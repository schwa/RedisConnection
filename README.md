# Redis Connection

A Swift Concurrency-based implementation of the Redis (3) Protocol. This project uses Apple's Network framework to implement the Redis Protocol.

The project supports the Redis streaming (RESP-3) protocol. It has built-in support for Redis pub-sub using Swift AsyncIterators.

## Basic Example

```swift
let connection = try await RedisConnection(host: host)
try await connection.connect()
try await connection.hello(password: password)
_ = try await connection.send("SET", "foo", "bar")
print(try await connection.send("GET", "foo").stringValue)
```

## Basic Pubsub Listener Example

```swift
let connection = try await RedisConnection(host: host)
try await connection.connect()
try await connection.hello(password: password)
for try await message in try await connection.subscribe(channels: channel) {
    print(message.value)
}
```

## Notes

This project is a hobby project. Caveat emptor and all that.

A lot of effort was spent on the Network framework protocol implementation. The Redis protocol (or rather the RESP3 protocol) isn't very well designed (there's no framing data and you have to parse the entire message to know how big it is...) and a lot of implementation issues were encountered. I feel I've addressed all these issues and that the protocol works well now.

Performance seems excellent publishing and subscribing to 10,000 messages per second on a remote Redis server (accessed via Wireguard).

The project doesn't know anything about any Redis command types except the handful of commands that are used to implement login/authentication and the pub-sub functionality.
