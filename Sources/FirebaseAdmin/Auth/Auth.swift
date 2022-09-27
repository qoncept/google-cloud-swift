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
    private var baseClient: BaseClient
    private let keySource: HTTPKeySource
    private let projectID: String
    public init(
        credentialStore: CredentialStore,
        client: AsyncHTTPClient.HTTPClient,
        projectID: String? = nil
    ) throws {
        if let projectID = projectID {
            self.projectID = projectID
        } else if let c = credentialStore.compilersafeCredential as? RichCredential {
            self.projectID = c.projectID
        } else {
            throw AuthError(message: "projectID must be provided if the credential doesn't have it.")
        }
        baseClient = BaseClient(credentialStore: credentialStore, client: client, projectID: self.projectID)
        keySource = HTTPKeySource(client: client)
    }

    public var tenantID: String? {
        didSet {
            baseClient.tenantID = tenantID
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
        struct Response: Decodable {
            var localId: String /// UID
        }
        let path = "/accounts"
        let res = try await baseClient.post(path: path, payload: user, responseType: Response.self)
        return res.localId
    }

    public func getUser(uid: String) async throws -> UserRecord? {
        struct Request: Encodable {
            var localId: [String]
        }
        let payload = Request(localId: [uid])

        struct Response: Decodable {
            var users: [UserRecord]?
        }

        let path = "/accounts:lookup"
        return try await baseClient.post(path: path, payload: payload, responseType: Response.self).users?.first
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
