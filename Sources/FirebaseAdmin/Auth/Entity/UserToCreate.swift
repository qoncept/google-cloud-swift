import Foundation

public struct CreateUserError: CodeAndMessageError {
    public enum Code: String {
        case invalidUID
        case invalidDisplayName
        case invalidEmail
        case invalidPhoneNumber
        case invalidPhotoURL
        case weakPassword
    }

    public init(code: CreateUserError.Code, message: String?) {
        self.code = code
        self.message = message
    }

    public var code: Code
    public var message: String?

    public func toAuth() -> FirebaseAuthError { convert()! }
}

extension FirebaseAuthError {
    public func toCreateUser() throws -> CreateUserError { try convertOrThrow() }
}

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

    func validatedRequest() throws -> Result<Void, CreateUserError> {
        if let localId = localId {
            switch Self.validateUID(uid: localId) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        if let displayName = displayName {
            switch Self.validateDisplayName(displayName: displayName) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        if let email = email {
            switch Self.validateEmail(email: email) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        if let phoneNumber = phoneNumber {
            switch Self.validatePhone(phone: phoneNumber) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        if let photoUrl = photoUrl {
            switch Self.validatePhotoURL(photoURL: photoUrl) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        if let password = password {
            switch Self.validatePassword(password: password) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }

        return .success(())
    }

    // MARK: - static

    static func validateUID(uid: String) -> Result<Void, CreateUserError> {
        if uid.isEmpty {
            return .failure(
                .init(code: .invalidUID, message: "uid must be a non-empty string")
            )
        }

        if uid.utf8.count > 128 {
            return .failure(
                .init(code: .invalidUID, message: "uid string must not be longer than 128 characters")
            )
        }

        return .success(())
    }

    static func validateDisplayName(displayName: String) -> Result<Void, CreateUserError> {
        if displayName.isEmpty {
            return .failure(
                .init(code: .invalidDisplayName, message: "display name must be a non-empty string")
            )
        }

        return .success(())
    }

    static func validateEmail(email: String) -> Result<Void, CreateUserError> {
        if email.isEmpty {
            return .failure(
                .init(code: .invalidEmail, message: "email must be a non-empty string")
            )
        }

        let parts = email.split(separator: "@")
        guard parts.count == 2, parts[1].contains(".") else {
            return .failure(
                .init(code: .invalidEmail, message: "malformed email string: \(email)")
            )
        }

        return .success(())
    }

    static let e164Regex = try! NSRegularExpression(pattern: #"\+.*[0-9A-Za-z]"#)
    static func validatePhone(phone: String) -> Result<Void, CreateUserError> {
        if phone.isEmpty {
            return .failure(
                .init(code: .invalidPhoneNumber, message: "phone number must be a non-empty string")
            )
        }

        if e164Regex.numberOfMatches(in: phone, options: [], range: NSRange(location: 0, length: phone.count)) == 0 {
            return .failure(
                .init(code: .invalidPhoneNumber, message: "phone number must be a valid, E.164 compliant identifier")
            )
        }

        return .success(())
    }

    static func validatePhotoURL(photoURL: String) -> Result<Void, CreateUserError> {
        if photoURL.isEmpty {
            return .failure(
                .init(code: .invalidPhotoURL, message: "photoURL must be a non-empty string")
            )
        }

        return .success(())
    }

    static func validatePassword(password: String) -> Result<Void, CreateUserError> {
        if password.utf8.count < 6 {
            return .failure(
                .init(code: .weakPassword, message: "password must be a string at least 6 characters long")
            )
        }

        return .success(())
    }
}
