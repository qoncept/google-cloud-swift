import Foundation

public protocol CodeAndMessageError: Error & CustomStringConvertible & LocalizedError {
    associatedtype Code: RawRepresentable where Code.RawValue == String

    init(code: Code, message: String?)

    var code: Code { get }
    var message: String? { get }
}

extension CodeAndMessageError {
    /// Cast an argument error. If it fails, the given error itself is thrown.
    public init(_ other: some CodeAndMessageError) throws {
        guard let newCode = Self.Code(rawValue: other.code.rawValue) else {
            throw other
        }
        self.init(code: newCode, message: other.message)
    }

    public var description: String {
        var str = code.rawValue
        if let message {
            str += ": " + message
        }
        return str
    }

    public var errorDescription: String? {
        description
    }
}
