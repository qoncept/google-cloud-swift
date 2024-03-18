import AsyncHTTPClient
import Foundation
import GoogleCloudBase

let storageEmulatorHostEnvVar = "STORAGE_EMULATOR_HOST"
private let defaultAPIEndpoint = URL(string: "https://storage.googleapis.com/")!

/// for Firebaseではない、生のCloud Storageを表す
/// ただしエミュレータにはFirebaseのものを使用している
public struct Storage: Sendable {
    private let authorizedClient: AuthorizedClient
    public init(client: GCPClient) {
        var credential = client.credential
        let baseURL: URL

        if let emulatorHost = ProcessInfo.processInfo.environment[storageEmulatorHostEnvVar] {
            baseURL = URL(string: "http://\(emulatorHost)/")!
            credential = EmulatorCredential()
        } else {
            baseURL = defaultAPIEndpoint
        }

        authorizedClient = .init(
            baseURL: baseURL,
            credential:  credential,
            httpClient: client.httpClient
        )
    }

    public func bucket(name: String) -> Bucket {
        Bucket(name: name, authorizedClient: authorizedClient)
    }

    public func signedURL(for file: StorageFile, config: SignerGetSignedURLConfig) async throws -> URL {
        try await URLSigner(
            authorizedClient: authorizedClient,
            file: file
        ).sign(config: config)
    }
}
