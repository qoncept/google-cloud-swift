import Foundation
import GoogleCloud
import Testing

@Suite struct BigQueryCodableTest {
    @Test func datetime() throws {
        let a = try Date(dataType: .datetime, dataValue: "1992-08-22T00:00:00")
        #expect(a == Date(timeIntervalSince1970: 714441600))

        let b = try Date(dataType: .datetime, dataValue: "1992-08-22T00:00:00.000000")
        #expect(b == Date(timeIntervalSince1970: 714441600))
    }

    @Test func timestamp() throws {
        let a = try Date(dataType: .timestamp, dataValue: "1641038400")
        #expect(a.timeIntervalSince1970 == 1641038400)

        let b = try Date(dataType: .timestamp, dataValue: "1641038400.000000")
        #expect(b.timeIntervalSince1970 == 1641038400)
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
