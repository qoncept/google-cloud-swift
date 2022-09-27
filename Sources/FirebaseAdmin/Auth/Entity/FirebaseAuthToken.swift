import Foundation
import JWTKit

public struct AuthTimeClaim: JWTUnixEpochClaim, Equatable, Sendable {
    public var value: Date

    public init(value: Date) {
        self.value = value
    }
}

public struct FirebaseAuthToken: JWTPayload, Sendable {
    public var authTime: AuthTimeClaim
    public var issuer: IssuerClaim
    public var audience: AudienceClaim
    public var expires: ExpirationClaim
    public var issuedAt: IssuedAtClaim
    public var subject: SubjectClaim
    public var firebase: FirebaseInfo
    public var name: String?
    public var picture: String?
    public var email: String?
    public var emailVerified: Bool?
    public var claims: [String: String]

    public var isEmailVerified: Bool {
        emailVerified == true
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case authTime = "auth_time"
        case issuer   = "iss"
        case audience = "aud"
        case expires  = "exp"
        case issuedAt = "iat"
        case subject  = "sub"
        case firebase
        case name
        case picture
        case email
        case emailVerified = "email_verified"
    }

    struct CustomCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            if CodingKeys.allCases.contains(where: { $0.rawValue == stringValue }) { return nil }
            self.stringValue = stringValue
        }
        var intValue: Int? { nil }
        init?(intValue: Int) {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authTime = try container.decode(AuthTimeClaim.self, forKey: .authTime)
        issuer = try container.decode(IssuerClaim.self, forKey: .issuer)
        audience = try container.decode(AudienceClaim.self, forKey: .audience)
        expires = try container.decode(ExpirationClaim.self, forKey: .expires)
        issuedAt = try container.decode(IssuedAtClaim.self, forKey: .issuedAt)
        subject = try container.decode(SubjectClaim.self, forKey: .subject)
        firebase = try container.decode(FirebaseInfo.self, forKey: .firebase)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        picture = try container.decodeIfPresent(String.self, forKey: .picture)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)

        let customContainer = try decoder.container(keyedBy: CustomCodingKey.self)
        var customClaims: [String: String] = [:]
        for unusedKey in customContainer.allKeys {
            if let value = try? customContainer.decode(String.self, forKey: unusedKey) {
                customClaims[unusedKey.stringValue] = value
            }
        }
        claims = customClaims
    }

    public struct FirebaseInfo: Codable, Sendable {
        public var signInProvider: String
        public var tenant: String?
        public var identities: [String: [String]]

        enum CodingKeys: String, CodingKey {
            case signInProvider = "sign_in_provider"
            case tenant         = "tenant"
            case identities     = "identities"
        }
    }

    // INFO: https://firebase.google.com/docs/auth/admin/verify-id-tokens?hl=ja#verify_id_tokens_using_a_third-party_jwt_library
    public func verify(using signer: JWTSigner) throws {
        guard let projectID = audience.value.first else {
            throw JWTError.claimVerificationFailure(name: "aud", reason: "Empty audience")
        }

        guard issuer.value == "https://securetoken.google.com/\(projectID)" else {
            throw JWTError.claimVerificationFailure(name: "iss", reason: "Token not provided by Firebase project: \(projectID)")
        }

        guard !subject.value.isEmpty else {
            throw JWTError.claimVerificationFailure(name: "sub", reason: "Empty subject")
        }

        let now = Date()
        try expires.verifyNotExpired(currentDate: now)
        guard issuedAt.value <= now.addingTimeInterval(60) else {
            throw JWTError.claimVerificationFailure(name: "iat", reason: "issued at future")
        }
        guard authTime.value <= now.addingTimeInterval(60) else {
            throw JWTError.claimVerificationFailure(name: "auth_time", reason: "authTime at future")
        }
    }
}
