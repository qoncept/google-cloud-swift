import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import NIOHTTP1

private let defaultAPIEndpoint = URL(string: "https://bigquery.googleapis.com/")!

public struct BigQuery: Sendable {
    public var projectID: String
    private let credentialStore: CredentialStore
    private let authorizedClient: AuthorizedClient

    public init(
        projectID: String,
        credentialStore: CredentialStore,
        client: AsyncHTTPClient.HTTPClient
    ) {
        self.projectID = projectID
        self.credentialStore = credentialStore
        authorizedClient = .init(
            baseURL: defaultAPIEndpoint,
            credentialStore: credentialStore,
            httpClient: client
        )
    }

    public func query<Row: Decodable>(
        _ query: BigQueryQueryString,
        decoding rowType: Row.Type
    ) async throws -> [Row] {
        let request = BigQueryQueryEncoder.encode(query)
        let response = try await authorizedClient.post(
            path: "bigquery/v2/projects/\(projectID)/queries",
            payload: request,
            responseType: BigQueryQueryResponse<Row>.self
        )

        if let errors = response.errors, !errors.isEmpty {
            throw BigQueryErrors(errors: errors)
        }

        return response.rows
    }
}
