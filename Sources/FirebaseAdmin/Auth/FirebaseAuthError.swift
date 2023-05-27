public struct FirebaseAuthError: Error & CustomStringConvertible {
    public enum Code: String, Sendable {
        case billingNotEnabled = "BILLING_NOT_ENABLED"
        case claimsTooLarge = "CLAIMS_TOO_LARGE"
        case configurationExists = "CONFIGURATION_EXISTS"
        case configurationNotFound = "CONFIGURATION_NOT_FOUND"
        case insufficientPermission = "INSUFFICIENT_PERMISSION"
        case invalidConfig = "INVALID_CONFIG"
        case invalidConfigID = "INVALID_CONFIG_ID"
        case invalidContinueURI = "INVALID_CONTINUE_URI"
        case invalidDynamicLinkDomain = "INVALID_DYNAMIC_LINK_DOMAIN"
        case duplicateEmail = "DUPLICATE_EMAIL"
        case duplicateLocalID = "DUPLICATE_LOCAL_ID"
        case duplicateMfaEnrollmentID = "DUPLICATE_MFA_ENROLLMENT_ID"
        case emailExists = "EMAIL_EXISTS"
        case emailNotFound = "EMAIL_NOT_FOUND"
        case forbiddenClaim = "FORBIDDEN_CLAIM"
        case invalidClaims = "INVALID_CLAIMS"
        case invalidDuration = "INVALID_DURATION"
        case invalidEmail = "INVALID_EMAIL"
        case invalidNewEmail = "INVALID_NEW_EMAIL"
        case invalidDisplayName = "INVALID_DISPLAY_NAME"
        case invalidIDToken = "INVALID_ID_TOKEN"
        case invalidOAuthClientID = "INVALID_OAUTH_CLIENT_ID"
        case invalidPageSelection = "INVALID_PAGE_SELECTION"
        case invalidPhoneNumber = "INVALID_PHONE_NUMBER"
        case invalidProjectID = "INVALID_PROJECT_ID"
        case invalidServiceAccount = "INVALID_SERVICE_ACCOUNT"
        case invalidTestingPhoneNumber = "INVALID_TESTING_PHONE_NUMBER"
        case invalidTenantType = "INVALID_TENANT_TYPE"
        case missingAndroidPackageName = "MISSING_ANDROID_PACKAGE_NAME"
        case missingConfig = "MISSING_CONFIG"
        case missingConfigID = "MISSING_CONFIG_ID"
        case missingDisplayName = "MISSING_DISPLAY_NAME"
        case missingEmail = "MISSING_EMAIL"
        case missingIOSBundleID = "MISSING_IOS_BUNDLE_ID"
        case missingIssuer = "MISSING_ISSUER"
        case missingLocalID = "MISSING_LOCAL_ID"
        case missingOAuthClientID = "MISSING_OAUTH_CLIENT_ID"
        case missingProviderID = "MISSING_PROVIDER_ID"
        case missingSamlRelyingPartyConfig = "MISSING_SAML_RELYING_PARTY_CONFIG"
        case missingUserAccount = "MISSING_USER_ACCOUNT"
        case operationNotAllowed = "OPERATION_NOT_ALLOWED"
        case permissionDenied = "PERMISSION_DENIED"
        case phoneNumberExists = "PHONE_NUMBER_EXISTS"
        case projectNotFound = "PROJECT_NOT_FOUND"
        case quotaExceeded = "QUOTA_EXCEEDED"
        case secondFactorLimitExceeded = "SECOND_FACTOR_LIMIT_EXCEEDED"
        case tenantNotFound = "TENANT_NOT_FOUND"
        case tenantIDMismatch = "TENANT_ID_MISMATCH"
        case tokenExpired = "TOKEN_EXPIRED"
        case unauthorizedDomain = "UNAUTHORIZED_DOMAIN"
        case unsupportedFirstFactor = "UNSUPPORTED_FIRST_FACTOR"
        case unsupportedSecondFactor = "UNSUPPORTED_SECOND_FACTOR"
        case unsupportedTenantOperation = "UNSUPPORTED_TENANT_OPERATION"
        case unverifiedEmail = "UNVERIFIED_EMAIL"
        case userNotFound = "USER_NOT_FOUND"
        case userDisabled = "USER_DISABLED"
        case weakPassword = "WEAK_PASSWORD"
        case invalidRecaptchaAction = "INVALID_RECAPTCHA_ACTION"
        case invalidRecaptchaEnforcementState = "INVALID_RECAPTCHA_ENFORCEMENT_STATE"
        case recaptchaNotEnabled = "RECAPTCHA_NOT_ENABLED"
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

    public var description: String {
        var str = code.rawValue
        if let message {
            str += ": " + message
        }
        return str
    }
}

extension Result {
    func tryMapError<NewError: Error>(_ convert: (Failure) throws -> NewError) throws -> Result<Success, NewError> {
        switch self {
        case .success(let x): return .success(x)
        case .failure(let e): return .failure(try convert(e))
        }
    }
}
