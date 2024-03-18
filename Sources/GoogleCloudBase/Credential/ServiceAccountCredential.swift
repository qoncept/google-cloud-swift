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
    var projectID: String
    let clientEmail: String
    private let privateKey: _RSA.Signing.PrivateKey
    let accessToken: AutoRotatingValue<GoogleOAuthAccessToken>

    init(credentialsFileData: Data, httpClient: AsyncHTTPClient.HTTPClient) throws {
        let serviceAccount = try JSONDecoder().decode(ServiceAccount.self, from: credentialsFileData)
        projectID = serviceAccount.projectID
        clientEmail = serviceAccount.clientEmail
        privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: serviceAccount.privateKey)
        let key = try Insecure.RSA.PrivateKey(backing: privateKey)
        let signerTask = Task {
            await JWTKeyCollection().addRS256(key: key)
        }

        self.accessToken = .init {
            let signer = await signerTask.value
            let jwt = try await Self.makeAuthJWT(clientEmail: serviceAccount.clientEmail, signer: signer)
            let postData = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"

            var req = HTTPClientRequest(url: "https://\(googleAuthTokenHost)/\(googleAuthTokenPath)")
            req.method = .POST
            req.headers = [
                "Content-Type": "application/x-www-form-urlencoded",
            ]
            req.body = .bytes(.init(string: postData))

            let token = try await Self.requestAccessToken(httpClient: httpClient, request: req)
            return (token, .seconds(token.exipresIn) - .tokenExpiryThreshold)
        }
    }

    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        return try await accessToken.getValue()
    }

    private static func makeAuthJWT(clientEmail: String, signer: JWTKeyCollection) async throws -> String {
        let scope = [
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/firebase.database",
            "https://www.googleapis.com/auth/firebase.messaging",
            "https://www.googleapis.com/auth/identitytoolkit",
            "https://www.googleapis.com/auth/userinfo.email",
        ].joined(separator: " ")

        let now = Date()
        let jwtPayload = AuthPayload(
            aud: .init(value: googleTokenAudience),
            exp: .init(value: now + 60 * 60),
            iss: .init(value: clientEmail),
            iat: .init(value: now),
            scope: scope
        )

        return try await signer.sign(jwtPayload)
    }

    func sign(data: Data) async throws -> Data {
        let signature = try privateKey.signature(for: SHA256.hash(data: data), padding: .insecurePKCS1v1_5)
        return signature.rawRepresentation
    }
}

private struct AuthPayload: JWTPayload {
    var aud: AudienceClaim
    var exp: ExpirationClaim
    var iss: IssuerClaim
    var iat: IssuedAtClaim
    var scope: String

    func verify(using algorithm: any JWTAlgorithm) throws {
        fatalError("send only payload")
    }
}
