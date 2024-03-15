import AsyncHTTPClient
@testable import FirebaseAdmin
import XCTest

final class HTTPKeySourceTest: XCTestCase {
    private let mockClock: MockClock = .init()

    private func makeKeySource() -> HTTPKeySource {
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        addTeardownBlock {
            try! client.syncShutdown()
        }
        return HTTPKeySource(client: client, clock: mockClock)
    }

    func testFetchKeys() async throws {
        let source = makeKeySource()

        let keys = try await source.publicKeys()
        let key = try await keys.getKey()
        XCTAssertNotNil(key)
    }

    func testRefreshKeys() async throws {
        mockClock.nowValue = Date()
        let source = makeKeySource()

        var refreshCalled = 0
        await source.setWillRefreshKeys {
            refreshCalled += 1
        }

        do {
            let keys = try await source.publicKeys()
            XCTAssertNotNil(keys)
            XCTAssertEqual(refreshCalled, 1)
        }
        do {
            let keys = try await source.publicKeys()
            XCTAssertNotNil(keys)
            XCTAssertEqual(refreshCalled, 1)
        }
        do {
            let keys = try await source.publicKeys()
            XCTAssertNotNil(keys)
            XCTAssertEqual(refreshCalled, 1)
        }

        mockClock.nowValue?.addTimeInterval(60 * 60 * 24)

        do {
            let keys = try await source.publicKeys()
            XCTAssertNotNil(keys)
            XCTAssertEqual(refreshCalled, 2)
        }
        do {
            let keys = try await source.publicKeys()
            XCTAssertNotNil(keys)
            XCTAssertEqual(refreshCalled, 2)
        }
    }

    func testParallelAccess() async throws {
        mockClock.nowValue = Date()
        let source = makeKeySource()

        var refreshCalled = 0
        await source.setWillRefreshKeys {
            refreshCalled += 1
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

        XCTAssertEqual(refreshCalled, 1)
    }
}
