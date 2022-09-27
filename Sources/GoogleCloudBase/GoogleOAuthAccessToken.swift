import Foundation

public struct GoogleOAuthAccessToken: Decodable, Sendable {
    public var accessToken: String
    public var exipresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case exipresIn = "expires_in"
    }
}
