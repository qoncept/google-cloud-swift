import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import JWTKit

// INFO: https://github.com/firebase/firebase-admin-node/blob/master/src/auth/auth-api-request.ts

struct AuthError: Error, CustomStringConvertible, LocalizedError {
    var message: String
    var description: String { message }
    var errorDescription: String? { message }
}

public struct Auth {
    public static let productionBaseURL: URL = URL(string: "https://identitytoolkit.googleapis.com/v1")!

    public static let emulatorHostEnvVar = "FIREBASE_AUTH_EMULATOR_HOST"

    public static func emulatorBaseURL(host: String) -> URL {
        URL(string: "http://\(host)/identitytoolkit.googleapis.com/v1")!
    }

    public static func emulatorBaseURL() -> URL? {
        guard let host = ProcessInfo.processInfo.environment[Auth.emulatorHostEnvVar] else { return nil }
        return emulatorBaseURL(host: host)
    }

    public static func emulatorAPIBaseURL(url: URL) -> URL? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard var host = c.host else { return nil }
        if let port = c.port {
            host += ":" + port.description
        }
        return URL(string: "http://\(host)/emulator/v1")
    }

    private static func projectID(from credentialStore: CredentialStore) -> String? {
        guard let richCredential = credentialStore.compilersafeCredential as? any RichCredential else {
            return nil
        }
        return richCredential.projectID
    }
    
    private var baseClient: BaseClient
    private let keySource: HTTPKeySource

    public init(
        credentialStore: CredentialStore,
        client: AsyncHTTPClient.HTTPClient,
        baseURL paramBaseURL: URL? = nil,
        projectID paramProjectID: String? = nil
    ) throws {
        var credentialStore = credentialStore
        var baseURL: URL
        let projectID: String? = paramProjectID ??
            Self.projectID(from: credentialStore)

        if let paramBaseURL {
            baseURL = paramBaseURL
        } else {
            if let emulator = Self.emulatorBaseURL() {
                baseURL = emulator
                credentialStore = CredentialStore(
                    credential: .makeEmulatorCredential()
                )
            } else {
                baseURL = Self.productionBaseURL
            }
        }

        let authorizedClient = AuthorizedClient(
            baseURL: baseURL,
            credentialStore: credentialStore,
            httpClient: client
        )

        try self.init(
            authorizedClient: authorizedClient,
            projectID: projectID
        )
    }

    public init(
        authorizedClient: AuthorizedClient,
        projectID paramProjectID: String? = nil
    ) throws {
        let projectID: String
        if let paramProjectID {
            projectID = paramProjectID
        } else if let id = Self.projectID(from: authorizedClient.credentialStore) {
            projectID = id
        } else {
            throw AuthError(message: "projectID must be provided if the credential doesn't have it.")
        }

        baseClient = BaseClient(
            authorizedClient: authorizedClient,
            projectID: projectID,
            tenantID: nil
        )
        keySource = HTTPKeySource(client: authorizedClient.httpClient)
    }

    public var authorizedClient: AuthorizedClient { baseClient.authorizedClient }
    
    public var projectID: String { baseClient.projectID }

    public var tenantID: String? {
        get {
            baseClient.tenantID
        }
        set {
            baseClient.tenantID = newValue
        }
    }

    public func isExpired(_ idToken: String) throws -> Bool {
        let unverifiedToken = try JWTSigners().unverified(idToken, as: FirebaseAuthToken.self)
        do {
            try unverifiedToken.expires.verifyNotExpired()
            return false
        } catch {
            return true
        }
    }

    public func verifyIdToken(_ idToken: String) async throws -> FirebaseAuthToken {
        let token = try await keySource.withPublicKeys { signers in
            try signers.verify(idToken, as: FirebaseAuthToken.self)
        }
        try token.audience.verifyIntendedAudience(includes: projectID)
        return token
    }

    public func createUser(_ user: UserToCreate) async throws -> Result<String, FirebaseAuthError> {
        try user.validatedRequest()
        let path = "/accounts"
        let res = try await baseClient.post(path: path, payload: user, responseType: UpdateUserResponse.self)
        return res.map { $0.localId }
    }

    public func user(for uid: String) async throws -> Result<UserRecord?, FirebaseAuthError> {
        return try await user(request: .init(localId: [uid]))
    }

    public func user(byEmail email: String) async throws -> Result<UserRecord?, FirebaseAuthError> {
        return try await user(request: .init(email: [email]))
    }

    private func user(request: GetUserRequest) async throws -> Result<UserRecord?, FirebaseAuthError> {
        let path = "/accounts:lookup"
        let users = try await baseClient.post(
            path: path, payload: request, responseType: GetUserResponse.self
        )
        return users.map { $0.users?.first }
    }

    public func updateUser(_ properties: UpdateUserProperties, for uid: String) async throws -> Result<Void, UpdateUserError> {
        let path = "/accounts:update"

        let ret = try await baseClient.post(
            path: path, payload: properties.toRaw(uid: uid), responseType: UpdateUserResponse.self
        )

        return try ret.map { (_) in () }.tryMapError { try $0.toUpdateUserError() }
    }

    public func setCustomUserClaims(_ claims: [String: String], for uid: String) async throws {
        struct Request: Encodable {
            var localId: String
            var customAttributes: String
        }
        let customAttributes = String(data: try JSONEncoder().encode(claims), encoding: .utf8) ?? ""
        let payload = Request(localId: uid, customAttributes: customAttributes)

        struct Response: Decodable {
            var localId: String /// UID
        }

        let path = "/accounts:update"
        _ = try await baseClient.post(path: path, payload: payload, responseType: Response.self)
    }

    public func deleteUser(for uid: String) async throws {
        struct Request: Encodable {
            var localId: String /// UID
        }
        let payload = Request(localId: uid)

        struct Response: Decodable {}

        let path = "/accounts:delete"
        _ = try await baseClient.post(path: path, payload: payload, responseType: Response.self)
    }
}
