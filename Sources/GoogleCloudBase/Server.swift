import Foundation

public struct Server: Sendable {
    public init(
        baseURL: URL,
        isEmulator: Bool
    ) {
        self.baseURL = baseURL
        self.isEmulator = isEmulator
    }

    public var baseURL: URL
    public var isEmulator: Bool
}
