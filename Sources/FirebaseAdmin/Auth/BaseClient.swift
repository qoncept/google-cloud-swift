import NIOHTTP1
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

        func get<Response: Decodable>(
            path: String,
            queryItems: [URLQueryItem],
            responseType: Response.Type
        ) async throws -> Result<Response, FirebaseAuthError> {
            do {
                let response = try await authorizedClient.get(
                    path: makeUserMtgPath(path: path),
                    headers: makeHeaders(),
                    queryItems: queryItems,
                    responseType: responseType
                )
                return .success(response)
            } catch {
                return try handleClientError(error)
            }
        }

        func post<Body: Encodable, Response: Decodable>(
            path: String,
            payload: Body,
            responseType: Response.Type
        ) async throws -> Result<Response, FirebaseAuthError> {
            do {
                let response = try await authorizedClient.post(
                    path: makeUserMtgPath(path: path),
                    headers: makeHeaders(),
                    payload: payload,
                    responseType: responseType
                )
                return .success(response)
            } catch {
                return try handleClientError(error)
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

        private func makeHeaders() -> HTTPHeaders {
            [
                "X-Goog-User-Project": projectID,
            ]
        }

        private func handleClientError<T>(_ error: any Error) throws -> Result<T, FirebaseAuthError> {
            if let error = error as? GoogleCloudBase.ErrorResponse {
                if let error = FirebaseAuthError.decodeErrorResponseMessage(
                    message: error.error.message
                ) {
                    return .failure(error)
                }
            }

            throw error
        }
    }
}
