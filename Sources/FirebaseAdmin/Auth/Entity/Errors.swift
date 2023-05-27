public enum UpdateUserError: Error {
    case invalidIDToken
    case emailExists
    case weakPassword

    public init?(from code: FirebaseAuthError) {
        switch code {
        case .invalidIDToken: self = .invalidIDToken
        case .emailExists: self = .emailExists
        case .weakPassword: self = .weakPassword
        default: return nil
        }
    }

    public var authError: FirebaseAuthError {
        switch self {
        case .invalidIDToken: return .invalidIDToken
        case .emailExists: return .emailExists
        case .weakPassword: return .weakPassword
        }
    }
}
