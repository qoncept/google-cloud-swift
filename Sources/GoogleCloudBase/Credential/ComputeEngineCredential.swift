import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

private let googleMetadataServiceHost = "metadata.google.internal"
private let googleMetadataServiceTokenPath = "/computeMetadata/v1/instance/service-accounts/default/token"
private let googleMetadataServiceEmailPath = "/computeMetadata/v1/instance/service-accounts/default/email"
private let googleMetadataProjectIDPath = "/computeMetadata/v1/project/project-id"

struct ComputeEngineCredential: RichCredential, Sendable {
    var httpClient: AsyncHTTPClient.HTTPClient
    var clientEmail: String
    var projectID: String
    var accessToken: AutoRotatingValue<AccessToken>

    static func makeFromMetadata(httpClient: AsyncHTTPClient.HTTPClient) async throws -> ComputeEngineCredential {
        let clientEmail = try await Self.requestString(httpClient: httpClient, request: Self.buildRequest(path: googleMetadataServiceEmailPath))
        let projectID = try await Self.requestString(httpClient: httpClient, request: Self.buildRequest(path: googleMetadataProjectIDPath))
        return .init(httpClient: httpClient, clientEmail: clientEmail, projectID: projectID)
    }

    init(httpClient: AsyncHTTPClient.HTTPClient, clientEmail: String, projectID: String) {
        self.httpClient = httpClient
        self.clientEmail = clientEmail
        self.projectID = projectID
        self.accessToken = .init {
            let req = try Self.buildRequest(path: googleMetadataServiceTokenPath)
            let token = try await Self.requestAccessToken(httpClient: httpClient, request: req)
            return (token.accessToken, .seconds(token.exipresIn) - .tokenExpiryThreshold)
        }
    }

    func getAccessToken() async throws -> AccessToken {
        return try await accessToken.getValue()
    }

    func sign(data: Data) async throws -> Data {
        // INFO: https://github.com/googleapis/google-auth-library-nodejs/blob/58c53b44113a7211884d49dac1683032a5ce681e/src/auth/googleauth.ts#L910-L926

        struct RequestBody: Encodable {
            var payload: String
        }
        let reqBody = RequestBody(payload: data.base64EncodedString())

        var req = HTTPClientRequest(url: "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/\(clientEmail):signBlob")
        req.method = .POST
        req.headers = [
            "Authorization": "Bearer \(try await accessToken.getValue())",
            "Content-Type": "application/json",
        ]
        req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(reqBody, allocator: ByteBufferAllocator()))

        let res = try await httpClient.execute(req, timeout: .seconds(20))
        let resBody = try await res.body.collect(upTo: .max)

        struct Response: Decodable {
            var keyId:  String
            var signedBlob:  String
        }

        if 400..<600 ~= res.status.code {
            throw try JSONDecoder().decode(IAMAPIErrorFrame.self, from: resBody)
        }

        let decodedBody = try JSONDecoder().decode(Response.self, from: resBody)
        guard let blob = Data(base64Encoded: decodedBody.signedBlob) else {
            throw CredentialError(message: "signedBlob is not base64 encoded")
        }
        return blob
    }

    private static func buildRequest(path: String) throws -> HTTPClientRequest {
        var req = HTTPClientRequest(url: "http://\(googleMetadataServiceHost)\(path)")
        req.method = .GET
        req.headers = [
            "Metadata-Flavor": "Google",
        ]
        return req
    }
}

struct IAMAPIErrorFrame: Decodable, Error, CustomStringConvertible, LocalizedError {
    struct ErrorBody: Decodable {
        var code: Int
        var message: String
        var status: String
    }

    var error: ErrorBody
    var description: String {
        "\(error.message)(\(error.code))"
    }
    var errorDescription: String? { description }
}
