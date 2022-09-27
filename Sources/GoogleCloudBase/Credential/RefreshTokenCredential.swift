import AsyncHTTPClient
import Foundation
import NIOHTTP1

private let refreshTokenEndpoint = "https://www.googleapis.com/oauth2/v4/token"

struct RefreshToken: Decodable {
    var clientID: String
    var clientSecret: String
    var refreshToken: String
    var type: String

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case refreshToken = "refresh_token"
        case type
    }
}

struct RefreshTokenCredential: Credential, Sendable {
    private let refreshToken: RefreshToken
    private let httpClient: AsyncHTTPClient.HTTPClient

    init(credentialsFileData: Data, httpClient: AsyncHTTPClient.HTTPClient) throws {
        refreshToken = try JSONDecoder().decode(RefreshToken.self, from: credentialsFileData)
        self.httpClient = httpClient
    }
    
    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        let postProperties: [(String, String)] = [
            ("client_id", refreshToken.clientID),
            ("client_secret", refreshToken.clientSecret),
            ("refresh_token", refreshToken.refreshToken),
            ("grant_type", "refresh_token"),
        ]
        let bodyString = postProperties.map { "\($0.0)=\($0.1)" }.joined(separator: "&")

        let req = try HTTPClient.Request(
            url: refreshTokenEndpoint,
            method: .POST,
            headers: HTTPHeaders([
                ("Content-Type", "application/x-www-form-urlencoded"),
            ]),
            body: .string(bodyString)
        )

        return try await Self.requestAccessToken(httpClient: httpClient, request: req)
    }
}
