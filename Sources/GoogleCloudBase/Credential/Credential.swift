import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFoundationCompat

public protocol Credential: Sendable {
    func getAccessToken() async throws -> GoogleOAuthAccessToken
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

/// Credentialにデフォルトのstatic funcを生やせるようにするため
extension Never: Credential {
    public func getAccessToken() async throws -> GoogleOAuthAccessToken { fatalError() }
    public func sign(data: Data) async throws -> Data { fatalError() }
}

extension Credential where Self == Never {
    private static func gcloudCredentialURL() -> URL? {
#if os(Windows)
        // Windows has a dedicated low-rights location for apps at ~/Application Data
        fatalError("not supported")
#endif
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = home.appendingPathComponent(".config", isDirectory: true)

        let gcloudCredential = configDirectory
            .appendingPathComponent("gcloud/application_default_credentials.json")
        if !FileManager.default.fileExists(atPath: gcloudCredential.path) {
            return nil
        }
        return gcloudCredential
    }

    public static func makeApplicationDefault(httpClient: AsyncHTTPClient.HTTPClient) throws -> any Credential {
        if let googleApplicationCredential = ProcessInfo.processInfo.environment["GOOGLE_APPLICATION_CREDENTIALS"] {
            return try makeCredential(fromFile: URL(fileURLWithPath: googleApplicationCredential), httpClient: httpClient)
        }

        if let gcloudCredentialURL = gcloudCredentialURL(),
           let data = try? Data(contentsOf: gcloudCredentialURL) {
            return try RefreshTokenCredential(credentialsFileData: data, httpClient: httpClient)
        }

        return try ComputeEngineCredential(httpClient: httpClient)
    }

    public static func makeCredential(fromFile fileURL: URL, httpClient: AsyncHTTPClient.HTTPClient) throws -> any Credential {
        let data = try Data(contentsOf: fileURL)
        return try makeCredential(data: data, httpClient: httpClient)
    }

    public static func makeCredential(fromBase64EncodedString string: String, httpClient: AsyncHTTPClient.HTTPClient) throws -> any Credential {
        guard let data = Data(base64Encoded: string) else {
            throw CredentialError(message: "Failed to decode base64EncodedString")
        }
        return try makeCredential(data: data, httpClient: httpClient)
    }

    public static func makeCredential(data: Data, httpClient: AsyncHTTPClient.HTTPClient) throws -> any Credential {
        let credentialsFile: CredentialsFile
        do {
            credentialsFile = try JSONDecoder().decode(CredentialsFile.self, from: data)
        } catch {
            throw CredentialError(message: "Failed to parse contents of the credentials file as an object")
        }

        switch credentialsFile.type {
        case "service_account":
            return try ServiceAccountCredential(credentialsFileData: data, httpClient: httpClient)
        case "authorized_user":
            return try RefreshTokenCredential(credentialsFileData: data, httpClient: httpClient)
        default:
            throw CredentialError(message: "Invalid contents in the credentials file")
        }
    }

    public static func makeEmulatorCredential() -> any Credential {
        return EmulatorCredential()
    }
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

extension Credential {
    internal static func requestAccessToken(
        httpClient: AsyncHTTPClient.HTTPClient,
        request: HTTPClient.Request
    ) async throws -> GoogleOAuthAccessToken {
        let res = try await httpClient.execute(request: request).get()
        guard let body = res.body else {
            throw CredentialError(message: "Missing payload")
        }

        if 400..<600 ~= res.status.code {
            let errorFrame = try JSONDecoder().decode(CredentialErrorFrame.self, from: body)
            throw CredentialError(message: errorFrame.description)
        }

        return try JSONDecoder().decode(GoogleOAuthAccessToken.self, from: body)
    }


    internal static func requestString(
        httpClient: AsyncHTTPClient.HTTPClient,
        request: HTTPClient.Request
    ) -> EventLoopFuture<String> {
        return httpClient.execute(request: request)
            .flatMapThrowing { res in
                guard let body = res.body else {
                    throw CredentialError(message: "Missing payload")
                }

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
}
