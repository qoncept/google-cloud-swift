import Foundation

private let tokenExpiryThreshold: Duration = .seconds(5 * 60)

public actor CredentialStore {
    public let credential: any Credential
    nonisolated public var compilersafeCredential: any Credential {
        // 外のモジュールが「actorに生えたSendableなlet変数」をawaitするとコンパイラがクラッシュするので、その回避
        credential
    }

    protocol StorageProtocol {
        mutating func store(result: GoogleOAuthAccessToken)
        var cachedAccessToken: String? { get }
    }

    private struct Storage<ClockType: Clock<Duration>>: StorageProtocol {
        var clock: ClockType

        struct OAuth2Token {
            var accessToken: String
            var expiry: ClockType.Instant
        }
        var cachedToken: OAuth2Token?

        mutating func store(result: GoogleOAuthAccessToken) {
            cachedToken = .init(
                accessToken: result.accessToken,
                expiry: clock.now.advanced(by: .seconds(result.exipresIn))
            )
        }

        var cachedAccessToken: String? {
            guard let cachedToken else {
                return nil
            }
            let remainingTime = cachedToken.expiry.duration(to: clock.now)
            if remainingTime < tokenExpiryThreshold {
                return nil
            }
            return cachedToken.accessToken
        }
    }
    private var refreshingTask: Task<String, any Error>?
    private var storage: any StorageProtocol

    public init(credential: any Credential, clock: some Clock<Duration> = .continuous) {
        self.credential = credential
        self.storage = Storage(clock: clock)
    }

    public func accessToken(forceRefresh: Bool = false) async throws -> String {
        if forceRefresh {
            return try await refreshToken()
        }
        guard let token = storage.cachedAccessToken else {
            return try await refreshToken()
        }

        return token
    }

    private func refreshToken() async throws -> String {
        if let task = refreshingTask {
            return try await task.value
        }

        let task = Task<String, any Error> {
            let tokenResponse = try await credential.getAccessToken()
            storage.store(result: tokenResponse)
            return tokenResponse.accessToken
        }
        refreshingTask = task
        defer { refreshingTask = nil }

        return try await task.value
    }
}
