import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import NIOConcurrencyHelpers
import NIOHTTP1

let bigqueryEmulatorHostEnvVar = "BIGQUERY_EMULATOR_HOST"
private let defaultAPIEndpoint = URL(string: "https://bigquery.googleapis.com/")!

public struct BigQuery: Sendable {
    public var projectID: String
    private let credentialStore: CredentialStore
    private var authorizedClient: AuthorizedClient

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

    public struct QueryOptions {
        public init(maxResults: Int? = nil, useLegacySql: Bool = false) {
            self.maxResults = maxResults
            self.useLegacySql = useLegacySql
        }
        public var maxResults: Int?
        public var useLegacySql: Bool = false
    }

    public func query<Row: Decodable>(
        _ query: BigQueryQueryString,
        options: QueryOptions = QueryOptions(),
        decoding rowType: Row.Type
    ) async throws -> [Row] {
        return try await queryStream(query, options: options, decoding: rowType)
            .reduce(into: [], { $0.append(contentsOf: $1) })
    }

    public func queryStream<Row: Decodable>(
        _ query: BigQueryQueryString,
        options: QueryOptions = QueryOptions(),
        decoding rowType: Row.Type
    ) -> AsyncThrowingStream<[Row], any Error> {
        return AsyncThrowingStream([Row].self, bufferingPolicy: .unbounded) { (continuetion) in
            let cancel = NIOLockedValueBox(false)

            continuetion.onTermination = { (termination) in
                cancel.withLockedValue { value in
                    value = true
                }
            }

            Task {
                let decoder = BigQueryRowDecoder()
                do {
                    let response = try await queryInternal(query, options: options)
                    var nextPageToken: String? = response.pageToken

                    let decoded = try response.rows.map {
                        try decoder.decode(rowType, from: BigQueryQueryResponseView(response: response, row: $0))
                    }
                    if case .terminated = continuetion.yield(decoded) {
                        nextPageToken = nil
                    }

                    while let pageToken = nextPageToken, !pageToken.isEmpty,
                          !cancel.withLockedValue({ $0 }) {
                        let response = try await getQueryResult(
                            jobReference: response.jobReference,
                            pageToken: pageToken,
                            options: options
                        )

                        let decoded = try response.rows.map {
                            try decoder.decode(rowType, from: BigQueryQueryResponseView(response: response, row: $0))
                        }
                        if case .terminated = continuetion.yield(decoded) {
                            break
                        }

                        nextPageToken = response.pageToken
                    }
                    
                    continuetion.finish()
                } catch {
                    continuetion.finish(throwing: error)
                }
            }
        }
    }

    private func queryInternal(
        _ query: BigQueryQueryString,
        options: QueryOptions = QueryOptions()
    ) async throws -> BigQueryQueryResponse {
        let (query, binds) = BigQueryDataTranslation.encode(query)

        var request = BigQueryQueryRequest(query: query, queryParameters: binds)
        request.maxResults = options.maxResults
        request.useLegacySql = options.useLegacySql

        let response = try await authorizedClient.post(
            path: "bigquery/v2/projects/\(projectID)/queries",
            payload: request,
            responseType: BigQueryQueryResponse.self
        )

        if let errors = response.errors, !errors.isEmpty {
            throw BigQueryErrors(errors: errors)
        }

        return response
    }

    private func getQueryResult(
        jobReference: BigQueryQueryResponse.JobReference,
        pageToken: String,
        options: QueryOptions
    ) async throws -> BigQueryQueryResponse {
        let response = try await authorizedClient.get(
            path: "bigquery/v2/projects/\(jobReference.projectId)/queries/\(jobReference.jobId)",
            queryItems: [
                .init(name: "pageToken", value: pageToken),
                options.maxResults.map { .init(name: "maxResults", value: $0.description) },
                .init(name: "location", value: jobReference.location),
            ].compactMap({ $0 }),
            responseType: BigQueryQueryResponse.self
        )

        if let errors = response.errors, !errors.isEmpty {
            throw BigQueryErrors(errors: errors)
        }

        return response
    }
}
