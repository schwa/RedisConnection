import Foundation
import Network

extension NWConnection.State: CustomStringConvertible {
    public var description: String {
        switch self {
        case .preparing:
            "preparing"
        case .ready:
            "ready"
        case .cancelled:
            "cancelled"
        case .setup:
            "setup"
        default:
            "?"
        }
    }
}

public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {
    let body: () async throws -> Element?

    public init(_ body: @escaping () async throws -> Element?) {
        self.body = body
    }

    public mutating func next() async throws -> Element? {
        try await body()
    }
}

public struct AnyAsyncSequence<Element>: AsyncSequence, Sendable {
    public typealias Iterator = AnyAsyncIterator<Element>

    public let makeUnderlyingIterator: @Sendable () -> Iterator

    public init<I>(_ makeUnderlyingIterator: @Sendable @escaping () -> I) where Element == I.Element, I: AsyncIteratorProtocol {
        self.makeUnderlyingIterator = {
            var i = makeUnderlyingIterator()
            return AnyAsyncIterator {
                try await i.next()
            }
        }
    }

    public func makeAsyncIterator() -> Iterator {
        makeUnderlyingIterator()
    }
}

extension [UInt8] {
    // I will fight you.
    static let crlf = [UInt8(ascii: "\r"), UInt8(ascii: "\n")]
}

extension Array {
    mutating func replaceLast(_ element: Element) {
        removeLast()
        append(element)
    }
}
