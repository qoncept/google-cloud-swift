import Foundation

private let tokenExpiryThreshold: TimeInterval = 5 * 60

struct OAuth2Token {
    var accessToken: String
    var expiry: Date
}

public actor CredentialStore {
    let credential: Credential
    nonisolated public var compilersafeCredential: Credential {
        // 外のモジュールが「actorに生えたSendableなlet変数」をawaitするとコンパイラがクラッシュするので、その回避
        credential
    }
    private let clock: Clock
    private var cachedToken: OAuth2Token?

    private var refreshingTask: Task<OAuth2Token, Error>?

    public init(credential: Credential, clock: Clock = .default) {
        self.credential = credential
        self.clock = clock
    }

    public func accessToken(forceRefresh: Bool = false) async throws -> String {
        if forceRefresh || shouldRefresh() {
            return try await refreshToken().accessToken
        }
        guard let token = cachedToken else {
            return try await refreshToken().accessToken
        }

        return token.accessToken
    }

    private func shouldRefresh() -> Bool {
        guard let cachedToken = cachedToken else {
            return true
        }
        return cachedToken.expiry.timeIntervalSince(clock.now()) <= tokenExpiryThreshold
    }

    private func refreshToken() async throws -> OAuth2Token {
        if let refreshingTask = refreshingTask {
            return try await refreshingTask.value
        }

        let task = Task<OAuth2Token, Error> {
            let rawTokenResponse = try await credential.getAccessToken()
            let newToken = OAuth2Token(
                accessToken: rawTokenResponse.accessToken,
                expiry: clock.now() + rawTokenResponse.exipresIn
            )

            cachedToken = newToken
            return newToken
        }
        refreshingTask = task
        defer { refreshingTask = nil }

        return try await task.value
    }
}
