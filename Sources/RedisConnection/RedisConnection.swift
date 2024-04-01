import Foundation
import Network
@preconcurrency import os

public actor RedisConnection {

    nonisolated
    public let label: String?

    let connection: NWConnection
    let stateStream: AsyncStream<NWConnection.State>

    let logger: Logger? = nil // Logger()

    enum Mode {
        case normal
        case subscriber
    }

    var mode = Mode.normal

    public init(label: String? = nil, host: String? = nil, port: Int? = nil) {
        self.label = label
        let host = NWEndpoint.Host(host ?? "localhost")
        let port = NWEndpoint.Port(rawValue: NWEndpoint.Port.RawValue(port ?? 6_379))!
        let params = NWParameters(tls: nil, tcp: .init())
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: RedisProtocol.definition), at: 0)
        let connection = NWConnection(host: host, port: port, using: params)
        let stateStream = AsyncStream { continuation in
            connection.stateUpdateHandler = { state in
                continuation.yield(state)
            }
        }
        self.connection = connection
        self.stateStream = stateStream
    }

    public func connect() async throws {
        logger?.debug("\(#function)")
        let queue = DispatchQueue(label: "redis-connection", qos: .default, attributes: [])
        connection.start(queue: queue)
        loop: for await state in stateStream {
            logger?.debug("State change: \(state)")
            switch state {
            case .preparing:
                break
            case .ready:
                break loop
            case .failed(let error):
                throw error
            case .waiting(let error):
                throw error
            case .setup:
                throw RedisError.unexpectedState
            case .cancelled:
                throw RedisError.unexpectedState
            @unknown default:
                throw RedisError.unexpectedState
            }
        }
        if let logger {
            Task {
                for await state in stateStream {
                    logger.debug("State change: \(state)")
                }
            }
        }
    }

    public func disconnect() async throws {
        logger?.debug("\(#function)")
        connection.cancel()
    }

    // MARK: -

    private func receiveHelper(resumeThrowing: @Sendable @escaping (Error) -> Void, resumeReturning: @Sendable @escaping (RESPValue) -> Void) {
        let logger = self.logger
        logger?.debug("\(#function)")
        connection.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { _, context, _, error in
            logger?.debug("\(#function) (closure)")
            if let error = error {
                resumeThrowing(error)
                return
            }
            guard let context = context else {
                fatalError("No context")
            }
            guard let message = context.protocolMetadata(definition: RedisProtocol.definition) as? NWProtocolFramer.Message else {
                resumeThrowing(RedisError.messageReceiveFailure)
                return
            }
            guard let value = message["message"] as? RESPValue else {
                fatalError("No message/message of wrong type.")
            }

            resumeReturning(value)
        }
    }

    // MARK: -

    public func send(value: RESPValue) async throws -> (RESPValue) {
        assert(mode == .normal)
        logger?.debug("\(#function)")
        let encodedValue = try value.encode()
        return try await withCheckedThrowingContinuation { continuation in
            connection.batch {
                receiveHelper { error in
                    continuation.resume(throwing: error)
                } resumeReturning: { value in
                    continuation.resume(returning: value)
                }
                connection.send(content: encodedValue, completion: .contentProcessed({ error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    }
                }))
            }
        }
    }

    public func sendNoReceive(value: RESPValue) async throws {
        assert(mode == .normal)
        logger?.debug("\(#function)")
        let encodedValue = try value.encode()
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: encodedValue, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                continuation.resume()
            }))
        }
    }

    public func receive() async throws -> RESPValue {
        assert(mode == .normal)
        logger?.debug("\(#function)")
        return try await withCheckedThrowingContinuation { continuation in
            receiveHelper { error in
                continuation.resume(throwing: error)
            } resumeReturning: { value in
                continuation.resume(returning: value)
            }
        }
    }
}

// MARK: -

public extension RedisConnection {

    func send(value: [String]) async throws -> (RESPValue) {
        logger?.debug("\(#function)")
        let value = RESPValue.array(value.map { .blobString($0) })
        return try await send(value: value)
    }

    func sendNoReceive(value: [String]) async throws {
        logger?.debug("\(#function)")
        let value = RESPValue.array(value.map { .blobString($0) })
        try await sendNoReceive(value: value)
    }

    func send(_ value: String...) async throws -> (RESPValue) {
        return try await send(value: value)
    }

    func send(values: [[String]]) async throws {
        logger?.debug("\(#function)")
        let encodedValue = try values.flatMap {
            try RESPValue.array($0.map { .blobString($0) }).encode()
        }
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: encodedValue, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                continuation.resume()
            }))
        }
    }
}

// MARK: -

public extension RedisConnection {

    func subscribe(channels: String...) async throws -> AnyAsyncSequence<Pubsub> {
        mode = .subscriber

        logger?.debug("\(#function)")
        try await sendNoReceive(value: ["SUBSCRIBE"] + channels)
        var confirmedChannels: Set<String> = []
        for _ in 0 ..< channels.count {
            confirmedChannels.insert(try await receive().pubsubValue.channel)
        }
        if confirmedChannels != Set(channels) {
            throw RedisError.partialSubscribe
        }
        return AnyAsyncSequence {
            AnyAsyncIterator {
                let value = try await self.receive()
                switch value {
                case .pubsub(let pubsub):
                    return pubsub
                default:
                    return nil
                }
            }
        }
    }

    func publish(channel: String, value: String) async throws -> Int {
        let response = try await send(value: ["PUBLISH", channel, value])
        return try response.integerValue
    }
}

// MARK: -

extension RedisConnection {
    public func hello(username: String = "default", password: String, clientName: String? = nil) async throws {
        logger?.debug("\(#function)")

        var request = ["HELLO", "3", "AUTH", username, password]
        if let clientName = clientName {
            request += ["SETNAME", clientName]
        }

        let response = try await send(value: request)
        guard case .map(let response) = response else {
            throw RedisError.authenticationFailure
        }
        guard let respVersion = try response[.blobString("proto")]?.integerValue, respVersion == 3 else {
            throw RedisError.authenticationFailure
        }
    }

    public func authenticate(password: String) async throws {
        logger?.debug("\(#function)")
        let response = try await send("AUTH", password)

        guard try response.stringValue == "OK" else {
            throw RedisError.authenticationFailure
        }
    }
}

// MARK: -
