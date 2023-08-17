@testable import GoogleCloud
import NIOPosix
import XCTest

final class BigQueryTest: XCTestCase {
    private static let client = AsyncHTTPClient.HTTPClient(eventLoopGroupProvider: .singleton)

    override class func setUp() {
        super.setUp()
        initLogger()
    }

    override class func tearDown() {
        do {
            try client.syncShutdown()
        } catch {
            XCTFail("\(error)")
        }

        super.tearDown()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(ProcessInfo.processInfo.environment[bigqueryEmulatorHostEnvVar] == nil, "BigQueryTest uses BigQuery Emulator.")
    }

    private func makeBigQuery() -> BigQuery {
        BigQuery(
            projectID: "testing-project-id",
            credentialStore: CredentialStore(credential: MockCredential()),
            client: Self.client
        )
    }

    func testBigQueryQueryResponseDecode() throws {
        let data = #"""
{"jobReference":{"jobId":"coyNAgTg6wfkrPHVDRqlyhov5UQ","projectId":"testing-project-id"},"schema":{"fields":[{"name":"id","type":"INTEGER"},{"name":"name","type":"STRING"},{"fields":[{"name":"key","type":"STRING"},{"name":"value","type":"JSON"}],"mode":"REPEATED","name":"structarr","type":"RECORD"},{"name":"birthday","type":"DATE"},{"name":"skillNum","type":"NUMERIC"},{"name":"created_at","type":"TIMESTAMP"}]},"rows":[{"f":[{"v":"1"},{"v":"alice"},{"v":[{"v":{"f":[{"v":"profile"},{"v":"{\"age\": 10}"}]}}]},{"v":"2012-01-01"},{"v":"3"},{"v":"1641038400.0"}]},{"f":[{"v":"2"},{"v":"bob"},{"v":[{"v":{"f":[{"v":"profile"},{"v":"{\"age\": 15}"}]}}]},{"v":"2007-02-01"},{"v":null},{"v":"1641146400.0"}]}],"totalRows":"2","jobComplete":true}
"""#.data(using: .utf8)!

        let _ = try JSONDecoder().decode(BigQueryQueryResponse.self, from: data)
    }

    func testBasic() async throws {
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

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].id, 1)
        XCTAssertEqual(rows[0].name, "alice")
        XCTAssertEqual(rows[0].skillNum, 3)
        XCTAssertEqual(rows[0].created_at, Date(timeIntervalSince1970: 1641038400))
        XCTAssertEqual(rows[1].skillNum, nil)
    }

    func testDecodePrimitives() async throws {
        let bigQuery = makeBigQuery()

        struct Row: Decodable {
            var bool: Bool
            var int: Int
            var float: Float
            var string: String
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
                , CURRENT_TIMESTAMP() AS `timestamp`
                , CURRENT_DATETIME() AS `datetime`
        """, decoding: Row.self)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].bool, true)
        XCTAssertEqual(rows[0].int, 1)
        XCTAssertEqual(rows[0].float, 0.5)
        XCTAssertEqual(rows[0].string, "hello")
        XCTAssertEqual(rows[0].timestamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(rows[0].datetime.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
    }

    func testParameter() async throws {
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

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, 1)
    }
}
