import Foundation
import NIOHTTP1
import AsyncHTTPClient

private let googleMetadataServiceHost = "metadata.google.internal"
private let googleMetadataServiceTokenPath = "/computeMetadata/v1/instance/service-accounts/default/token"
private let googleMetadataServiceEmailPath = "/computeMetadata/v1/instance/service-accounts/default/email"
private let googleMetadataProjectIDPath = "/computeMetadata/v1/project/project-id"

struct ComputeEngineCredential: RichCredential, Sendable {
    private let httpClient: AsyncHTTPClient.HTTPClient
    let clientEmail: String
    let projectID: String

    init(httpClient: AsyncHTTPClient.HTTPClient) throws {
        self.httpClient = httpClient
        clientEmail = try Self.requestString(httpClient: httpClient, request: Self.buildRequest(path: googleMetadataServiceEmailPath)).wait()
        projectID = try Self.requestString(httpClient: httpClient, request: Self.buildRequest(path: googleMetadataProjectIDPath)).wait()
    }

    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        let req = try Self.buildRequest(path: googleMetadataServiceTokenPath)
        return try await Self.requestAccessToken(httpClient: httpClient, request: req)
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
                "Authorization": "Bearer \(try await getAccessToken().accessToken)", // TODO: CredentialStoreと同じものを使いたい
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

    private static func buildRequest(path: String) throws -> HTTPClient.Request {
        try HTTPClient.Request(
            url: "http://\(googleMetadataServiceHost)\(path)",
            method: .GET,
            headers: [
                "Metadata-Flavor": "Google",
            ]
        )
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
