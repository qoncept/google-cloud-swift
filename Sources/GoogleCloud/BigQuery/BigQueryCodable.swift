import Foundation
import NIOPosix

public protocol BigQueryEncodable: Sendable {
    static var parameterDataType: BigQueryDataType { get }
    func parameterDataValue() -> String
}

public protocol BigQueryDecodable {
    init(dataType: BigQueryDataType, dataValue: String) throws
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
    public init(dataType: BigQueryDataType, dataValue: String) throws {
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
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension Int8: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension Int16: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension Int32: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension Int64: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension UInt: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension UInt8: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension UInt16: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension UInt32: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension UInt64: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .int64 }
}
extension Float32: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .float64 }
}
extension Float64: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .float64 }
}
extension String: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .string }
}
extension Bool: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .bool }
}
extension Date: BigQueryCodable {
    public static var parameterDataType: BigQueryDataType { .timestamp }
    public func parameterDataValue() -> String {
        self.timeIntervalSince1970.parameterDataValue()
    }

    public init(dataType: BigQueryDataType, dataValue: String) throws {
        switch dataType {
        case .timestamp:
            guard let t = TimeInterval(dataValue) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(dataValue)\" is not double"))
            }
            self = .init(timeIntervalSince1970: t)
        case .datetime:
            var format = Date.ISO8601FormatStyle.iso8601
                .year()
                .month()
                .day()
                .time(includingFractionalSeconds: false)
            if let d = try? Date(dataValue, strategy: format) {
                self = d
            } else {
                format = format.time(includingFractionalSeconds: true)
                self = try Date(dataValue, strategy: format)
            }
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(dataType)\" is unsupported"))
        }
    }
}
extension BigQueryEncodable where Self: RawRepresentable, RawValue: BigQueryEncodable {
    public static var parameterDataType: BigQueryDataType {
        RawValue.parameterDataType
    }
    public func parameterDataValue() -> String {
        rawValue.parameterDataValue()
    }
}

extension BigQueryDecodable where Self: RawRepresentable, RawValue: BigQueryDecodable {
    public init(dataType: BigQueryDataType, dataValue: String) throws {
        let raw = try RawValue(dataType: dataType, dataValue: dataValue)
        guard let result = Self.init(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\"\(raw)\" cannot convert to \(Self.self)"))
        }
        self = result
    }
}
