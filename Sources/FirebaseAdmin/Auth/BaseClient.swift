import AsyncHTTPClient
import Foundation
import GoogleCloudBase

extension Auth {
    struct BaseClient {
        let authorizedClient: AuthorizedClient
        let projectID: String
        var tenantID: String?

        init(
            authorizedClient: AuthorizedClient,
            projectID: String,
            tenantID: String?
        ) {
            self.authorizedClient = authorizedClient
            self.projectID = projectID
            self.tenantID = tenantID
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
