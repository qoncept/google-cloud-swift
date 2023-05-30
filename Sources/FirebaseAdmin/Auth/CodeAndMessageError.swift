import Foundation

public protocol CodeAndMessageError: Error & CustomStringConvertible & LocalizedError {
    associatedtype Code: RawRepresentable where Code.RawValue == String

    init(code: Code, message: String?)

    var code: Code { get }
    var message: String? { get }
}

extension CodeAndMessageError {
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

    public func convert<NewError>(to type: NewError.Type = NewError.self) -> NewError? where NewError: CodeAndMessageError {
        guard let newCode = NewError.Code(rawValue: code.rawValue) else { return nil }
        return NewError(code: newCode, message: message)
    }

    public func convertOrThrow<NewError>(to type: NewError.Type = NewError.self) throws -> NewError where NewError: CodeAndMessageError {
        guard let newError = convert(to: type) else {
            throw self
        }
        return newError
    }
}
