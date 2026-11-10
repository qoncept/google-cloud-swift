import FirebaseAdmin
import Foundation
import Testing

private let mockBaseURL = ProcessInfo.processInfo.environment["HTTPMOCK_BASE_URL"].flatMap(URL.init(string:))

@Suite(
    .enabled(if: mockBaseURL != nil, "MessagingHTTPMockTest uses an HTTP mock server."),
    .gcpClient { credential in
        credential.getAccessTokenResult = .success(AccessToken(rawValue: "test-access-token"))
    }
)
struct MessagingHTTPMockTest: ~Copyable {
    private func makeMessaging() throws -> Messaging {
        return try Messaging(
            client: .mockCredentialClient,
            projectID: "testing-project-id",
            baseURL: try #require(mockBaseURL)
        )
    }

    @Test func sendsMessage() async throws {
        let messaging = try makeMessaging()
        let message = Message(target: .token("valid-device"))

        let name = try await messaging.send(message, validateOnly: true)

        #expect(name == "projects/testing-project-id/messages/123")
    }

    @Test func returnsFCMError() async throws {
        let messaging = try makeMessaging()
        let message = Message(target: .token("unregistered-device"))

        do {
            _ = try await messaging.send(message)
            Issue.record("Expected an FCM error")
        } catch let error as MessagingError {
            #expect(error.statusCode == 404)
            #expect(error.status == "NOT_FOUND")
            #expect(error.message == "Requested entity was not found.")
            #expect(error.fcmErrorCode == "UNREGISTERED")
            #expect(error.isUnregistered)
            #expect(error.headers.first(name: "Retry-After") == "120")
        }
    }

    @Test func rejectsUnmatchedRequest() async throws {
        let messaging = try makeMessaging()
        let message = Message(target: .token("valid-device"))

        do {
            _ = try await messaging.send(message)
            Issue.record("Expected an unmatched request error")
        } catch let error as MessagingError {
            #expect(error.statusCode == 404)
            #expect(!error.isUnregistered)
            #expect(error.fcmErrorCode == nil)
        }
    }
}
