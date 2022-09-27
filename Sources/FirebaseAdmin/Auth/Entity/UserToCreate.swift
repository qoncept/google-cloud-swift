import Foundation

struct UserToCreateError: Error {
    var message: String
}

public struct UserToCreate: Encodable {
    public init(localId: String? = nil, displayName: String? = nil, email: String? = nil, phoneNumber: String? = nil, photoUrl: String? = nil, password: String? = nil) {
        self.localId = localId
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoUrl = photoUrl
        self.password = password
    }

    public var localId: String?
    public var displayName: String?
    public var email: String?
    public var phoneNumber: String?
    public var photoUrl: String?
    public var password: String?

    func validatedRequest() throws {
        if let localId = localId {
            try Self.validateUID(uid: localId)
        }

        if let displayName = displayName {
            try Self.validateDisplayName(displayName: displayName)
        }

        if let email = email {
            try Self.validateEmail(email: email)
        }

        if let phoneNumber = phoneNumber {
            try Self.validatePhone(phone: phoneNumber)
        }

        if let photoUrl = photoUrl {
            try Self.validatePhotoURL(photoURL: photoUrl)
        }

        if let password = password {
            try Self.validatePassword(password: password)
        }
    }

    // MARK: - static

    static func validateUID(uid: String) throws {
        if uid.isEmpty {
            throw UserToCreateError(message: "uid must be a non-empty string")
        }

        if uid.utf8.count > 128 {
            throw UserToCreateError(message: "uid string must not be longer than 128 characters")
        }
    }

    static func validateDisplayName(displayName: String) throws {
        if displayName.isEmpty {
            throw UserToCreateError(message: "display name must be a non-empty string")
        }
    }

    static func validateEmail(email: String) throws {
        if email.isEmpty {
            throw UserToCreateError(message: "email must be a non-empty string")
        }

        let parts = email.split(separator: "@")
        guard parts.count == 2, parts[1].contains(".") else {
            throw UserToCreateError(message: "malformed email string: \(email)")
        }
    }

    static let e164Regex = try! NSRegularExpression(pattern: #"\+.*[0-9A-Za-z]"#)
    static func validatePhone(phone: String) throws {
        if phone.isEmpty {
            throw UserToCreateError(message: "phone number must be a non-empty string")
        }

        if e164Regex.numberOfMatches(in: phone, options: [], range: NSRange(location: 0, length: phone.count)) == 0 {
            throw UserToCreateError(message: "phone number must be a valid, E.164 compliant identifier")
        }
    }

    static func validatePhotoURL(photoURL: String) throws {
        if photoURL.isEmpty {
            throw UserToCreateError(message: "photoURL must be a non-empty string")
        }
    }

    static func validatePassword(password: String) throws {
        if password.utf8.count < 6 {
            throw UserToCreateError(message: "password must be a string at least 6 characters long")
        }
    }
}
