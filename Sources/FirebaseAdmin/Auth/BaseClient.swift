import AsyncHTTPClient
import Foundation
import GoogleCloudBase

private let defaultAuthURL = URL(string: "https://identitytoolkit.googleapis.com")!
let emulatorHostEnvVar = "FIREBASE_AUTH_EMULATOR_HOST"
private let emulatorToken = "owner"
private let sdkVersion = "0.0.1"

extension Auth {
    struct BaseClient {
        let authorizedClient: AuthorizedClient
        let projectID: String

        var tenantID: String?

        init(
            credentialStore: CredentialStore,
            client: HTTPClient,
            projectID: String
        ) {
            self.projectID = projectID

            let baseURL: URL
            let isEmulator: Bool
            if let authEmulatorHost = ProcessInfo.processInfo.environment[emulatorHostEnvVar] {
                baseURL = URL(string: "http://\(authEmulatorHost)/identitytoolkit.googleapis.com")!
                isEmulator = true
            } else {
                baseURL = defaultAuthURL
                isEmulator = false
            }

            let idToolkitV1Endpoint = baseURL.appendingPathComponent("v1")
            let userManagementEndpoint = idToolkitV1Endpoint

            authorizedClient = .init(
                baseURL: userManagementEndpoint,
                credentialStore: credentialStore,
                httpClient: client,
                isEmulator: isEmulator
            )
        }

        func post<Body: Encodable, Response: Decodable>(
            path: String,
            payload: Body,
            responseType: Response.Type
        ) async throws -> Result<Response, FirebaseAuthError> {
            do {
                let response = try await authorizedClient.post(
                    path: makeUserMtgPath(path: path),
                    headers: [
                        "X-Goog-User-Project": projectID,
                    ],
                    payload: payload,
                    responseType: responseType
                )
                return .success(response)
            } catch {
                guard let error = error as? GoogleCloudBase.ErrorResponse else {
                    throw error
                }

                let string = error.error.message

                var codeString = string.trimmingCharacters(in: .whitespaces)
                var messageString: String? = nil
                if let index = string.firstIndex(of: ":") {
                    codeString = string[..<index].trimmingCharacters(in: .whitespaces)
                    messageString = string[string.index(after: index)...].trimmingCharacters(in: .whitespaces)
                }

                guard let code = FirebaseAuthError.Code(rawValue: codeString) else { throw error }

                return .failure(
                    FirebaseAuthError(code: code, message: messageString)
                )
            }
        }

        private func makeUserMtgPath(path: String) -> String {
            let tmpURL = URL(fileURLWithPath: "/")
            if let tenantID = tenantID {
                return tmpURL.appendingPathComponent("projects")
                    .appendingPathComponent(projectID)
                    .appendingPathComponent("tenants")
                    .appendingPathComponent(tenantID)
                    .appendingPathComponent(path)
                    .path
            } else {
                return tmpURL.appendingPathComponent("projects")
                    .appendingPathComponent(projectID)
                    .appendingPathComponent(path)
                    .path
            }
        }
    }
}
