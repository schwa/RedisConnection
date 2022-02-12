public indirect enum RESPValue: Sendable, Hashable {
    // <implemented>/<unit tests decode>/<unit test encode
    case simpleString(String)              // ✅🔲🔲 RESP 2+: `+<string>\r\n`
    case errorString(String)               // ✅🔲🔲 RESP 2+: `-<string>\r\n`
    case integer(Int)                      // ✅🔲🔲 RESP 2+: `:<number>\r\n`
    case blobString([UInt8])               // ✅🔲🔲 RESP 2+: `$<length>\r\n<bytes>\r\n`
    case nullBulkString                    // ✅🔲🔲 RESP 2:  `$-1\r\n
    case nullArray                         // ✅🔲🔲 RESP 2:  `*-1\r\n`
    case null                              // ✅✅🔲 RESP 3:  `_\r\n`
    case double(Double)                    // ✅🔲🔲 RESP 3:  `,<floating-point-number>\r\n`
    case boolean(Bool)                     // ✅✅🔲 RESP 3:  `#t\r\n` / `#f\r\n`
    case blobError([UInt8])                // ✅✅🔲 RESP 3:  `!<length>\r\n<bytes>\r\n`
    case verbatimString([UInt8])           // ✅✅🔲 RESP 3:  `=<length>\r\n<bytes>`
    case bigNumber([UInt8])                // ✅🔲🔲 RESP 3:  `(<big number>\r\n`
    case array([RESPValue])                // ✅🔲🔲 RESP 2+: `*<count>\r\n<elements>`
    case map([RESPValue: RESPValue])       // ✅✅🔲 RESP 3+: `%<count>\r\n<elements>`
    case set(Set<RESPValue>)               // ✅✅🔲 RESP 3+: `~<count>\r\n<elements>`
    case attribute([RESPValue: RESPValue]) // ✅🔲🔲 RESP 3+: `|<count>\r\n<elements>`
    case pubsub(Pubsub)                    // ✅🔲🔲 RESP 3+: `><count>\r\n<elements>` // TODO - this may not be exactly how this works
}

public struct Pubsub: Sendable, Hashable {
    public enum Kind: String, Sendable {
        case message
        case subscribe
        case unsubscribe
    }
    public var kind: Kind
    public var channel: String
    public var value: RESPValue
}

public extension RESPValue {
    static func blobString(_ string: String) -> RESPValue {
        return blobString(Array(string.utf8))
    }

    var integerValue: Int {
        get throws {
            guard case .integer(let value) = self else {
                throw RedisError.typeMismatch
            }
            return value
        }
    }

    var stringValue: String {
        get throws {
            switch self {
            case .simpleString(let value), .errorString(let value):
                return value
            case .blobString(let value), .blobError(let value), .verbatimString(let value):
                // TODO: encoding is safe to assume?
                guard let value = String(bytes: value, encoding: .utf8) else {
                    throw RedisError.stringDecodingError
                }
                return value
            default:
                throw RedisError.typeMismatch
            }
        }
    }

    var arrayValue: [RESPValue] {
        get throws {
            switch self {
            case .array(let array):
                return array
            default:
                throw RedisError.typeMismatch
            }
        }
    }

    var pubsubValue: Pubsub {
        get throws {
            switch self {
            case .pubsub(let value):
                return value
            default:
                throw RedisError.typeMismatch
            }
        }

    }
}

public extension RESPValue {
    func encode() throws -> [UInt8] {
        switch self {
        case .simpleString(let value):
            return Array("+\(value)\r\n".utf8)
        case .errorString(let value):
            return Array("-\(value)\r\n".utf8)
        case .integer(let value):
            return Array(":\(value)\r\n".utf8)
        case .blobString(let value):
            return Array("$\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .nullBulkString:
            return Array("$-1\r\n".utf8)
        case .array(let values):
            let encodedValues = try values.flatMap { try $0.encode() }
            return Array("*\(values.count)\r\n".utf8) + encodedValues
        case .nullArray:
            return Array("*-1\r\n".utf8)
        case .null:
            return Array("_\r\n".utf8)
        case .boolean(let value):
            return Array("#\(value ? "t" : "f")\r\n".utf8)
        case .blobError(let value):
            return Array("!\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .verbatimString(let value):
            return Array("=\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .bigNumber(let value):
            return Array("+\(value)\r\n".utf8)
        case .double(_):
            fatalError("Inimplemented")
        case .map(_):
            fatalError("Inimplemented")
        case .set(_):
            fatalError("Inimplemented")
        case .attribute(_):
            fatalError("Inimplemented")
        case .pubsub(_):
            fatalError("Inimplemented")
        }
    }
}

extension RESPValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .simpleString(let value):
            return value
        case .errorString(let value):
            return value
        case .integer(let value):
            return "\(value)"
        case .blobString(let value):
            return String(bytes: value, encoding: .utf8)!
        case .nullBulkString:
            return "<nil-string>"
        case .array(let values):
            return "[" + values.map { $0.description }.joined(separator: ", ") + "]"
        case .nullArray:
            return "<nil-array>"
        case .null:
            return "<null>"
        case .double(let value):
            return "\(value)"
        case .boolean(let value):
            return "\(value)"
        case .blobError(let value):
            return String(bytes: value, encoding: .utf8)!
        case .verbatimString(let value):
            return String(bytes: value, encoding: .utf8)!
        case .bigNumber(let value):
            return ".bigNumber(\(value))"
        case .map(let values):
            return ".map([" + values.map { "\($0.key.description): \($0.value.description)" }.joined(separator: ", ") + "])"
        case .set(let values):
            return ".set([" + values.map { $0.description }.joined(separator: ", ") + "])"
        case .attribute(let values):
            return ".attribute([" + values.map { "\($0.key.description): \($0.value.description)" }.joined(separator: ", ") + "])"
        case .pubsub(let value):
            return "pubsub(\(String(describing: value))"
        }
    }
}
