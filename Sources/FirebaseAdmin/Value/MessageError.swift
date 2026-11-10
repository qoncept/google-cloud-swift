import Foundation

struct MessageError: Error, CustomStringConvertible, LocalizedError {
    init(_ description: String) {
        self.description = description
    }
    var description: String
    var errorDescription: String? { description }
}
