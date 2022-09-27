import Foundation
import GoogleCloudBase

// from: https://github.com/firebase/firebase-admin-node/blob/master/src/auth/user-record.ts#L423

public struct UserRecord: Decodable {
    public struct UserInfo: Decodable {
        public var rawId: String
        public var providerID: String
        public var displayName: String?
        public var email: String?
        public var photoURL: String?
        public var phoneNumber: String?

        enum CodingKeys: String, CodingKey {
            case rawId
            case providerID = "providerId"
            case displayName
            case email
            case photoURL = "photoUrl"
            case phoneNumber
        }
    }

    public var uid: String
    public var email: String?
    private var _emailVerified: Bool?
    public var emailVerified: Bool {
        _emailVerified ?? false
    }
    public var displayName: String?

    public var photoURL: String?
    public var phoneNumber: String?

    private var _disabled: Bool?
    public var disabled: Bool {
        _disabled ?? false // If disabled is not provided, the account is enabled by default.
    }

    @StringMilliUnixDate public var createdAt: Date
    @StringMilliUnixDate public var lastLoginAt: Date
    @RFC3339ZOptionalDate public var lastRefreshAt: Date?

    public var providers: [UserInfo]

    @CustomClaims public var customClaims: [String: String]
    @StringUnixOptionalDate public var tokensValidAfterAt: Date?

    enum CodingKeys: String, CodingKey {
        case uid = "localId"
        case email
        case _emailVerified = "emailVerified"
        case displayName

        case photoURL = "photoUrl"
        case phoneNumber

        case _disabled = "disabled"

        case createdAt
        case lastLoginAt
        case lastRefreshAt

        case providers = "providerUserInfo"
        case customClaims = "customAttributes"
        case tokensValidAfterAt = "validSince"
    }
}

@propertyWrapper public struct CustomClaims: Decodable {
    public init(wrappedValue: [String : String]) {
        self.wrappedValue = wrappedValue
    }
    public var wrappedValue: [String: String]
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let jsonString = try c.decode(String.self)
        wrappedValue = try JSONDecoder().decode([String: String].self, from: jsonString.data(using: .utf8) ?? .init())
    }
}

extension KeyedDecodingContainer {
    public func decode(_ type: CustomClaims.Type, forKey key: Key) throws -> CustomClaims {
        try decodeIfPresent(type, forKey: key) ?? CustomClaims(wrappedValue: [:])
    }
}
