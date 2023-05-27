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
        ) async throws -> Response {
            try await authorizedClient.post(
                path: makeUserMtgPath(path: path),
                headers: [
                    "X-Goog-User-Project": projectID,
                ],
                payload: payload,
                responseType: responseType
            )
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
