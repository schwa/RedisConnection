import Foundation
import RedisConnection
import os


@main
struct Main {
    static let host = "sjc.morning-resonance-3623.internal"
    static let password = "notagoodpassword"

    static func main() async throws {
        try await basic1Test()
        try await basic2Test()
        try await pubSubTest()
    }

    static func basic1Test() async throws {
        let connection = try await RedisConnection(label: "preamble", host: host)
        try await connection.connect()
        try await connection.hello(password: password)
        _ = try await connection.send("SET", "foo", "bar")
        print(try await connection.send("GET", "foo").stringValue)
    }

    static func basic2Test() async throws {
        // Connect to a REDIS server and ask it a bunch of questions...
        Timeit.shared.start("PREAMBLE")
        let connection = try await RedisConnection(label: "preamble", host: host)
        try await connection.connect()
        try await connection.hello(username: "default", password: password, clientName: "example-client")
        log(connection, try await connection.send("PING"))
        log(connection, try await connection.send("CLIENT", "INFO"))
        log(connection, try await connection.send("CLIENT", "GETNAME"))
        log(connection, try await connection.send("ACL", "WHOAMI"))
        log(connection, try await connection.send("ACL", "USERS"))
        log(connection, try await connection.send("ACL", "LIST"))
        //        log(connection, try await connection.send("CONFIG", "GET", "*"))
        //        log(connection, try await connection.send("COMMAND"))
        log(connection,  try await connection.send("QUIT"))
        try await connection.disconnect()
        await Timeit.shared.finish("PREAMBLE")
    }

    static func pubSubTest() async throws {

        let channel = "my-example-channel"

        let listenerTask = Task {
            Timeit.shared.start("Listening")
            let connection = try await RedisConnection(label: "listener", host: host)
            try await connection.connect()
            try await connection.hello(password: password)
            var values = Set<Int>()
            for try await message in try await connection.subscribe(channels: channel) {
                if try message.kind == .message && message.value.stringValue == "STOP" {
                    log(connection, "STOPPING")
                    break
                }
                values.insert(Int(try message.value.stringValue)!)
            }
            await Timeit.shared.finish("Listening")
            return values
        }

        let publisherTask = Task {
            // We're going to publish some things.
            let values = 0..<100
            Timeit.shared.start("Sending")
            let connection = try await RedisConnection(label: "sender", host: host)
            try await connection.connect()
            try await connection.hello(password: password)
            try await connection.send(values: values.map { ["PUBLISH", channel, "\($0)"] })
            log(connection, try await connection.publish(channel: channel, value: "STOP"))
            await Timeit.shared.finish("Sending")
            return Set(values)
        }

        let receivedValues = try await listenerTask.value
        let publishedValues = try await publisherTask.value

        assert(publishedValues == receivedValues)
    }
}
