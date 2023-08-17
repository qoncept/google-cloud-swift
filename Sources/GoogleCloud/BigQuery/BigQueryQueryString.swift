public struct BigQueryQueryString {
    @usableFromInline enum Fragment {
        case raw(String)
        case parameter(any BigQueryEncodable)
    }

    @usableFromInline
    var fragments: [Fragment]

    @inlinable
    public init<S: StringProtocol>(_ string: S) {
        self.fragments = [.raw(string.description)]
    }
}

extension BigQueryQueryString: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension BigQueryQueryString: ExpressibleByStringInterpolation {
    @inlinable
    public init(stringInterpolation: BigQueryQueryString) {
        self.fragments = stringInterpolation.fragments
    }
}

extension BigQueryQueryString: StringInterpolationProtocol {
    @inlinable
    public init(literalCapacity: Int, interpolationCount: Int) {
        self.fragments = []
    }
    
    @inlinable
    public mutating func appendLiteral(_ literal: String) {
        self.fragments.append(.raw(literal))
    }

    @inlinable
    public mutating func appendInterpolation(raw value: String) {
        self.fragments.append(.raw(value))
    }

    @inlinable
    public mutating func appendInterpolation(bind value: any BigQueryEncodable) {
        self.fragments.append(.parameter(value))
    }

    @inlinable
    public mutating func appendInterpolation(_ other: BigQueryQueryString) {
        self.fragments.append(contentsOf: other.fragments)
    }
}

extension BigQueryQueryString {
    @inlinable
    public static func +(lhs: BigQueryQueryString, rhs: BigQueryQueryString) -> BigQueryQueryString {
        return "\(lhs)\(rhs)"
    }

    @inlinable
    public static func +=(lhs: inout BigQueryQueryString, rhs: BigQueryQueryString) {
        lhs.fragments.append(contentsOf: rhs.fragments)
    }
}

extension Array where Element == BigQueryQueryString {
    @inlinable
    public func joined(separator: String) -> BigQueryQueryString {
        let separator = "\(raw: separator)" as BigQueryQueryString
        return self.first.map { self.dropFirst().lazy.reduce($0) { $0 + separator + $1 } } ?? ""
    }
}
