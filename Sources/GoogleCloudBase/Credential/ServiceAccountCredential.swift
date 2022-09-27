import AsyncHTTPClient
import Crypto
import _CryptoExtras
import Foundation
import JWTKit
import NIOHTTP1

// INFO: https://github.com/googleapis/google-auth-library-nodejs/blob/main/src/auth/jwtclient.ts

private let googleTokenAudience = "https://accounts.google.com/o/oauth2/token"
private let googleAuthTokenHost = "accounts.google.com"
private let googleAuthTokenPath = "/o/oauth2/token"

private struct ServiceAccount: Decodable {
    var projectID: String
    var clientEmail: String
    var privateKey: String

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case clientEmail = "client_email"
        case privateKey = "private_key"
    }
}

struct ServiceAccountCredential: RichCredential, Sendable {
    let projectID: String
    private let privateKey: String
    let clientEmail: String

    private let httpClient: AsyncHTTPClient.HTTPClient
    private let clock: Clock

    init(credentialsFileData: Data, httpClient: AsyncHTTPClient.HTTPClient, clock: Clock = .default) throws {
        let serviceAccount = try JSONDecoder().decode(ServiceAccount.self, from: credentialsFileData)
        projectID = serviceAccount.projectID
        privateKey = serviceAccount.privateKey
        clientEmail = serviceAccount.clientEmail

        self.httpClient = httpClient
        self.clock = clock
    }

    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        let jwt = try makeAuthJWT()
        let postData = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"

        let req = try HTTPClient.Request(
            url: URL(string: "https://\(googleAuthTokenHost)/\(googleAuthTokenPath)")!,
            method: .POST,
            headers: HTTPHeaders([
                ("Content-Type", "application/x-www-form-urlencoded"),
            ]),
            body: .string(postData)
        )

        return try await Self.requestAccessToken(httpClient: httpClient, request: req)
    }

    private func makeAuthJWT() throws -> String {
        let scope = [
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/firebase.database",
            "https://www.googleapis.com/auth/firebase.messaging",
            "https://www.googleapis.com/auth/identitytoolkit",
            "https://www.googleapis.com/auth/userinfo.email",
        ].joined(separator: " ")

        let now = clock.now()
        let jwtPayload = AuthPayload(
            aud: .init(value: googleTokenAudience),
            exp: .init(value: now + 60 * 60),
            iss: .init(value: clientEmail),
            iat: .init(value: now),
            scope: scope
        )

        let signer = try JWTSigner.rs256(key: RSAKey.private(pem: privateKey))
        return try signer.sign(jwtPayload)
    }

    func sign(data: Data) async throws -> Data {
        let key = try _RSA.Signing.PrivateKey(pemRepresentation: privateKey)
        let signature = try key.signature(for: SHA256.hash(data: data), padding: .insecurePKCS1v1_5)
        return signature.rawRepresentation
    }
}

private struct AuthPayload: JWTPayload {
    var aud: AudienceClaim
    var exp: ExpirationClaim
    var iss: IssuerClaim
    var iat: IssuedAtClaim
    var scope: String

    func verify(using signer: JWTSigner) throws {
        fatalError("send only payload")
    }
}
