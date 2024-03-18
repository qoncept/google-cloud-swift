import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import JWTKit
import Logging

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

    private static func projectID(from credential: any Credential) -> String? {
        guard let richCredential = credential as? any RichCredential else {
            return nil
        }
        return richCredential.projectID
    }
    
    private var baseClient: BaseClient
    private let keySource: HTTPKeySource

    public init(
        client: GCPClient,
        baseURL paramBaseURL: URL? = nil,
        projectID paramProjectID: String? = nil
    ) throws {
        var credential = client.credential
        var baseURL: URL
        guard let projectID = paramProjectID ?? Self.projectID(from: credential) else {
            throw AuthError(message: "projectID must be provided if the credential doesn't have it.")
        }

        if let paramBaseURL {
            baseURL = paramBaseURL
        } else {
            if let emulator = Self.emulatorBaseURL() {
                baseURL = emulator
                credential = EmulatorCredential()
            } else {
                baseURL = Self.productionBaseURL
            }
        }

        let authorizedClient = AuthorizedClient(
            baseURL: baseURL,
            gcpClient: client,
            credential: credential
        )

        baseClient = BaseClient(
            authorizedClient: authorizedClient,
            projectID: projectID,
            tenantID: nil
        )
        keySource = HTTPKeySource(client: client.httpClient)
    }
    
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
        let unverifiedToken = try DefaultJWTParser().parse([UInt8](idToken.utf8), as: FirebaseAuthToken.self).payload
        do {
            try unverifiedToken.expires.verifyNotExpired()
            return false
        } catch {
            return true
        }
    }

    public func verifyIdToken(_ idToken: String) async throws -> FirebaseAuthToken {
        let token = try await keySource.publicKeys().verify(idToken, as: FirebaseAuthToken.self)
        try token.audience.verifyIntendedAudience(includes: projectID)
        return token
    }

    public func createUser(
        _ user: UserToCreate,
        logger: Logger? = nil
    ) async throws -> Result<String, CreateUserError> {
        switch user.validatedRequest() {
        case .failure(let e): return .failure(e)
        case .success: break
        }
        let path = "/accounts"
        let res = try await baseClient.post(path: path, payload: user, logger: logger, responseType: UpdateUserResponse.self)
        return try res.map { $0.localId }.tryMapError { try CreateUserError($0) }
    }

    public func user(
        for uid: String,
        logger: Logger? = nil
    ) async throws -> UserRecord? {
        return try await user(request: .init(localId: [uid]), logger: logger)
    }

    public func user(
        byEmail email: String,
        logger: Logger? = nil
    ) async throws -> UserRecord? {
        return try await user(request: .init(email: [email]), logger: logger)
    }

    private func user(
        request: GetUserRequest,
        logger: Logger?
    ) async throws -> UserRecord? {
        let path = "/accounts:lookup"
        let res = try await baseClient.post(
            path: path, payload: request, logger: logger, responseType: GetUserResponse.self
        ).get()
        return res.users?.first
    }

    public func users(
        for queries: [UserIdentityQuery],
        logger: Logger? = nil
    ) async throws -> [UserRecord] {
        if queries.isEmpty { return [] }
        
        let path = "/accounts:lookup"
        var request = GetUsersRequest()
        for query in queries {
            request.append(query: query)
        }
        return try await baseClient.post(
            path: path, payload: request, logger: logger, responseType: GetUsersResponse.self
        ).get().users ?? []
    }

    public func updateUser(
        _ properties: UpdateUserProperties,
        for uid: String,
        logger: Logger? = nil
    ) async throws -> Result<Void, UpdateUserError> {
        switch properties.validate() {
        case .failure(let error): return .failure(error)
        case .success: break
        }

        let path = "/accounts:update"

        let ret = try await baseClient.post(
            path: path, payload: properties.toRaw(uid: uid), logger: logger, responseType: UpdateUserResponse.self
        )

        return try ret.map { (_) in () }.tryMapError { try UpdateUserError($0) }
    }

    public func setCustomUserClaims(
        _ claims: [String: String],
        for uid: String,
        logger: Logger? = nil
    ) async throws {
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
        _ = try await baseClient.post(path: path, payload: payload, logger: logger, responseType: Response.self)
    }

    public func deleteUser(
        for uid: String,
        logger: Logger? = nil
    ) async throws {
        struct Request: Encodable {
            var localId: String /// UID
        }
        let payload = Request(localId: uid)

        struct Response: Decodable {}

        let path = "/accounts:delete"
        _ = try await baseClient.post(path: path, payload: payload, logger: logger, responseType: Response.self)
    }

    public func listUsers(
        pageSize: Int?,
        pageToken: String?,
        logger: Logger? = nil
    ) async throws -> Result<ListUserResult, FirebaseAuthError> {
        var queryItems: [URLQueryItem] = [
            .init(name: "maxResults", value: (pageSize ?? 1000).description)
        ]
        if let pageToken {
            queryItems.append(.init(name: "nextPageToken", value: pageToken))
        }
        return try await baseClient.get(
            path: "/accounts:batchGet",
            queryItems: queryItems,
            logger: logger,
            responseType: ListUserResult.self
        )
    }
}
