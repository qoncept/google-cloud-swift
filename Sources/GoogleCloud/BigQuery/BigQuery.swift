import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import NIOHTTP1

let bigqueryEmulatorHostEnvVar = "BIGQUERY_EMULATOR_HOST"
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

        var credentialStore = credentialStore
        let baseURL: URL
        if let emulatorHost = ProcessInfo.processInfo.environment[bigqueryEmulatorHostEnvVar] {
            baseURL = URL(string: "http://\(emulatorHost)/")!
            credentialStore = CredentialStore(credential: .makeEmulatorCredential())
        } else {
            baseURL = defaultAPIEndpoint
        }

        self.credentialStore = credentialStore
        authorizedClient = .init(
            baseURL: baseURL,
            credentialStore: credentialStore,
            httpClient: client
        )
    }

    public func query<Row: Decodable>(
        _ query: BigQueryQueryString,
        decoding rowType: Row.Type
    ) async throws -> [Row] {
        let (query, binds) = BigQueryDataTranslation.encode(query)
        let response = try await authorizedClient.post(
            path: "bigquery/v2/projects/\(projectID)/queries",
            payload: BigQueryQueryRequest(query: query, queryParameters: binds),
            responseType: BigQueryQueryResponse.self
        )

        if let errors = response.errors, !errors.isEmpty {
            throw BigQueryErrors(errors: errors)
        }

        return try response.rows.map { row in
            return try BigQueryRowDecoder()
                .decode(Row.self, from: BigQueryQueryResponseView(response: response, row: row))
        }
    }
}
