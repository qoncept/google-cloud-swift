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

extension Server {
    public static let authProduction: Server = Server(
        baseURL: URL(string: "https://identitytoolkit.googleapis.com/v1")!,
        isEmulator: false
    )

    public static func authEmulator(host: String) -> Server {
        return Server(
            baseURL: URL(string: "http://\(host)/identitytoolkit.googleapis.com/v1")!,
            isEmulator: true
        )
    }

    public static func auth() -> Server {
        if let host = ProcessInfo.processInfo.environment[Auth.emulatorHostEnvVar] {
            return self.authEmulator(host: host)
        } else {
            return self.authProduction
        }
    }

    public var authEmulatorBaseURL: URL? {
        guard isEmulator else { return nil }
        guard let c = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        guard var host = c.host else { return nil }
        if let port = c.port {
            host += ":" + port.description
        }
        return URL(string: "http://\(host)/emulator/v1")
    }
}

public struct Auth {
    public static let emulatorHostEnvVar = "FIREBASE_AUTH_EMULATOR_HOST"
    
    private var baseClient: BaseClient
    private let keySource: HTTPKeySource

    public init(
        credentialStore: CredentialStore,
        client: AsyncHTTPClient.HTTPClient,
        server: Server = .auth(),
        projectID: String? = nil,
        tenantID: String? = nil
    ) throws {
        let authorizedClient = AuthorizedClient(
            server: server,
            credentialStore: credentialStore,
            httpClient: client
        )

        try self.init(
            authorizedClient: authorizedClient,
            projectID: projectID,
            tenantID: tenantID
        )
    }

    public init(
        authorizedClient: AuthorizedClient,
        projectID paramProjectID: String? = nil,
        tenantID: String? = nil
    ) throws {
        let projectID: String
        if let paramProjectID {
            projectID = paramProjectID
        } else if let c = authorizedClient.credentialStore.compilersafeCredential as? RichCredential {
            projectID = c.projectID
        } else {
            throw AuthError(message: "projectID must be provided if the credential doesn't have it.")
        }

        baseClient = BaseClient(
            authorizedClient: authorizedClient,
            projectID: projectID,
            tenantID: tenantID
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

    public func createUser(user: UserToCreate) async throws -> String {
        try user.validatedRequest()
        let path = "/accounts"
        let res = try await baseClient.post(path: path, payload: user, responseType: UpdateUserResponse.self)
        return res.localId
    }

    public func getUser(uid: String) async throws -> UserRecord? {
        return try await getUser(request: .init(localId: [uid]))
    }

    public func getUser(email: String) async throws -> UserRecord? {
        return try await getUser(request: .init(email: [email]))
    }

    private func getUser(request: GetUserRequest) async throws -> UserRecord? {
        let path = "/accounts:lookup"
        return try await baseClient.post(
            path: path, payload: request, responseType: GetUserResponse.self
        ).users?.first
    }

    public func updateUser(uid: String, properties: UpdateUserProperties) async throws -> String {
        let path = "/accounts:update"

        let res = try await baseClient.post(
            path: path, payload: properties.toRaw(uid: uid), responseType: UpdateUserResponse.self
        )
        return res.localId
    }

    public func setCustomUserClaims(uid: String, claims: [String: String]) async throws {
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

    public func deleteUser(uid: String) async throws {
        struct Request: Encodable {
            var localId: String /// UID
        }
        let payload = Request(localId: uid)

        struct Response: Decodable {}

        let path = "/accounts:delete"
        _ = try await baseClient.post(path: path, payload: payload, responseType: Response.self)
    }
}
