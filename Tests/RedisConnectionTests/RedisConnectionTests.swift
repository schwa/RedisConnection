import class Foundation.Bundle
import RedisConnection
import XCTest

final class RedisConnectionTests: XCTestCase {
//        let url = Bundle.module.url(forResource: "foo", withExtension: "dat")!
//        let data = try Data(contentsOf: url)
//        var scanner = CollectionScanner(elements: data)
//        let value = scanner.scanRESPValue()

    func testNull() throws {
        XCTAssert(try RESPValueParser.parse(bytes: "_\r\n".utf8) == .null)
        XCTAssertThrowsError(try RESPValueParser.parse(bytes: "_x\r\n".utf8))
    }

    func testBool() throws {
        XCTAssert(try RESPValueParser.parse(bytes: "_\r\n".utf8) == .null)
        XCTAssertThrowsError(try RESPValueParser.parse(bytes: "_x\r\n".utf8))
    }

    func testBlobError() throws {
        XCTAssertEqual(try RESPValueParser.parse(bytes: "!11\r\nHello world\r\n".utf8)?.description, "Hello world")
    }

    func testVerbatimString() throws {
        XCTAssertEqual(try RESPValueParser.parse(bytes: "=11\r\nHello world\r\n".utf8)?.description, "Hello world")
    }

    func testMap() throws {
        XCTAssertEqual(try RESPValueParser.parse(bytes: "%1\r\n+Hello\r\n+world\r\n".utf8)?.description, ".map([Hello: world])")
    }

    func testSet() throws {
        XCTAssertEqual(try RESPValueParser.parse(bytes: "~1\r\n+Hello World\r\n".utf8)?.description, ".set([Hello World])")
    }

    func testAttribute() throws {
        XCTAssertEqual(try RESPValueParser.parse(bytes: "|1\r\n+Hello\r\n+world\r\n".utf8)?.description, ".attribute([Hello: world])")
    }
}

// TODO: Null bulk string

// var p = RESPValueParser()
// print(try p.parse(bytes: Array("+Hello world\r\n".utf8)))
// print(try p.parse(bytes: Array("-Hello world\r\n".utf8)))
// print(try p.parse(bytes: Array(":1234\r\n".utf8)))
// print(try p.parse(bytes: Array("$3\r\nfoo\r\n".utf8)))
// print(try p.parse(bytes: Array("$0\r\n\r\n".utf8)))
// print(try p.parse(bytes: Array("$-1\r\n".utf8)))
// print(try p.parse(bytes: Array("*-1\r\n".utf8)))
// print(try p.parse(bytes: Array("*0\r\n".utf8)))
// print(try p.parse(bytes: Array("*2\r\n+A\r\n+B\r\n".utf8)))
//
//
// let u = URL(fileURLWithPath: "/Users/schwa/Library/Mobile Documents/com~apple~CloudDocs/Projects/RedisConnection/Tests/RedisConnectionTests/foo.dat")
// let bytes = Array<UInt8>(try Data(contentsOf: u))
// print(try p.parse(bytes: bytes))
//
//
//
//// var parser = RESPStreamingParser()
////// try parser.feed(Array("+hello world\r\n".utf8))
////// try parser.feed(Array("-hello world\r\n".utf8))
////// try parser.feed(Array(":123\r\n".utf8))
////// try parser.feed(Array("$6\r\nfoobar\r\n".utf8))
////// try parser.feed(Array("*0\r\n".utf8))
////// try parser.feed(Array("*0\r\n".utf8))
//// try parser.feed(Array("*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n".utf8))
