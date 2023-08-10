import Foundation

// https://cloud.google.com/bigquery/docs/reference/rest/v2/jobs/query#QueryRequest

struct BigQueryQueryRequest: Encodable {
    var kind: String? // ?
    var query: String

    struct DatasetReference: Encodable {
        var datasetId: String
        var projectId: String?
    }
    var defaultDataset: DatasetReference?
    var timeoutMs: Int?
    var dryRun: Bool?
    var useQueryCache: Bool?
    var useLegacySql: Bool?

    // https://cloud.google.com/bigquery/docs/parameterized-queries?#api
    struct QueryParameter: Encodable {
        var name: String
        struct `Type`: Encodable {
            var type: String
            // arrayType and structTypes is not yet supported
        }
        var parameterType: Type
        struct Value: Encodable {
            var value: String
            // arrayType and structTypes is not yet supported
        }
        var parameterValue: Value
    }
    var queryParameters: [QueryParameter]
}

struct BigQueryQueryResponse<Row: Decodable>: Decodable {
    var rows: [Row]
    var totalRows: String?
    var pageToken: String?
    var errors: [BigQueryError]?
}
