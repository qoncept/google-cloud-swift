import Foundation
@testable import GoogleCloud
import NIOPosix
import Testing

@Suite(
    .gcpClient,
    .enabled(if: ProcessInfo.processInfo.environment[bigqueryEmulatorHostEnvVar] != nil, "BigQueryTest uses BigQuery Emulator.")
) struct BigQueryTest {
    private func makeBigQuery() -> BigQuery {
        BigQuery(
            client: .mockCredentialClient,
            projectID: "testing-project-id"
        )
    }

    @Test func bigQueryQueryResponseDecode() throws {
        let data = #"""
{"jobReference":{"jobId":"coyNAgTg6wfkrPHVDRqlyhov5UQ","projectId":"testing-project-id"},"schema":{"fields":[{"name":"id","type":"INTEGER"},{"name":"name","type":"STRING"},{"fields":[{"name":"key","type":"STRING"},{"name":"value","type":"JSON"}],"mode":"REPEATED","name":"structarr","type":"RECORD"},{"name":"birthday","type":"DATE"},{"name":"skillNum","type":"NUMERIC"},{"name":"created_at","type":"TIMESTAMP"}]},"rows":[{"f":[{"v":"1"},{"v":"alice"},{"v":[{"v":{"f":[{"v":"profile"},{"v":"{\"age\": 10}"}]}}]},{"v":"2012-01-01"},{"v":"3"},{"v":"1641038400.0"}]},{"f":[{"v":"2"},{"v":"bob"},{"v":[{"v":{"f":[{"v":"profile"},{"v":"{\"age\": 15}"}]}}]},{"v":"2007-02-01"},{"v":null},{"v":"1641146400.0"}]}],"totalRows":"2","jobComplete":true}
"""#.data(using: .utf8)!

        let _ = try JSONDecoder().decode(BigQueryQueryResponse.self, from: data)
    }

    @Test func basic() async throws {
        let bigQuery = makeBigQuery()

        struct Row: Decodable {
            var id: Int
            var name: String
            var skillNum: Int?
            var created_at: Date
        }
        let rows = try await bigQuery.query(
            "SELECT id, name, birthday, skillNum, created_at FROM dataset1.table_a",
            decoding: Row.self
        )

        #expect(rows.count == 2)
        #expect(rows[0].id == 1)
        #expect(rows[0].name == "alice")
        #expect(rows[0].skillNum == 3)
        #expect(rows[0].created_at == Date(timeIntervalSince1970: 1641038400))
        #expect(rows[1].skillNum == nil)
    }

    @Test func decodePrimitives() async throws {
        let bigQuery = makeBigQuery()

        struct Row: Decodable {
            var bool: Bool
            var int: Int
            var float: Float
            var string: String
            var optional: Int?
            var timestamp: Date
            var datetime: Date
        }
        let now = Date()
        let rows = try await bigQuery.query("""
            SELECT
                true AS `bool`
                , 1 AS `int`
                , 0.5 AS `float`
                , 'hello' AS `string`
                , null AS `optional`
                , CURRENT_TIMESTAMP() AS `timestamp`
                , CURRENT_DATETIME() AS `datetime`
        """, decoding: Row.self)

        #expect(rows.count == 1)
        #expect(rows[0].bool == true)
        #expect(rows[0].int == 1)
        #expect(rows[0].float == 0.5)
        #expect(rows[0].string == "hello")
        #expect(rows[0].optional == nil)
        #expect(abs(rows[0].timestamp.timeIntervalSince1970 - now.timeIntervalSince1970) < 1)
        #expect(abs(rows[0].datetime.timeIntervalSince1970 - now.timeIntervalSince1970) < 1)
    }

    @Test func parameter() async throws {
        let bigQuery = makeBigQuery()

        struct Row: Decodable {
            var id: Int
            var name: String
            var skillNum: Int?
            var created_at: Date
        }
        let rows = try await bigQuery.query(
            "SELECT * FROM dataset1.table_a WHERE id = \(bind: 1)",
            decoding: Row.self
        )

        #expect(rows.count == 1)
        #expect(rows[0].id == 1)
    }
}
