import AsyncHTTPClient
import Foundation
import NIOHTTP1

private let googleMetadataServiceHost = "metadata.google.internal"
private let googleMetadataServiceTokenPath = "/computeMetadata/v1/instance/service-accounts/default/token"
private let googleMetadataServiceEmailPath = "/computeMetadata/v1/instance/service-accounts/default/email"
private let googleMetadataProjectIDPath = "/computeMetadata/v1/project/project-id"

struct ComputeEngineCredential: RichCredential, Sendable {
    var httpClient: AsyncHTTPClient.HTTPClient
    var clientEmail: String
    var projectID: String
    var accessToken: AutoRotatingValue<GoogleOAuthAccessToken>

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
            return (token, .seconds(token.exipresIn) - .tokenExpiryThreshold)
        }
    }

    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        return try await accessToken.getValue()
    }

    func sign(data: Data) async throws -> Data {
        // INFO: https://github.com/googleapis/google-auth-library-nodejs/blob/58c53b44113a7211884d49dac1683032a5ce681e/src/auth/googleauth.ts#L910-L926

        struct RequestBody: Encodable {
            var payload: String
        }
        let body = RequestBody(payload: data.base64EncodedString())

        let req = try HTTPClient.Request(
            url: "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/\(clientEmail):signBlob",
            method: .POST,
            headers: [
                "Authorization": "Bearer \(try await accessToken.getValue().accessToken)",
                "Content-Type": "application/json",
            ],
            body: .data(try JSONEncoder().encode(body))
        )

        let res = try await httpClient.execute(request: req).get()

        struct Response: Decodable {
            var keyId:  String
            var signedBlob:  String
        }

        guard let body = res.body else {
            throw CredentialError(message: "Missing payload")
        }

        if 400..<600 ~= res.status.code {
            throw try JSONDecoder().decode(IAMAPIErrorFrame.self, from: body)
        }

        let decodedBody = try JSONDecoder().decode(Response.self, from: body)
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
