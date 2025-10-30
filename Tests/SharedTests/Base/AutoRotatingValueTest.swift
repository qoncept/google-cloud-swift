import Atomics
import Foundation
@testable import GoogleCloudBase
import NIOPosix
import Testing

@Suite struct AutoRotatingValueTest {
    private let mockClock = MockClock()

    @Test func getValue() async throws {
        let counter = ManagedAtomic(0)
        let store = AutoRotatingValue {
            counter.wrappingIncrement(ordering: .relaxed)
            return ("hello", .seconds(1))
        }
        let token = try await store.getValue()
        #expect(token == "hello")
        #expect(counter.load(ordering: .relaxed) == 1)
    }

    @Test func refreshValue() async throws {
        let counter = ManagedAtomic(0)
        let store = AutoRotatingValue(clock: mockClock) {
            counter.wrappingIncrement(ordering: .relaxed)
            return ("hello", .seconds(1))
        }
        mockClock.nowValue = Date()

        _ = try await store.getValue()
        #expect(counter.load(ordering: .relaxed) == 1)

        _ = try await store.getValue()
        #expect(counter.load(ordering: .relaxed) == 1)

        mockClock.nowValue?.addTimeInterval(2)
        _ = try await store.getValue()
        #expect(counter.load(ordering: .relaxed) == 2)
    }

    @Test func parallelAccess() async throws {
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

        #expect(counter.load(ordering: .relaxed) == 1)
    }
}
