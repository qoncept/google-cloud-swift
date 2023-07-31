import Foundation

public struct CreateUserError: FirebaseAuthAPIError {
    public enum Code: String {
        case invalidUID
        case invalidDisplayName
        case invalidEmail
        case emailExists
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

    init(_ error: UserValidationError) {
        switch error.code {
        case .invalidDisplayName: self = .init(code: .invalidDisplayName, message: error.message)
        case .invalidEmail: self = .init(code: .invalidEmail, message: error.message)
        case .invalidPhoneNumber: self = .init(code: .invalidPhoneNumber, message: error.message)
        case .invalidPhotoURL: self = .init(code: .invalidPhotoURL, message: error.message)
        case .weakPassword: self = .init(code: .weakPassword, message: error.message)
        }
    }
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

    func validatedRequest() -> Result<Void, CreateUserError> {
        if let localId = localId {
            switch UserValidations.validateUID(localId) {
            case .failure(let error): return .failure(error)
            case .success: break
            }
        }

        if let displayName = displayName {
            switch UserValidations.validateDisplayName(displayName) {
            case .failure(let error): return .failure(.init(error))
            case .success: break
            }
        }

        if let email = email {
            switch UserValidations.validateEmail(email) {
            case .failure(let error): return .failure(.init(error))
            case .success: break
            }
        }

        if let phoneNumber = phoneNumber {
            switch UserValidations.validatePhone(phoneNumber) {
            case .failure(let error): return .failure(.init(error))
            case .success: break
            }
        }

        if let photoUrl = photoUrl {
            switch UserValidations.validatePhotoURL(photoURL: photoUrl) {
            case .failure(let error): return .failure(.init(error))
            case .success: break
            }
        }

        if let password = password {
            switch UserValidations.validatePassword(password: password) {
            case .failure(let error): return .failure(.init(error))
            case .success: break
            }
        }

        return .success(())
    }
}
