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
    var accessToken: AutoRotatingValue<GoogleOAuthAccessToken>

    init(credentialsFileData: Data, httpClient: AsyncHTTPClient.HTTPClient) throws {
        let refreshToken = try JSONDecoder().decode(RefreshToken.self, from: credentialsFileData)
        self.accessToken = .init {
            let postProperties: [(String, String)] = [
                ("client_id", refreshToken.clientID),
                ("client_secret", refreshToken.clientSecret),
                ("refresh_token", refreshToken.refreshToken),
                ("grant_type", "refresh_token"),
            ]
            let bodyString = postProperties.map { "\($0.0)=\($0.1)" }.joined(separator: "&")

            var req = HTTPClientRequest(url: refreshTokenEndpoint)
            req.method = .POST
            req.headers = [
                "Content-Type": "application/x-www-form-urlencoded",
            ]
            req.body = .bytes(.init(string: bodyString))

            let token = try await Self.requestAccessToken(httpClient: httpClient, request: req)
            return (token, .seconds(token.exipresIn) - .tokenExpiryThreshold)
        }
    }
    
    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        return try await accessToken.getValue()
    }
}
