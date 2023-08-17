import Foundation

public protocol BigQueryEncodable {
    static var parameterDataType: String { get }
    func parameterDataValue() -> String
}

public protocol BigQueryDecodable {
    init(dataType: String, dataValue: String) throws
}

public typealias BigQueryCodable = BigQueryEncodable & BigQueryDecodable

// INFO: Data types
// https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types

extension CustomStringConvertible where Self: BigQueryEncodable {
    public func parameterDataValue() -> String {
        description
    }
}

extension LosslessStringConvertible where Self: BigQueryDecodable {
    public init(dataType: String, dataValue: String) throws {
        guard let result = Self.init(dataValue) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "\"\(dataValue)\" cannot convert to \(Self.self)"
            ))
        }
        self = result
    }
}

extension Int: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int8: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int16: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int32: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int64: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt8: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt16: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt32: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt64: BigQueryCodable {
    public static var parameterDataType: String { "INT64" }
}
extension Float16: BigQueryCodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension Float32: BigQueryCodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension Float64: BigQueryCodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension String: BigQueryCodable {
    public static var parameterDataType: String { "STRING" }
}
extension Bool: BigQueryCodable {
    public static var parameterDataType: String { "BOOL" }
}
extension Date: BigQueryCodable {
    public static var parameterDataType: String { "TIMESTAMP" }
    public func parameterDataValue() -> String {
        self.timeIntervalSince1970.parameterDataValue()
    }

    public init(dataType: String, dataValue: String) throws {
        switch dataType {
        case "TIMESTAMP":
            guard let t = TimeInterval(dataValue) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(dataValue)\" is not double"))
            }
            self = .init(timeIntervalSince1970: t)
        case "DATETIME":
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            formatter.formatOptions.remove(.withTimeZone)
            guard let d = formatter.date(from: dataValue) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(dataValue)\" is invalid format"))
            }
            self = d
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(dataType)\" is unsupported"))
        }
    }
}
