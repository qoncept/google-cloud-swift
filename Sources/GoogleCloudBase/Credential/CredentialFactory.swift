import AsyncHTTPClient
import Foundation
import Logging

public protocol AsyncCredentialFactoryProtocol: Sendable {
    func makeCredential(context: CredentialFactoryContext) async throws -> any Credential
}

public struct AsyncCredentialFactory: AsyncCredentialFactoryProtocol {
    public typealias Context = CredentialFactoryContext

    private var cb: @Sendable (Context) async throws -> any Credential
    init(cb: @Sendable @escaping (Context) async throws -> any Credential) {
        self.cb = cb
    }
    init(next: @escaping (Context) async throws -> AsyncCredentialFactory) {
        self.cb = { context in
            let factory = try await next(context)
            return try await factory.makeCredential(context: context)
        }
    }

    public func makeCredential(context: Context) async throws -> any Credential {
        try await cb(context)
    }
}

public struct SyncCredentialFactory: AsyncCredentialFactoryProtocol {
    public typealias Context = CredentialFactoryContext

    private var cb: @Sendable (Context) throws -> any Credential
    init(cb: @Sendable @escaping (Context) throws -> any Credential) {
        self.cb = cb
    }
    init(next: @escaping (Context) throws -> SyncCredentialFactory) {
        self.cb = { context in
            let factory = try next(context)
            return try factory.makeCredential(context: context)
        }
    }

    public func makeCredential(context: Context) throws -> any Credential {
        try cb(context)
    }
}

public struct CredentialFactoryContext {
    public init(httpClient: HTTPClient, logger: Logger) {
        self.httpClient = httpClient
        self.logger = logger
    }
    public var httpClient: HTTPClient
    public var logger: Logger
}

extension SyncCredentialFactory {
    public static func custom(_ factory: @Sendable @escaping (Context) throws -> any Credential) -> SyncCredentialFactory {
        SyncCredentialFactory(cb: factory)
    }

    public static func `static`(base64EncodedString string: String) -> SyncCredentialFactory {
        return SyncCredentialFactory { context in
            guard let data = Data(base64Encoded: string) else {
                throw CredentialError(message: "Failed to decode base64EncodedString")
            }
            return json(data: data)
        }
    }

    public static func json(fileURL: URL) -> SyncCredentialFactory {
        return SyncCredentialFactory { context in
            let data = try Data(contentsOf: fileURL)
            return json(data: data)
        }
    }

    public static func json(data: Data) -> SyncCredentialFactory {
        return SyncCredentialFactory { context in
            struct CredentialsFile: Decodable {
                var type: String
            }

            let credentialsFile: CredentialsFile
            do {
                credentialsFile = try JSONDecoder().decode(CredentialsFile.self, from: data)
            } catch {
                throw CredentialError(message: "Failed to parse contents of the credentials file as an object")
            }

            switch credentialsFile.type {
            case "service_account":
                return try ServiceAccountCredential(credentialsFileData: data, httpClient: context.httpClient)
            case "authorized_user":
                return try RefreshTokenCredential(credentialsFileData: data, httpClient: context.httpClient)
            default:
                throw CredentialError(message: "Invalid contents in the credentials file")
            }
        }
    }

    public static var environment: SyncCredentialFactory {
        return SyncCredentialFactory { context in
            guard let googleApplicationCredential = ProcessInfo.processInfo.environment["GOOGLE_APPLICATION_CREDENTIALS"] else {
                throw CredentialError(message: "GOOGLE_APPLICATION_CREDENTIALS is not set")
            }
            return json(fileURL: URL(filePath: googleApplicationCredential))
        }
    }

    ///  `~/.config/gcloud/application_default_credentials.json`
    public static var configFile: SyncCredentialFactory {
        func defaultGcloudCredentialURL() -> URL {
#if os(Windows)
            // Windows has a dedicated low-rights location for apps at ~/Application Data
            fatalError("not supported")
#endif
            let home = FileManager.default.homeDirectoryForCurrentUser
            let configDirectory = home.appendingPathComponent(".config", isDirectory: true)

            return configDirectory
                .appendingPathComponent("gcloud/application_default_credentials.json")
        }

        return SyncCredentialFactory { context in
            let fileURL = defaultGcloudCredentialURL()
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                throw CredentialError(message: "\(fileURL) is not found")
            }
            return json(fileURL: fileURL)
        }
    }

    public static func selector(_ providers: SyncCredentialFactory...) -> SyncCredentialFactory {
        return SyncCredentialFactory { context -> any Credential in
            var errors: [any Error] = []
            for provider in providers {
                do {
                    return try provider.makeCredential(context: context)
                } catch {
                    errors.append(error)
                }
            }
            throw CredentialError(message: "no avaliable credentials. errors=[\(errors.map({ "\($0)" }).joined(separator: ", "))]")
        }
    }

    public static var emulator: SyncCredentialFactory {
        return SyncCredentialFactory { _ in
            EmulatorCredential()
        }
    }
}

extension AsyncCredentialFactory {
    public static var applicationDefault: AsyncCredentialFactory {
#if os(Linux)
        return selector(SyncCredentialFactory.environment, SyncCredentialFactory.configFile, computeEngine)
#else
        return selector(SyncCredentialFactory.environment, SyncCredentialFactory.configFile)
#endif
    }

    public static func custom(_ factory: @Sendable @escaping (Context) async throws -> any Credential) ->  AsyncCredentialFactory {
        AsyncCredentialFactory(cb: factory)
    }

    public static var computeEngine: AsyncCredentialFactory {
        return AsyncCredentialFactory { context in
            return try await ComputeEngineCredential.makeFromMetadata(httpClient: context.httpClient)
        }
    }

    public static func selector(_ providers: any AsyncCredentialFactoryProtocol...) -> AsyncCredentialFactory {
        return AsyncCredentialFactory { context -> any Credential in
            var errors: [any Error] = []
            for provider in providers {
                do {
                    return try await provider.makeCredential(context: context)
                } catch {
                    errors.append(error)
                }
            }
            throw CredentialError(message: "no avaliable credentials. errors=[\(errors.map({ "\($0)" }).joined(separator: ", "))]")
        }
    }
}
