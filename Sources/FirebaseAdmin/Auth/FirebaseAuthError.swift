public struct FirebaseAuthError: CodeAndMessageError {
    public enum Code: String, Sendable {
        case billingNotEnabled
        case claimsTooLarge
        case configurationExists
        case configurationNotFound
        case insufficientPermission
        case invalidConfig
        case invalidConfigID
        case invalidContinueURI
        case invalidDynamicLinkDomain
        case duplicateEmail
        case duplicateLocalID
        case duplicateMfaEnrollmentID
        case emailExists
        case emailNotFound
        case forbiddenClaim
        case invalidClaims
        case invalidDuration
        case invalidEmail
        case invalidNewEmail
        case invalidDisplayName
        case invalidIDToken
        case invalidOAuthClientID
        case invalidPageSelection
        case invalidPhoneNumber
        case invalidProjectID
        case invalidServiceAccount
        case invalidTestingPhoneNumber
        case invalidTenantType
        case missingAndroidPackageName
        case missingConfig
        case missingConfigID
        case missingDisplayName
        case missingEmail
        case missingIOSBundleID
        case missingIssuer
        case missingLocalID
        case missingOAuthClientID
        case missingProviderID
        case missingSamlRelyingPartyConfig
        case missingUserAccount
        case operationNotAllowed
        case permissionDenied
        case phoneNumberExists
        case projectNotFound
        case quotaExceeded
        case secondFactorLimitExceeded
        case tenantNotFound
        case tenantIDMismatch
        case tokenExpired
        case unauthorizedDomain
        case unsupportedFirstFactor
        case unsupportedSecondFactor
        case unsupportedTenantOperation
        case unverifiedEmail
        case userNotFound
        case userDisabled
        case weakPassword
        case invalidRecaptchaAction
        case invalidRecaptchaEnforcementState
        case recaptchaNotEnabled
    }

    public var code: Code
    public var message: String?

    public init(
        code: Code,
        message: String?
    ) {
        self.code = code
        self.message = message
    }

    public init?(from string: String) {
        var codeString = string.trimmingCharacters(in: .whitespaces)
        var messageString: String? = nil
        if let index = codeString.firstIndex(of: ":") {
            codeString = codeString[..<index].trimmingCharacters(in: .whitespaces)
            messageString = codeString[codeString.index(after: index)...].trimmingCharacters(in: .whitespaces)
        }

        guard let code = Code(rawValue: codeString) else { return nil }

        self.init(code: code, message: messageString)
    }

    static let codeStringMap: [Code: String] = [
        .billingNotEnabled: "BILLING_NOT_ENABLED",
        .claimsTooLarge: "CLAIMS_TOO_LARGE",
        .configurationExists: "CONFIGURATION_EXISTS",
        .configurationNotFound: "CONFIGURATION_NOT_FOUND",
        .insufficientPermission: "INSUFFICIENT_PERMISSION",
        .invalidConfig: "INVALID_CONFIG",
        .invalidConfigID: "INVALID_CONFIG_ID",
        .invalidContinueURI: "INVALID_CONTINUE_URI",
        .invalidDynamicLinkDomain: "INVALID_DYNAMIC_LINK_DOMAIN",
        .duplicateEmail: "DUPLICATE_EMAIL",
        .duplicateLocalID: "DUPLICATE_LOCAL_ID",
        .duplicateMfaEnrollmentID: "DUPLICATE_MFA_ENROLLMENT_ID",
        .emailExists: "EMAIL_EXISTS",
        .emailNotFound: "EMAIL_NOT_FOUND",
        .forbiddenClaim: "FORBIDDEN_CLAIM",
        .invalidClaims: "INVALID_CLAIMS",
        .invalidDuration: "INVALID_DURATION",
        .invalidEmail: "INVALID_EMAIL",
        .invalidNewEmail: "INVALID_NEW_EMAIL",
        .invalidDisplayName: "INVALID_DISPLAY_NAME",
        .invalidIDToken: "INVALID_ID_TOKEN",
        .invalidOAuthClientID: "INVALID_OAUTH_CLIENT_ID",
        .invalidPageSelection: "INVALID_PAGE_SELECTION",
        .invalidPhoneNumber: "INVALID_PHONE_NUMBER",
        .invalidProjectID: "INVALID_PROJECT_ID",
        .invalidServiceAccount: "INVALID_SERVICE_ACCOUNT",
        .invalidTestingPhoneNumber: "INVALID_TESTING_PHONE_NUMBER",
        .invalidTenantType: "INVALID_TENANT_TYPE",
        .missingAndroidPackageName: "MISSING_ANDROID_PACKAGE_NAME",
        .missingConfig: "MISSING_CONFIG",
        .missingConfigID: "MISSING_CONFIG_ID",
        .missingDisplayName: "MISSING_DISPLAY_NAME",
        .missingEmail: "MISSING_EMAIL",
        .missingIOSBundleID: "MISSING_IOS_BUNDLE_ID",
        .missingIssuer: "MISSING_ISSUER",
        .missingLocalID: "MISSING_LOCAL_ID",
        .missingOAuthClientID: "MISSING_OAUTH_CLIENT_ID",
        .missingProviderID: "MISSING_PROVIDER_ID",
        .missingSamlRelyingPartyConfig: "MISSING_SAML_RELYING_PARTY_CONFIG",
        .missingUserAccount: "MISSING_USER_ACCOUNT",
        .operationNotAllowed: "OPERATION_NOT_ALLOWED",
        .permissionDenied: "PERMISSION_DENIED",
        .phoneNumberExists: "PHONE_NUMBER_EXISTS",
        .projectNotFound: "PROJECT_NOT_FOUND",
        .quotaExceeded: "QUOTA_EXCEEDED",
        .secondFactorLimitExceeded: "SECOND_FACTOR_LIMIT_EXCEEDED",
        .tenantNotFound: "TENANT_NOT_FOUND",
        .tenantIDMismatch: "TENANT_ID_MISMATCH",
        .tokenExpired: "TOKEN_EXPIRED",
        .unauthorizedDomain: "UNAUTHORIZED_DOMAIN",
        .unsupportedFirstFactor: "UNSUPPORTED_FIRST_FACTOR",
        .unsupportedSecondFactor: "UNSUPPORTED_SECOND_FACTOR",
        .unsupportedTenantOperation: "UNSUPPORTED_TENANT_OPERATION",
        .unverifiedEmail: "UNVERIFIED_EMAIL",
        .userNotFound: "USER_NOT_FOUND",
        .userDisabled: "USER_DISABLED",
        .weakPassword: "WEAK_PASSWORD",
        .invalidRecaptchaAction: "INVALID_RECAPTCHA_ACTION",
        .invalidRecaptchaEnforcementState: "INVALID_RECAPTCHA_ENFORCEMENT_STATE",
        .recaptchaNotEnabled: "RECAPTCHA_NOT_ENABLED"
    ]

    static let stringCodeMap: [String: Code] = Dictionary(
        codeStringMap.map { ($0.value, $0.key) }
    ) { $1 }
}

