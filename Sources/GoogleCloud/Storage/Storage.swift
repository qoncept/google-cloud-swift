import AsyncHTTPClient
import Foundation
import GoogleCloudBase

let storageEmulatorHostEnvVar = "STORAGE_EMULATOR_HOST"
private let defaultAPIEndpoint = URL(string: "https://storage.googleapis.com/")!

/// for Firebaseではない、生のCloud Storageを表す
/// ただしエミュレータにはFirebaseのものを使用している
public struct Storage: Sendable {
    private let credentialStore: CredentialStore

    private let authorizedClient: AuthorizedClient
    public init(
        credentialStore: CredentialStore,
        client: AsyncHTTPClient.HTTPClient
    ) {
        var credentialStore = credentialStore
        let baseURL: URL

        if let emulatorHost = ProcessInfo.processInfo.environment[storageEmulatorHostEnvVar] {
            baseURL = URL(string: "http://\(emulatorHost)/")!
            credentialStore = CredentialStore(credential: .makeEmulatorCredential())
        } else {
            baseURL = defaultAPIEndpoint
        }

        self.credentialStore = credentialStore
        authorizedClient = .init(
            baseURL: baseURL,
            credentialStore: credentialStore,
            httpClient: client
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
