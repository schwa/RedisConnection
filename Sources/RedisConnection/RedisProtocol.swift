import Foundation
import Network
import os

// https://developer.apple.com/forums/thread/118686
// https://developer.apple.com/forums/thread/132575
// https://developer.apple.com/documentation/network/building_a_custom_peer-to-peer_protocol

//    The value you return from parseInput is "move the cursor ahead by N bytes, I've consumed them". The value you return from handleInput is "I need N bytes to present before I want to be woken up again". The value you pass to deliverInputNoCopy is "move the cursor ahead by N bytes, and deliver those N bytes".

public class RedisProtocol: NWProtocolFramerImplementation {
    public static let label: String = "REDIS"
    public static let definition = NWProtocolFramer.Definition(implementation: RedisProtocol.self)

    var debugLogger: Logger? // Logger()
    let logger = Logger()
    var parser = RESPValueParser()

    public required init(framer _: NWProtocolFramer.Instance) {}

    public func start(framer _: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }

    public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        debugLogger?.debug(#function)

        var value: RESPValue?
        var error: Error?

        while error == nil {
            // We always need minimumIncompleteLength to be at least 1.
            let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: Int.max) { buffer, isComplete in
                do {
                    debugLogger?.debug("Buffer \(String(describing: buffer)), isComplete: \(isComplete)")
                    // Remember how many bytes we've passed so far
                    let startBytesParsed = parser.bytesParsed
                    debugLogger?.debug("startBytesParsed: \(startBytesParsed)")
                    debugLogger?.debug("\(String(describing: buffer)) \(isComplete)")
                    guard let buffer, !buffer.isEmpty else {
                        debugLogger?.debug("Zero bytes. Skipping")
                        return 0
                    }
                    value = try parser.parse(bytes: buffer)
                    debugLogger?.debug("parsed: \(self.parser.bytesParsed - startBytesParsed) / \(buffer.count)")
                    // We may not have parsed the entire buffer so compute what we did pass
                    return parser.bytesParsed - startBytesParsed
                }
                catch {
                    logger.error("\(String(describing: error))")
                    error = localError
                    return 0
                }
            }
            if !parsed {
                debugLogger?.debug("NOT PARSED")
                return 0
            }
            guard let value else {
                debugLogger?.debug("CONTINUE")
                continue
            }
            let message = NWProtocolFramer.Message(instance: framer)
            message["message"] = value
            let result = framer.deliverInputNoCopy(length: 0, message: message, isComplete: true)
            if result {
                return 0
            }
        }

        return 0
    }

    public func handleOutput(framer: NWProtocolFramer.Instance, message _: NWProtocolFramer.Message, messageLength: Int, isComplete _: Bool) {
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        }
        catch {
            logger.error("\(String(describing: error))")
        }
    }

    public func wakeup(framer _: NWProtocolFramer.Instance) {}

    public func stop(framer _: NWProtocolFramer.Instance) -> Bool {
        true
    }

    public func cleanup(framer _: NWProtocolFramer.Instance) {}
}
