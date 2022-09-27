@testable import GoogleCloudBase
import NIOPosix
import XCTest

final class CredentialStoreTest: XCTestCase {
    private let mockClock = MockClock()
    private let mockCredential = MockCredential()

    private func makeStore() -> CredentialStore {
        CredentialStore(
            credential: mockCredential,
            clock: mockClock
        )
    }

    func testGetToken() async throws {
        mockCredential.getAccessTokenResult = .success(GoogleOAuthAccessToken(
            accessToken: "test_token",
            exipresIn: 60 * 60 * 1
        ))
        let store = makeStore()

        let token = try await store.accessToken()
        XCTAssertEqual(token, "test_token")
        XCTAssertEqual(mockCredential.getAccessTokenCalled, 1)
    }

    func testRefreshToken() async throws {
        let now = Date()
        mockClock.nowValue = now
        mockCredential.getAccessTokenResult = .success(GoogleOAuthAccessToken(
            accessToken: "test_token",
            exipresIn: 60 * 60 * 1
        ))
        let store = makeStore()
        _ = try await store.accessToken()
        XCTAssertEqual(mockCredential.getAccessTokenCalled, 1)

        _ = try await store.accessToken()
        XCTAssertEqual(mockCredential.getAccessTokenCalled, 1)

        mockClock.nowValue = now + 60 * 60 * 2
        _ = try await store.accessToken()
        XCTAssertEqual(mockCredential.getAccessTokenCalled, 2)
    }

    func testParallelAccess() async throws {
        let now = Date()
        mockClock.nowValue = now
        mockCredential.getAccessTokenResult = .success(GoogleOAuthAccessToken(
            accessToken: "test_token",
            exipresIn: 60 * 60 * 1
        ))
        let store = makeStore()

        let times = 30
        try await withThrowingTaskGroup(of: Void.self) { g in
            for _ in 0..<times {
                g.addTask {
                    _ = try await store.accessToken()
                }
            }
            try await g.waitForAll()
        }

        XCTAssertEqual(mockCredential.getAccessTokenCalled, 1)
    }
}
