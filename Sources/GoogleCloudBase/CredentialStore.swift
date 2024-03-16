import Foundation

private let tokenExpiryThreshold: Duration = .seconds(5 * 60)

public actor CredentialStore {
    private let credentialTask: Task<any Credential, any Error>
    private var refreshingTask: Task<String, any Error>?
    private var storage: any DurationalCacheProtocol<String>

    public init(
        context: CredentialFactory.Context,
        credentialFactory: CredentialFactory,
        clock: some Clock<Duration> = .continuous
    ) {
        self.credentialTask = Task {
            try await credentialFactory.makeCredential(context: context)
        }
        self.storage = DurationalCache(clock: clock)
    }

    public var credential: any Credential {
        get async throws {
            try await credentialTask.value
        }
    }

    public func accessToken(forceRefresh: Bool = false) async throws -> String {
        if forceRefresh {
            return try await refreshToken()
        }
        guard let token = storage.cachedValue else {
            return try await refreshToken()
        }

        return token
    }

    private func refreshToken() async throws -> String {
        if let task = refreshingTask {
            return try await task.value
        }

        let task = Task<String, any Error> {
            let tokenResponse = try await credentialTask.value.getAccessToken()
            storage.store(value: tokenResponse.accessToken, expiresIn: .seconds(tokenResponse.exipresIn) - tokenExpiryThreshold)
            return tokenResponse.accessToken
        }
        refreshingTask = task
        defer { refreshingTask = nil }

        return try await task.value
    }
}
