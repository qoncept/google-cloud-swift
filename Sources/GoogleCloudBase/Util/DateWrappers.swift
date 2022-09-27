import Foundation

struct RFC3339ZDateBase: Codable {
    var value: Date
    init(value: Date) {
        self.value = value
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dateString = try c.decode(String.self)
        let formatters: [ISO8601DateFormatter] = [
            {
                let f = ISO8601DateFormatter()
                f.formatOptions.formUnion(.withFractionalSeconds)
                return f
            }(),
            ISO8601DateFormatter()
        ]
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                value = date
                return
            }
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "invalid date format")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        let dateString = ISO8601DateFormatter().string(from: value)
        try c.encode(dateString)
    }
}

@propertyWrapper public struct RFC3339ZDate: Codable {
    public init(wrappedValue: Date) {
        self.innerValue = .init(value: wrappedValue)
    }
    private var innerValue: RFC3339ZDateBase
    public var wrappedValue: Date {
        get { innerValue.value }
        set { innerValue.value = newValue }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        innerValue = try c.decode(RFC3339ZDateBase.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(innerValue)
    }
}

@propertyWrapper public struct RFC3339ZOptionalDate: Codable {
    public init(wrappedValue: Date?) {
        self.innerValue = wrappedValue.map { .init(value: $0) }
    }
    private var innerValue: RFC3339ZDateBase?
    public var wrappedValue: Date? {
        get { innerValue?.value }
        set { innerValue = newValue.map { .init(value: $0) } }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        innerValue = try c.decode(RFC3339ZDateBase.self)
    }

    public func encode(to encoder: Encoder) throws {
        if let innerValue = innerValue {
            var c = encoder.singleValueContainer()
            try c.encode(innerValue)
        }
    }
}

extension KeyedDecodingContainer {
    public func decode(_ type: RFC3339ZOptionalDate.Type, forKey key: Key) throws -> RFC3339ZOptionalDate {
        try decodeIfPresent(type, forKey: key) ?? .init(wrappedValue: nil)
    }
}

@propertyWrapper public struct StringMilliUnixDate: Decodable {
    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }
    public var wrappedValue: Date
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let jsonString = try c.decode(String.self)
        guard let number = TimeInterval(jsonString) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "expected number string")
        }
        wrappedValue = Date(timeIntervalSince1970: number / 1000)
    }
}

@propertyWrapper public struct StringUnixOptionalDate: Decodable {
    public init(wrappedValue: Date? = nil) {
        self.wrappedValue = wrappedValue
    }
    public var wrappedValue: Date?
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let jsonString = try c.decode(String.self)
        guard let number = TimeInterval(jsonString) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "expected number string")
        }
        wrappedValue = Date(timeIntervalSince1970: number)
    }
}

extension KeyedDecodingContainer {
    public func decode(_ type: StringUnixOptionalDate.Type, forKey key: Key) throws -> StringUnixOptionalDate {
        try decodeIfPresent(type, forKey: key) ?? .init(wrappedValue: nil)
    }
}
