public struct AccessToken: RawRepresentable, Sendable, Hashable, Codable, CustomStringConvertible {
    public typealias RawValue = String
    public var rawValue: RawValue

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }

    public var description: String {
        "\(rawValue)"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        rawValue = try c.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
