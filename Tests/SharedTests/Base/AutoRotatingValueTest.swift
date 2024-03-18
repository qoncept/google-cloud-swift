import Atomics
@testable import GoogleCloudBase
import NIOPosix
import XCTest

final class AutoRotatingValueTest: XCTestCase {
    private let mockClock = MockClock()

    func testGetValue() async throws {
        let counter = ManagedAtomic(0)
        let store = AutoRotatingValue {
            counter.wrappingIncrement(ordering: .relaxed)
            return ("hello", .seconds(1))
        }
        let token = try await store.getValue()
        XCTAssertEqual(token, "hello")
        XCTAssertEqual(counter.load(ordering: .relaxed), 1)
    }

    func testRefreshValue() async throws {
        let counter = ManagedAtomic(0)
        let store = AutoRotatingValue(clock: mockClock) {
            counter.wrappingIncrement(ordering: .relaxed)
            return ("hello", .seconds(1))
        }
        mockClock.nowValue = Date()

        _ = try await store.getValue()
        XCTAssertEqual(counter.load(ordering: .relaxed), 1)

        _ = try await store.getValue()
        XCTAssertEqual(counter.load(ordering: .relaxed), 1)

        mockClock.nowValue?.addTimeInterval(2)
        _ = try await store.getValue()
        XCTAssertEqual(counter.load(ordering: .relaxed), 2)
    }

    func testParallelAccess() async throws {
        let counter = ManagedAtomic(0)
        let store = AutoRotatingValue(clock: mockClock) {
            counter.wrappingIncrement(ordering: .relaxed)
            return ("hello", .seconds(1))
        }
        mockClock.nowValue = Date()

        let times = 30
        try await withThrowingTaskGroup(of: Void.self) { g in
            for _ in 0..<times {
                g.addTask {
                    _ = try await store.getValue()
                }
            }
            try await g.waitForAll()
        }

        XCTAssertEqual(counter.load(ordering: .relaxed), 1)
    }
}
