import Foundation

struct EmulatorCredential: RichCredential & Sendable {
    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        GoogleOAuthAccessToken(
            accessToken: "owner",
            exipresIn: 3600
        )
    }

    var clientEmail: String { "owner@example.com" }
    var projectID: String { "testing-project-id" }

    func sign(data: Data) async throws -> Data {
        data
    }
}
