public enum RedisError: Error {
    case authenticationFailure
    case unexpectedState
    case parseError
    case messageReceiveFailure
    case typeMismatch
    case stringDecodingError
    case unknownHeader(Character)
    case partialSubscribe

    @available(*, deprecated, message: "Create a better error")
    case undefined(String)
}
