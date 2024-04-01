import Foundation
import os
import RedisConnection

@main
struct Main {
    static let host = "localhost"
    static let password = "notagoodpassword"

    static func main() async throws {
        //        try! await basic1Test()
        //        try! await basic2Test()
        try! await pubSubTest()
    }

    static func basic1Test() async throws {
        let connection = RedisConnection(label: "preamble", host: host)
        try await connection.connect()
        try await connection.hello(password: password)
        _ = try await connection.send("SET", "foo", "bar")
        try await print(connection.send("GET", "foo").stringValue)
    }

    static func basic2Test() async throws {
        // Connect to a REDIS server and ask it a bunch of questions...
        Timeit.shared.start("PREAMBLE")
        let connection = RedisConnection(label: "preamble", host: host)
        try await connection.connect()
        try await connection.hello(username: "default", password: password, clientName: "example-client")
        try await log(connection, connection.send("PING"))
        try await log(connection, connection.send("CLIENT", "INFO"))
        try await log(connection, connection.send("CLIENT", "GETNAME"))
        try await log(connection, connection.send("ACL", "WHOAMI"))
        try await log(connection, connection.send("ACL", "USERS"))
        try await log(connection, connection.send("ACL", "LIST"))
        //        log(connection, try await connection.send("CONFIG", "GET", "*"))
        //        log(connection, try await connection.send("COMMAND"))
        try await log(connection, connection.send("QUIT"))
        try await connection.disconnect()
        await Timeit.shared.finish("PREAMBLE")
    }

    static func pubSubTest() async throws {
        let channel = "my-example-channel"

        let listenerTask = Task {
            Timeit.shared.start("Listening")
            let connection = RedisConnection(label: "listener", host: host)
            try await connection.connect()
            try await connection.hello(password: password)
            var values = Set<Int>()
            for try await message in try await connection.subscribe(channels: channel) {
                if try message.kind == .message && message.value.stringValue == "STOP" {
                    log(connection, "STOPPING")
                    break
                }
                try values.insert(Int(message.value.stringValue)!)
            }
            await Timeit.shared.finish("Listening")
            return values
        }

        let publisherTask = Task {
            // We're going to publish some things.
            let values = 0 ..< 10000
            Timeit.shared.start("Sending")
            let connection = RedisConnection(label: "sender", host: host)
            try await connection.connect()
            try await connection.hello(password: password)
            try await connection.send(values: values.map { ["PUBLISH", channel, "\($0)"] })
            try await log(connection, connection.publish(channel: channel, value: "STOP"))
            await Timeit.shared.finish("Sending")
            return Set(values)
        }

        let receivedValues = try await listenerTask.value
        let publishedValues = try await publisherTask.value

        assert(publishedValues == receivedValues)
    }
}
