import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix

let bigqueryEmulatorHostEnvVar = "BIGQUERY_EMULATOR_HOST"
private let defaultAPIEndpoint = URL(string: "https://bigquery.googleapis.com/")!

public struct BigQuery: Sendable {
    public var projectID: String
    private var authorizedClient: AuthorizedClient
    public var threadPool: NIOThreadPool

    public init(
        client: GCPClient,
        projectID: String,
        threadPool: NIOThreadPool = NIOThreadPool.singleton
    ) {
        self.projectID = projectID

        var credential = client.credential
        let baseURL: URL
        if let emulatorHost = ProcessInfo.processInfo.environment[bigqueryEmulatorHostEnvVar] {
            baseURL = URL(string: "http://\(emulatorHost)/")!
            credential = EmulatorCredential()
        } else {
            baseURL = defaultAPIEndpoint
        }

        authorizedClient = .init(
            baseURL: baseURL,
            gcpClient: client,
            credential: credential
        )
        self.threadPool = threadPool
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
        decoding rowType: Row.Type,
        timeout: TimeAmount = .seconds(60),
        logger: Logger? = nil
    ) async throws -> [Row] {
        return try await queryStream(query, options: options, decoding: rowType, timeout: timeout, logger: logger)
            .reduce(into: [], { $0.append(contentsOf: $1) })
    }

    public func queryStream<Row: Decodable>(
        _ query: BigQueryQueryString,
        options: QueryOptions = QueryOptions(),
        decoding rowType: Row.Type,
        timeout: TimeAmount = .seconds(60),
        logger: Logger? = nil
    ) -> AsyncThrowingStream<[Row], any Error> {
        return AsyncThrowingStream([Row].self, bufferingPolicy: .unbounded) { (continuetion) in
            let task = Task {
                let decoder = BigQueryRowDecoder()
                do {
                    @Sendable func asyncDecode(response: BigQueryQueryResponse) async throws {
                        if response.rows.isEmpty { return }
                        try await threadPool.runIfActive {
                            let decoded = try response.rows.map {
                                try decoder.decode(rowType, from: BigQueryQueryResponseView(response: response, row: $0))
                            }
                            if case .terminated = continuetion.yield(decoded) {
                                throw CancellationError()
                            }
                        }
                    }

                    let response = try await queryInternal(
                        query,
                        options: options,
                        timeout: timeout,
                        logger: logger
                    )

                    var nextPageToken: String? = response.pageToken
                    var nextRows: BigQueryQueryResponse = response

                    repeat {
                        let currentPageToken = nextPageToken
                        let currentRows = nextRows

                        if let pageToken = currentPageToken, !pageToken.isEmpty {
                            async let fetch = try await getQueryResult(
                                jobReference: response.jobReference,
                                pageToken: pageToken,
                                options: options,
                                timeout: timeout,
                                logger: logger
                            )
                            
                            try await asyncDecode(response: currentRows)

                            let fetchResult = try await fetch
                            (nextPageToken, nextRows) = (fetchResult.pageToken, fetchResult)
                        } else {
                            try await asyncDecode(response: currentRows)
                            nextPageToken = nil
                            nextRows.rows = []
                        }
                    } while nextPageToken != nil || !nextRows.rows.isEmpty

                    continuetion.finish()
                } catch {
                    continuetion.finish(throwing: error)
                }
            }

            continuetion.onTermination = { (termination) in
                task.cancel()
            }
        }
    }

    private func queryInternal(
        _ query: BigQueryQueryString,
        options: QueryOptions = QueryOptions(),
        timeout: TimeAmount,
        logger: Logger?
    ) async throws -> BigQueryQueryResponse {
        let (query, binds) = BigQueryDataTranslation.encode(query)

        var request = BigQueryQueryRequest(query: query, queryParameters: binds)
        request.maxResults = options.maxResults
        request.useLegacySql = options.useLegacySql

        let response = try await authorizedClient.execute(
            method: .POST,
            path: "bigquery/v2/projects/\(projectID)/queries",
            payload: .json(request),
            timeout: timeout,
            logger: logger,
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
        options: QueryOptions,
        timeout: TimeAmount,
        logger: Logger?
    ) async throws -> BigQueryQueryResponse {
        let response = try await authorizedClient.execute(
            method: .GET,
            path: "bigquery/v2/projects/\(jobReference.projectId)/queries/\(jobReference.jobId)",
            queryItems: [
                .init(name: "pageToken", value: pageToken),
                options.maxResults.map { .init(name: "maxResults", value: $0.description) },
                .init(name: "location", value: jobReference.location),
            ].compactMap({ $0 }),
            timeout: timeout,
            logger: logger,
            responseType: BigQueryQueryResponse.self
        )

        if let errors = response.errors, !errors.isEmpty {
            throw BigQueryErrors(errors: errors)
        }

        return response
    }
}
