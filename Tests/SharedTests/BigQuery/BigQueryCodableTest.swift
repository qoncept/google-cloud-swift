import Foundation
import GoogleCloud
import XCTest

final class BigQueryCodableTest: XCTestCase {
    func testDatetime() {
        XCTAssertNoThrow(
            try Date(dataType: .datetime, dataValue: "1992-08-22T00:00:00")
        )

        XCTAssertNoThrow(
            try Date(dataType: .datetime, dataValue: "1992-08-22T00:00:00.000000")
        )
    }

    func testTimestamp() {
        XCTAssertNoThrow(
            try Date(dataType: .timestamp, dataValue: "1641038400")
        )
        XCTAssertNoThrow(
            try Date(dataType: .timestamp, dataValue: "1641038400.000000")
        )
    }
}

// auto conformance check
fileprivate struct MyValueD: RawRepresentable {
    var rawValue: String
}
extension MyValueD: BigQueryDecodable {}

fileprivate struct MyValueE: RawRepresentable {
    var rawValue: String
}
extension MyValueE: BigQueryEncodable {}
