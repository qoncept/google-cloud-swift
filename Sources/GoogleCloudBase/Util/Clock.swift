import Foundation

public protocol Clock: Sendable {
    func now() -> Date
}

public struct DefaultClock: Clock, Sendable {
    public func now() -> Date { Date() }
}

extension Clock where Self == DefaultClock {
    public static var `default`: DefaultClock { DefaultClock() }
}
