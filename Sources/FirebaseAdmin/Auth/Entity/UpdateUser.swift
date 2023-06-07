import Foundation

public struct UpdateUserError: CodeAndMessageError {
    public enum Code: String, Sendable {
//        case invalidUID
//        case invalidDisplayName
        case invalidEmail
        case emailExists
        case invalidPhoneNumber
//        case invalidPhotoURL
        case weakPassword
    }

    public init(
        code: UpdateUserError.Code,
        message: String?
    ) {
        self.code = code
        self.message = message
    }

    public var code: Code
    public var message: String?
}

// interface UpdateRequest
// https://github.com/firebase/firebase-admin-node/blob/master/src/auth/auth-config.ts#L129
public struct UpdateUserProperties {
    public init(
        disabled: Bool? = nil,
        displayName: SetOrDelete<String>? = nil,
        email: String? = nil,
        emailVerified: Bool? = nil,
        password: String? = nil,
        phoneNumber: SetOrDelete<String>? = nil,
        photoURL: SetOrDelete<String>? = nil
    ) {
        self.disabled = disabled
        self.displayName = displayName
        self.email = email
        self.emailVerified = emailVerified
        self.password = password
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
    }

    public var disabled: Bool?
    public var displayName: SetOrDelete<String>?
    public var email: String?
    public var emailVerified: Bool?
    public var password: String?
    public var phoneNumber: SetOrDelete<String>?
    public var photoURL: SetOrDelete<String>?

// TODO: implement
//    public var multiFactor: MultiFactorUpdateSettings?
//    public var providerToLink: UserProvider?
//    public var providersToUnlink: [String]?

    func toRaw(uid: String) throws -> RawUpdateUserRequest {
        let rawEmail = self.email
        var rawDisplayName: String? = nil
        var rawPhotoUrl: String? = nil
        var rawPhoneNumber: String? = nil
        var deleteAttribute: [String] = []
        var deleteProvider: [String] = []

//        if let provider = providerToLink {
//            switch provider.providerId {
//            case "email":
//                if let _ = self.email {
//                    throw UpdateUserError(
//                        "Both UpdateRequest.email and UpdateRequest.providerToLink.providerId='email' were set. " +
//                        "To link to the email/password provider, only specify the UpdateRequest.email field."
//                    )
//                }
//                rawEmail = provider.uid
//                providerToLink = nil
//            case "phone":
//                if let _ = self.phoneNumber {
//                    throw UpdateUserError(
//                        "Both UpdateRequest.phoneNumber and UpdateRequest.providerToLink.providerId='phone' were set. " +
//                        "To link to a phone provider, only specify the UpdateRequest.phoneNumber field."
//                    )
//                }
//                rawPhoneNumber = provider.uid
//                providerToLink = nil
//            default: break
//            }
//        }

        if let displayName {
            switch displayName {
            case .set(let x):
                rawDisplayName = x
            case .delete:
                deleteAttribute.append("DISPLAY_NAME")
            }
        }

        if let photoURL {
            switch photoURL {
            case .set(let x):
                rawPhotoUrl = x
            case .delete:
                deleteAttribute.append("PHOTO_URL")
            }
        }

        if let phoneNumber {
            switch phoneNumber {
            case .set(let x):
                rawPhoneNumber = x
            case .delete:
                deleteProvider.append("phone")
            }
        }

        return RawUpdateUserRequest(
            localId: uid,
            disableUser: disabled,
            displayName: rawDisplayName,
            email: rawEmail,
            emailVerified: emailVerified,
            password: password,
            phoneNumber: rawPhoneNumber,
            photoUrl: rawPhotoUrl,
            deleteAttribute: deleteAttribute.isEmpty ? nil : deleteAttribute,
            deleteProvider: deleteProvider.isEmpty ? nil : deleteProvider
        )
    }
}

struct UpdateUserResponse: Decodable {
    // uid
    var localId: String
}

public struct MultiFactorUpdateSettings {
    public init(
        enrolledFactors: [UpdateMultiFactorInfoRequest]
    ) {
        self.enrolledFactors = enrolledFactors
    }

    public var enrolledFactors: [UpdateMultiFactorInfoRequest]

    func toRaw() -> RawUpdateUserRequest.Mfa {
        let enrollments: [AuthFactorInfo] = enrolledFactors.map { $0.toRaw() }

        return RawUpdateUserRequest.Mfa(
            enrollments: enrollments.isEmpty ? nil : enrollments
        )
    }
}

public struct UpdateMultiFactorInfoRequest: Encodable {
    public init(
        uid: String? = nil,
        displayName: String? = nil,
        enrollmentTime: Date? = nil,
        factorId: String,
        phoneNumber: String? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.enrollmentTime = enrollmentTime
        self.factorId = factorId
        self.phoneNumber = phoneNumber
    }

    public var uid: String?
    public var displayName: String?
    public var enrollmentTime: Date?
    public var factorId: String

    // UpdatePhoneMultiFactorInfoRequest
    public var phoneNumber: String?

    func toRaw() -> AuthFactorInfo {
        return AuthFactorInfo(
            mfaEnrollmentId: uid,
            displayName: displayName,
            phoneInfo: phoneNumber,
            enrolledAt: enrollmentTime
        )
    }
}

public struct UserProvider: Encodable {
    public init(
        uid: String? = nil,
        displayName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        photoURL: String? = nil,
        providerId: String? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
        self.providerId = providerId
    }

    public var uid: String?
    public var displayName: String?
    public var email: String?
    public var phoneNumber: String?
    public var photoURL: String?
    public var providerId: String?

    func toRaw() -> LinkProviderUserInfo {
        LinkProviderUserInfo(
            rawId: uid,
            displayName: displayName,
            email: email,
            phoneNumber: phoneNumber,
            photoURL: photoURL,
            providerId: providerId
        )
    }
}

struct RawUpdateUserRequest: Encodable {
    struct Mfa: Encodable {
        var enrollments: [AuthFactorInfo]?
    }

    var localId: String
    var disableUser: Bool?
    var displayName: String?
    var email: String?
    var emailVerified: Bool?
    var password: String?
    var phoneNumber: String?
    var photoUrl: String?

    // TODO: implement
//    var mfa: Mfa?
//    var linkProviderUserInfo: LinkProviderUserInfo?

    var deleteAttribute: [String]?
    var deleteProvider: [String]?
}

struct AuthFactorInfo: Encodable {
    var mfaEnrollmentId: String?
    var displayName: String?
    var phoneInfo: String?
    @RFC3339ZOptionalDate var enrolledAt: Date?
}

struct LinkProviderUserInfo: Encodable {
    var rawId: String?
    var displayName: String?
    var email: String?
    var phoneNumber: String?
    var photoURL: String?
    var providerId: String?
}
