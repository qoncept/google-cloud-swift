// INFO: https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#numeric_types

public enum BigQueryDataType: String, CaseIterable, Codable, Sendable {
    case array = "ARRAY"
    case bignumeric = "BIGNUMERIC"
    case bool = "BOOL"
    case bytes = "BYTES"
    case date = "DATE"
    case datetime = "DATETIME"
    case float64 = "FLOAT64"
    case geography = "GEOGRAPHY"
    case int64 = "INT64"
    case interval = "INTERVAL"
    case json = "JSON"
    case numeric = "NUMERIC"
    case string = "STRING"
    case `struct` = "STRUCT"
    case time = "TIME"
    case timestamp = "TIMESTAMP"
    case record = "RECORD"

    public init?(rawValue: String) {
        if let c = Self.allCases.first(where: { $0.rawValue == rawValue }) {
            self = c
        } else {
            switch rawValue {
            case "BOOLEAN":
                self = .bool
            case "FLOAT":
                self = .float64
            case "INT", "SMALLINT", "INTEGER", "BIGINT", "TINYINT", "BYTEINT":
                self = .int64
            case "DECIMAL":
                self = .numeric
            case "BIGDECIMAL":
                self = .bignumeric
            default:
                return nil
            }
        }
    }
}
