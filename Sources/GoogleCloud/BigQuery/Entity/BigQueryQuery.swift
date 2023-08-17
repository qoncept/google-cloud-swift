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

struct BigQueryQueryResponse: Decodable {
    struct TableSchema: Decodable {
        struct TableFieldSchema: Decodable {
            var name: String
            var type: BigQueryDataType
            var mode: String?
            var fields: [TableFieldSchema]?
        }
        var fields: [TableFieldSchema]
    }
    var schema: TableSchema?

    struct Row: Decodable {
        struct NestedColumnValue: Decodable {
            var v: Row
        }

        enum Value: Decodable {
            case repeating([NestedColumnValue])
            case nonRepeating(String?)

            enum CodingKeys: String, CodingKey {
                case v
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let value = try? container.decode(String.self, forKey: .v) {
                    self = .nonRepeating(value)
                } else if let list = try? container.decode([NestedColumnValue].self, forKey: .v) {
                    self = .repeating(list)
                } else if (try? container.decodeNil(forKey: .v)) == true {
                    self = .nonRepeating(nil)
                } else {
                    throw _Error.missingValue
                }
            }

            enum _Error: Error {
                case missingValue
            }
        }

        var f: [Value]
    }

    var rows: [Row]
    var totalRows: String?
    var pageToken: String?
    var errors: [BigQueryError]?
}
