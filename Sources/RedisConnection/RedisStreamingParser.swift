import Foundation

// https://redis.io/topics/protocol
// https://github.com/antirez/RESP3/blob/master/spec.md

// NOT IMPLEMENTED: STREAM TYPES

public protocol RESPParser {
    mutating func parse(byte: UInt8) throws -> RESPValue?
}

public extension RESPParser {
    mutating func parse(bytes: some Collection<UInt8>) throws -> RESPValue? {
        for byte in bytes {
            if let value = try parse(byte: byte) {
                return value
            }
        }
        return nil
    }
}

// MARK: -

public struct RESPSimpleValueParserHelper: RESPParser {
    enum State {
        case waiting
        case headerConsumed
    }

    let header: UInt8
    let value: ([UInt8]) throws -> RESPValue?
    var state: State = .waiting
    var bytes: [UInt8] = []

    public init(header: UInt8, value: @escaping ([UInt8]) throws -> RESPValue?) {
        self.header = header
        self.value = value
    }

    public mutating func parse(byte: UInt8) throws -> RESPValue? {
        bytes.append(byte)
        switch (state, byte, Array(bytes.suffix(2))) {
        case (.waiting, header, _):
            state = .headerConsumed
            bytes = []
            return nil
        case (.headerConsumed, _, .crlf):
            defer {
                self.state = .waiting
                self.bytes = []
            }
            return try value(bytes.dropLast(2))
        case (.headerConsumed, _, _):
            return nil
        default:
            throw RedisError.parseError
        }
    }
}

public struct RESPFramedValueParserHelper: RESPParser {
    enum State {
        case waiting
        case headerConsumed
        case lengthConsumed
    }

    let header: UInt8
    let value: (Int, [UInt8]) -> RESPValue?
    var state: State = .waiting
    var bytes: [UInt8] = []
    var length: Int?

    public init(header: UInt8, value: @escaping (Int, [UInt8]) -> RESPValue?) {
        self.header = header
        self.value = value
    }

    public mutating func parse(byte: UInt8) throws -> RESPValue? {
        bytes.append(byte)
        switch (state, byte, Array(bytes.suffix(2)), bytes.count) {
        case (.waiting, header, _, _):
            state = .headerConsumed
            bytes = []
            return nil
        case (.headerConsumed, _, .crlf, _):
            state = .lengthConsumed
            guard let s = String(bytes: bytes.dropLast(2), encoding: .ascii) else {
                throw RedisError.stringDecodingError
            }
            guard let i = Int(s) else {
                throw RedisError.parseError
            }
            length = i
            bytes = []
            return nil
        case (.headerConsumed, _, _, _):
            return nil
        case (.lengthConsumed, _, .crlf, length! + 2):
            defer {
                state = .waiting
                bytes = []
            }
            return value(length!, bytes.dropLast(2))
        case (.lengthConsumed, _, _, _):
            return nil
        default:
            throw RedisError.parseError
        }
    }
}

public struct RESPCollectionParserHelper: RESPParser {
    enum State {
        case waiting
        case headerConsumed
        case countConsumed
    }

    let header: UInt8
    let valueCount: (Int) -> Int
    let value: (Int, [RESPValue]) throws -> RESPValue?
    var state: State = .waiting
    var bytes: [UInt8] = []
    var count: Int?
    var values: [RESPValue] = []
    var valueParser = RESPValueParser()

    public init(header: UInt8, valueCount: @escaping (Int) -> Int = { $0 }, value: @escaping (Int, [RESPValue]) throws -> RESPValue?) {
        self.header = header
        self.valueCount = valueCount
        self.value = value
    }

    public mutating func parse(byte: UInt8) throws -> RESPValue? {
        bytes.append(byte)
        switch (state, byte, Array(bytes.suffix(2)), bytes.count) {
        case (.waiting, header, _, _):
            state = .headerConsumed
            bytes = []
            return nil
        case (.headerConsumed, _, .crlf, _):
            state = .countConsumed
            guard let s = String(bytes: bytes.dropLast(2), encoding: .ascii) else {
                throw RedisError.stringDecodingError
            }
            guard let i = Int(s) else {
                throw RedisError.parseError
            }
            count = valueCount(i)
            bytes = []
            if count == 0 {
                return try value(0, [])
            }
            return nil
        case (.headerConsumed, _, _, _):
            return nil
        case (.countConsumed, _, _, _):
            if let value = try valueParser.parse(byte: byte) {
                values.append(value)
                valueParser = RESPValueParser()
                if values.count == count {
                    return try self.value(count!, values)
                }
            }
            return nil
        default:
            throw RedisError.parseError
        }
    }
}

// MARK: -

public struct RESPValueParser: RESPParser {
    private var helper: RESPParser!

//    private var bytes: [UInt8] = []
    public private(set) var bytesParsed: Int = 0

    public init() {}

    public mutating func parse(byte: UInt8) throws -> RESPValue? {
//        bytes.append(byte)
        if helper == nil {
            switch Character(UnicodeScalar(byte)) {
            case "+":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: "+")) {
                    .simpleString(String(bytes: $0, encoding: .utf8)!)
                }
            case "-":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: "-")) {
                    .errorString(String(bytes: $0, encoding: .utf8)!)
                }
            case ":":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: ":")) {
                    .integer(Int(String(bytes: $0, encoding: .utf8)!)!)
                }
            case "$":
                helper = RESPFramedValueParserHelper(header: UInt8(ascii: "$")) { length, bytes in
                    if length == -1 {
                        .nullBulkString
                    }
                    else {
                        .blobString(bytes)
                    }
                }
            case "*":
                helper = RESPCollectionParserHelper(header: UInt8(ascii: "*")) { count, values in
                    if count == -1 {
                        return .nullArray
                    }
                    else {
                        guard count == values.count else {
                            throw RedisError.parseError
                        }
                        return .array(values)
                    }
                }
            case "_":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: "_")) {
                    guard $0.isEmpty else {
                        throw RedisError.parseError
                    }
                    return .null
                }
            case "#":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: "#")) {
                    switch String(bytes: $0, encoding: .utf8) {
                    case "t":
                        return .boolean(true)
                    case "f":
                        return .boolean(false)
                    default:
                        throw RedisError.parseError
                    }
                }
            case "!":
                helper = RESPFramedValueParserHelper(header: UInt8(ascii: "!")) { _, bytes in
                    .blobError(bytes)
                }
            case "=":
                helper = RESPFramedValueParserHelper(header: UInt8(ascii: "=")) { _, bytes in
                    .verbatimString(bytes)
                }
            case "(":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: "(")) {
                    .bigNumber($0)
                }
            case "%":
                helper = RESPCollectionParserHelper(header: UInt8(ascii: "%")) {
                    $0 * 2
                }
                value: { _, values in
                    let pairs = try stride(from: 0, to: values.count, by: 2).map {
                        Array(values[$0 ..< Swift.min($0 + 2, values.count)])
                    }
                    .map { (values: [RESPValue]) -> (RESPValue, RESPValue) in
                        guard values.count == 2 else {
                            throw RedisError.parseError
                        }
                        return (values[0], values[1])
                    }
                    return .map(Dictionary(uniqueKeysWithValues: pairs))
                }
            case "~":
                helper = RESPCollectionParserHelper(header: UInt8(ascii: "~")) { _, values in
                    .set(Set(values))
                }
            case "|":
                helper = RESPCollectionParserHelper(header: UInt8(ascii: "|")) {
                    $0 * 2
                }
                value: { _, values in
                    let pairs = stride(from: 0, to: values.count, by: 2).map {
                        Array(values[$0 ..< Swift.min($0 + 2, values.count)])
                    }
                    .map {
                        ($0[0], $0[1])
                    }
                    return .attribute(Dictionary(uniqueKeysWithValues: pairs))
                }
            case ",":
                helper = RESPSimpleValueParserHelper(header: UInt8(ascii: ",")) {
                    .double(Double(String(bytes: $0, encoding: .utf8)!)!)
                }
            case ">":
                helper = RESPCollectionParserHelper(header: UInt8(ascii: ">")) { _, values in
                    guard let kind = try Pubsub.Kind(rawValue: values[0].stringValue.lowercased()) else {
                        throw RedisError.parseError
                    }
                    let pubsub = try Pubsub(
                        kind: kind,
                        channel: values[1].stringValue,
                        value: values[2]
                    )
                    return .pubsub(pubsub)
                }
            default:
//                throw RedisError.undefined("Unknown header character, \(Character(UnicodeScalar(byte))), bytes: \(String(bytes: bytes, encoding: .utf8)!.replacingOccurrences(of: "\r\n", with: "\\r\\n"))")
                throw RedisError.unknownHeader(Character(UnicodeScalar(byte)))
            }
        }
        defer {
            bytesParsed += 1
        }
        if let value = try helper.parse(byte: byte) {
            helper = nil
            return value
        }
        return nil
    }
}

public extension RESPValueParser {
    static func parse(bytes: some Collection<UInt8>) throws -> RESPValue? {
        var parser = RESPValueParser()
        return try parser.parse(bytes: bytes)
    }
}
