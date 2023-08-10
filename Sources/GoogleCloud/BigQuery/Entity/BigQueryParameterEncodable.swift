import Foundation

public protocol BigQueryParameterEncodable {
    static var parameterDataType: String { get }
    func parameterDataValue() -> String
}

extension CustomStringConvertible where Self: BigQueryParameterEncodable {
    public func parameterDataValue() -> String {
        description
    }
}

extension Int: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int8: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int16: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int32: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension Int64: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt8: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt16: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt32: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension UInt64: BigQueryParameterEncodable {
    public static var parameterDataType: String { "INT64" }
}
extension Float16: BigQueryParameterEncodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension Float32: BigQueryParameterEncodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension Float64: BigQueryParameterEncodable {
    public static var parameterDataType: String { "FLOAT64" }
}
extension String: BigQueryParameterEncodable {
    public static var parameterDataType: String { "STRING" }
}
extension Bool: BigQueryParameterEncodable {
    public static var parameterDataType: String { "BOOL" }
}
extension Date: BigQueryParameterEncodable {
    public static var parameterDataType: String { "TIMESTAMP" }
    public func parameterDataValue() -> String {
        self.timeIntervalSince1970.description
    }
}
