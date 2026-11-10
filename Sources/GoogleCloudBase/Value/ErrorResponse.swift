import NIOHTTP1

public struct ErrorResponse: Decodable, Error, CustomStringConvertible {
    public struct Error: Decodable, Sendable {
        public var code: Int
        public var message: String
        public var status: String?
        public var errors: [[String: String]]?
        public var details: [JSONValue]?
    }
    public var error: Error
    /// The HTTP status, when the error was received from an HTTP request.
    public var httpStatusCode: UInt?
    public var httpHeaders: HTTPHeaders?
    public var description: String { "\(error.message)(\(error.code))" }

    private enum CodingKeys: String, CodingKey {
        case error
    }
}
