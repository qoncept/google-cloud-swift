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
            var type: String
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

// TODO: repeatedやその他高度な構造には非対応
protocol SQLRow {
    var allColumns: [String] { get }
    func contains(column: String) -> Bool
    func decodeNil(column: String) throws -> Bool
    func decode<D>(column: String, as type: D.Type) throws -> D where D: Decodable
}

struct BigQueryQueryResponseView: SQLRow {
    var allColumns: [String] {
        columns.map(\.name)
    }
    var columns: [BigQueryQueryResponse.TableSchema.TableFieldSchema]
    var row: BigQueryQueryResponse.Row

    init(response: BigQueryQueryResponse, row: BigQueryQueryResponse.Row) {
        self.columns = response.schema?.fields ?? []
        self.row = row
    }

    func contains(column: String) -> Bool {
        columns.contains { $0.name == column }
    }

    enum _Error: Error {
        case missingColumn
        case typeMismatch
    }

    func decodeNil(column: String) throws -> Bool {
        guard let i = columns.firstIndex(where: { $0.name == column}) else {
            return true
        }
        switch row.f[i] {
        case .nonRepeating(.none):
            return true
        default:
            return false
        }
    }

    func decode<D: Decodable>(column: String, as type: D.Type) throws -> D {
        guard let i = columns.firstIndex(where: { $0.name == column}) else {
            throw _Error.missingColumn
        }

        switch row.f[i] {
        case .nonRepeating(.some(let value)):
            return try BigQueryDataTranslation.decode(type, dataType: columns[i].type, dataValue: value)
        default:
            throw _Error.typeMismatch
        }
    }
}

struct SQLRowDecoder {
    init() {
    }

    func decode<T: Decodable>(_ type: T.Type, from row: some SQLRow) throws -> T {
        return try T.init(from: _Decoder(row: row))
    }

    enum _Error: Error {
        case nesting
        case unkeyedContainer
        case singleValueContainer
    }

    struct _Decoder<Row: SQLRow>: Decoder {
        var row: Row
        var codingPath: [any CodingKey]
        var userInfo: [CodingUserInfoKey : Any] {
            [:]
        }

        fileprivate init(row: Row, codingPath: [any CodingKey] = []) {
            self.row = row
            self.codingPath = codingPath
        }

        func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
            .init(_KeyedDecoder(referencing: self, row: row, codingPath: codingPath))
        }

        func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw _Error.unkeyedContainer
        }

        func singleValueContainer() throws -> any SingleValueDecodingContainer {
            throw _Error.singleValueContainer
        }
    }

    struct _KeyedDecoder<Row: SQLRow, Key: CodingKey>: KeyedDecodingContainerProtocol {
        var decoder: _Decoder<Row>
        var row: Row
        var codingPath: [any CodingKey]
        var allKeys: [Key] {
            row.allColumns.compactMap(Key.init(stringValue:))
        }

        fileprivate init(referencing decoder: _Decoder<Row>, row: Row, codingPath: [any CodingKey] = []) {
            self.decoder = decoder
            self.row = row
            self.codingPath = codingPath
        }

        private func column(for key: Key) -> String {
            key.stringValue
        }

        func contains(_ key: Key) -> Bool {
            row.contains(column: column(for: key))
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            try row.decodeNil(column: column(for: key))
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T
        where T : Decodable
        {
            try row.decode(column: column(for: key), as: T.self)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey
        {
            throw _Error.nesting
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw _Error.nesting
        }

        func superDecoder() throws -> any Decoder {
            _Decoder(row: row, codingPath: codingPath)
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw _Error.nesting
        }
    }
}
