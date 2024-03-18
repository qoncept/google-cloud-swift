import Foundation
@testable import FirebaseAdmin

final class MockClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = Date

    var nowValue: Date?
    var now: Date {
        nowValue ?? Date()
    }
    var minimumResolution: Duration {
        .seconds(1)
    }

    func sleep(until deadline: Date, tolerance: Duration?) async throws {
        let d = deadline.timeIntervalSinceNow
        try await Task.sleep(for: .seconds(d))
    }
}

extension Date: InstantProtocol {
    public typealias Duration = Swift.Duration
    public func advanced(by duration: Duration) -> Self {
        addingTimeInterval(TimeInterval(duration.components.seconds))
    }

    public func duration(to other: Self) -> Self.Duration {
        .seconds(timeIntervalSince(other)) 
    }
}
