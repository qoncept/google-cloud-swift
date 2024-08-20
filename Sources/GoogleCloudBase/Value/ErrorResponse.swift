public struct ErrorResponse: Decodable, Error, CustomStringConvertible {
    public struct Error: Decodable, Sendable {
        public var code: Int
        public var message: String
        public var status: String?
        public var errors: [[String: String]]?
    }
    public var error: Error
    public var description: String { "\(error.message)(\(error.code))" }
}
