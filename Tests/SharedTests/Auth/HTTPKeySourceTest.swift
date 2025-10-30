import AsyncHTTPClient
import Atomics
import Foundation
@testable import FirebaseAdmin
import Testing

@Suite struct HTTPKeySourceTest {
    private let mockClock: MockClock = .init()

    private func makeKeySource() -> HTTPKeySource {
        return HTTPKeySource(clock: mockClock)
    }

    @Test func fetchKeys() async throws {
        let source = makeKeySource()

        let keys = try await source.publicKeys()
        let key = try await keys.getKey()
        #expect(key != nil)
    }

    @Test func refreshKeys() async throws {
        mockClock.nowValue = Date()
        let source = makeKeySource()

        let refreshCalled = ManagedAtomic(0)
        source.setWillRefreshKeys {
            refreshCalled.wrappingIncrement(ordering: .relaxed)
        }

        do {
            let keys = try await source.publicKeys()
            #expect(keys != nil)
            #expect(refreshCalled.load(ordering: .relaxed) == 1)
        }
        do {
            let keys = try await source.publicKeys()
            #expect(keys != nil)
            #expect(refreshCalled.load(ordering: .relaxed) == 1)
        }
        do {
            let keys = try await source.publicKeys()
            #expect(keys != nil)
            #expect(refreshCalled.load(ordering: .relaxed) == 1)
        }

        mockClock.nowValue?.addTimeInterval(60 * 60 * 24)

        do {
            let keys = try await source.publicKeys()
            #expect(keys != nil)
            #expect(refreshCalled.load(ordering: .relaxed) == 2)
        }
        do {
            let keys = try await source.publicKeys()
            #expect(keys != nil)
            #expect(refreshCalled.load(ordering: .relaxed) == 2)
        }
    }

    @Test func parallelAccess() async throws {
        mockClock.nowValue = Date()
        let source = makeKeySource()

        let refreshCalled = ManagedAtomic(0)
        source.setWillRefreshKeys {
            refreshCalled.wrappingIncrement(ordering: .relaxed)
        }

        let times = 30
        try await withThrowingTaskGroup(of: Void.self) { g in
            for _ in 0..<times {
                g.addTask {
                    _ = try await source.publicKeys()
                }
            }
            try await g.waitForAll()
        }

        #expect(refreshCalled.load(ordering: .relaxed) == 1)
    }
}
