import Foundation

// TODO: repeatedやその他高度な構造には非対応
protocol SQLRow {
    var allColumns: [String] { get }
    func contains(column: String) -> Bool
    func decodeNil(column: String) throws -> Bool
    func decode<D>(column: String, as type: D.Type, codingPath: [any CodingKey]) throws -> D where D: Decodable
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

    func decode<D: Decodable>(column: String, as type: D.Type, codingPath: [any CodingKey]) throws -> D {
        guard let i = columns.firstIndex(where: { $0.name == column}) else {
            throw _Error.missingColumn
        }

        switch row.f[i] {
        case .nonRepeating(.some(let value)):
            return try BigQueryDataTranslation.decode(type, dataType: columns[i].type, dataValue: value, codingPath: codingPath)
        default:
            throw _Error.typeMismatch
        }
    }
}

struct BigQueryRowDecoder {
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

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T
        {
            try row.decode(
                column: column(for: key),
                as: T.self,
                codingPath: codingPath + CollectionOfOne<any CodingKey>(key)
            )
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey>
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
