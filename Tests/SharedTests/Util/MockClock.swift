import Foundation
@testable import FirebaseAdmin

class MockClock: Clock, @unchecked Sendable {
    var nowValue: Date?
    func now() -> Date {
        nowValue ?? Date()
    }
}
