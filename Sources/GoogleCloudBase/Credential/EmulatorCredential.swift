import Foundation

package struct EmulatorCredential: RichCredential & Sendable {
    package init() {}
    package func getAccessToken() async throws -> AccessToken {
        AccessToken("owner")
    }

    package var clientEmail: String { "owner@example.com" }
    package var projectID: String { "testing-project-id" }

    package func sign(data: Data) async throws -> Data {
        struct EmulatorCredentialCannotSign: Error {}
        throw EmulatorCredentialCannotSign()
    }
}
