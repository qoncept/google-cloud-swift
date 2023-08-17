import Foundation

// https://cloud.google.com/bigquery/docs/reference/rest/v2/Job

struct BigQueryJobRequest: Encodable {
    struct Configuration: Encodable {
        struct Query: Encodable {
            var query: String
            struct TableReference: Encodable {
                var projectId: String
                var datasetId: String
                var tableId: String
            }
            var destinationTable: TableReference?
        }
        var query: Query?
        var dryRun: Bool
        @StringMilliUnixOptionalDate var jobTimeoutMs: Date?

        // umimplemented
        struct Load: Encodable {}
        var load: Load?
        struct Copy: Encodable {}
        var copy: Copy?
        struct Extract: Encodable {}
        var extract: Extract?
    }
    var configuration: Configuration
}

struct BigQueryJobResponse: Decodable {
    
}
