import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFoundationCompat

public protocol Credential: Sendable {
    func getAccessToken() async throws -> AccessToken
}

public protocol RichCredential: Credential {
    var clientEmail: String { get }
    var projectID: String { get }
    func sign(data: Data) async throws -> Data
}

struct CredentialError: Error, CustomStringConvertible, LocalizedError {
    var message: String
    var description: String { message }
    var errorDescription: String? { message }
}

private struct CredentialsFile: Decodable {
    var type: String
}

struct CredentialErrorFrame: Decodable, Error, CustomStringConvertible, LocalizedError {
    var error: String
    var error_description: String?
    var description: String {
        if let errorDescription = error_description {
            return "\(error) (\(errorDescription))"
        }
        return error
    }
    var errorDescription: String? { description }
}

struct AccessTokenResponse: Decodable, Sendable {
    var accessToken: AccessToken
    var exipresIn: Double // seconds

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case exipresIn = "expires_in"
    }
}

extension Credential {
    internal static func requestAccessToken(
        httpClient: AsyncHTTPClient.HTTPClient,
        request: HTTPClientRequest
    ) async throws -> AccessTokenResponse {
        let res = try await httpClient.execute(request, timeout: .seconds(10))
        let body = try await res.body.collect(upTo: .max)

        if 400..<600 ~= res.status.code {
            let errorFrame = try JSONDecoder().decode(CredentialErrorFrame.self, from: body)
            throw CredentialError(message: errorFrame.description)
        }

        return try JSONDecoder().decode(AccessTokenResponse.self, from: body)
    }


    internal static func requestString(
        httpClient: AsyncHTTPClient.HTTPClient,
        request: HTTPClientRequest
    ) async throws -> String {
        let res = try await httpClient.execute(request, timeout: .seconds(10))
        let body = try await res.body.collect(upTo: .max)

        if 400..<600 ~= res.status.code {
            let errorFrame = try JSONDecoder().decode(CredentialErrorFrame.self, from: body)
            throw CredentialError(message: errorFrame.description)
        }

        guard let data = body.getData(at: body.readerIndex, length: body.readableBytes),
              let string = String(data: data, encoding: .utf8) else {
            throw CredentialError(message: "body cannot decode as utf8")
        }
        return string
    }
}
