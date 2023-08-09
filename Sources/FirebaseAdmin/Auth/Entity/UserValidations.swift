import Foundation

// common with create and update
struct UserValidationError: CodeAndMessageError {
    enum Code: String {
        case invalidDisplayName
        case invalidEmail
        case invalidPhoneNumber
        case invalidPhotoURL
        case weakPassword
    }

    var code: Code
    var message: String?
}

enum UserValidations {
    static func validateUID(_ uid: String) -> Result<Void, CreateUserError> {
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

    static func validateDisplayName(_ displayName: String) -> Result<Void, UserValidationError> {
        if displayName.isEmpty {
            return .failure(
                .init(code: .invalidDisplayName, message: "display name must be a non-empty string")
            )
        }

        return .success(())
    }

    static func validateEmail(_ email: String) -> Result<Void, UserValidationError> {
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

    static func validatePhone(_ phone: String) -> Result<Void, UserValidationError> {
        if phone.isEmpty {
            return .failure(
                .init(code: .invalidPhoneNumber, message: "phone number must be a non-empty string")
            )
        }

        if phone.matches(of: /\+.*[0-9A-Za-z]/).isEmpty {
            return .failure(
                .init(code: .invalidPhoneNumber, message: "phone number must be a valid, E.164 compliant identifier")
            )
        }

        return .success(())
    }

    static func validatePhotoURL(photoURL: String) -> Result<Void, UserValidationError> {
        if photoURL.isEmpty {
            return .failure(
                .init(code: .invalidPhotoURL, message: "photoURL must be a non-empty string")
            )
        }
        
        return .success(())
    }

    static func validatePassword(password: String) -> Result<Void, UserValidationError> {
        if password.utf8.count < 6 {
            return .failure(
                .init(code: .weakPassword, message: "password must be a string at least 6 characters long")
            )
        }

        return .success(())
    }
}
