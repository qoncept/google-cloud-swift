import FirebaseAdmin
import Foundation

actor MockCredential: Credential {
    struct UndefinedError: Error {}

    var getAccessTokenCalled: Int = 0
    var getAccessTokenDelay: TimeInterval = 0
    var getAccessTokenResult: Result<AccessToken, any Error> = .failure(UndefinedError())

    func getAccessToken() async throws -> AccessToken {
        getAccessTokenCalled += 1
        try await Task.sleep(for: .seconds(getAccessTokenDelay))
        return try getAccessTokenResult.get()
    }
}

extension SyncCredentialFactory {
    static func mock(credential: MockCredential = MockCredential()) -> SyncCredentialFactory {
        return .custom { _ in credential }
    }
}
