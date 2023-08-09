import FirebaseAdmin
import Foundation

final class MockCredential: Credential, @unchecked Sendable {
    struct UndefinedError: Error {}

    var getAccessTokenCalled: Int = 0
    var getAccessTokenDelay: TimeInterval = 0
    var getAccessTokenResult: Result<GoogleOAuthAccessToken, any Error> = .failure(UndefinedError())

    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        getAccessTokenCalled += 1
        try await Task.sleep(nanoseconds: UInt64(getAccessTokenDelay * 1000 * 1000 * 1000))
        return try getAccessTokenResult.get()
    }
}
