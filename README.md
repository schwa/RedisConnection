# RedisConnection

A description of this package.

```swift
let connection = try await RedisConnection(label: "preamble", host: host)
try await connection.connect()
try await connection.hello(password: password)
_ = try await connection.send("SET", "foo", "bar")
print(try await connection.send("GET", "foo").stringValue)
```
