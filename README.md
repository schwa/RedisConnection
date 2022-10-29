# RedisConnection

A Swift Concurrency-based implementation of the Redis (3) Protocol. This project uses Apple's Network framework to implement the Redis Protocol.

The project supports the Redis streaming (RESP-3) protocol. It has built-in support for Redis pub-sub using Swift AsyncIterators.

## Basic Example

```swift
let connection = try await RedisConnection(label: "preamble", host: host)
try await connection.connect()
try await connection.hello(password: password)
_ = try await connection.send("SET", "foo", "bar")
print(try await connection.send("GET", "foo").stringValue)
```

## Basic Pubsub Listener Example

```swift
let connection = try await RedisConnection(label: "preamble", host: host)
try await connection.connect()
try await connection.hello(password: password)
for try await message in try await connection.subscribe(channels: channel) {
    print(message.value)
}
```
