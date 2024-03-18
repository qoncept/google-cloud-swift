import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import Logging
import NIOHTTP1

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
            logger: Logger?,
            responseType: Response.Type
        ) async throws -> Result<Response, FirebaseAuthError> {
            do {
                let response = try await authorizedClient.execute(
                    method: .GET,
                    path: makeUserMtgPath(path: path),
                    queryItems: queryItems,
                    headers: makeHeaders(),
                    logger: logger,
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
            logger: Logger?,
            responseType: Response.Type
        ) async throws -> Result<Response, FirebaseAuthError> {
            do {
                let response = try await authorizedClient.execute(
                    method: .POST,
                    path: makeUserMtgPath(path: path),
                    payload: .json(payload),
                    headers: makeHeaders(),
                    logger: logger,
                    responseType: responseType
                )
                return .success(response)
            } catch {
                return try handleClientError(error)
            }
        }

        private func makeUserMtgPath(path: String) -> String {
            let tmpURL = URL(fileURLWithPath: "/")
            if let tenantID {
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
