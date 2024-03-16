import AsyncHTTPClient
import Foundation
import Logging
import NIOConcurrencyHelpers
import NIOCore

public struct CredentialFactory {
    public struct Context {
        public var httpClient: HTTPClient
        public var logger: Logger
    }

    private var cb: (Context) async throws -> any Credential
    init(cb: @escaping (Context) async throws -> any Credential) {
        self.cb = cb
    }
    init(next: @escaping (Context) throws -> CredentialFactory) {
        self.cb = { context in
            let factory = try next(context)
            return try await factory.makeCredential(context: context)
        }
    }

    internal func makeCredential(context: Context) async throws -> any Credential {
        try await self.cb(context)
    }
}

extension CredentialFactory {
    public static var applicationDefault: CredentialFactory {
#if os(Linux)
        return .selector(.environment, .configFile, .computeEngine)
#else
        return .selector(.environment, .configFile)
#endif
    }

    public static func custom(_ factory: @escaping (Context) async throws -> any Credential) -> CredentialFactory {
        CredentialFactory(cb: factory)
    }

    public static func `static`(base64EncodedString string: String) -> CredentialFactory {
        CredentialFactory { context in
            guard let data = Data(base64Encoded: string) else {
                throw CredentialError(message: "Failed to decode base64EncodedString")
            }
            return json(data: data)
        }
    }

    public static func json(fileURL: URL) -> CredentialFactory {
        return CredentialFactory { context in
            let data = try Data(contentsOf: fileURL)
            return .json(data: data)
        }
    }

    public static func json(data: Data) -> CredentialFactory {
        return CredentialFactory { context in
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

    public static var computeEngine: CredentialFactory {
        CredentialFactory { context in
            return try await ComputeEngineCredential.makeFromMetadata(httpClient: context.httpClient)
        }
    }

    public static var environment: CredentialFactory {
        CredentialFactory { context in
            guard let googleApplicationCredential = ProcessInfo.processInfo.environment["GOOGLE_APPLICATION_CREDENTIALS"] else {
                throw CredentialError(message: "GOOGLE_APPLICATION_CREDENTIALS is not set")
            }
            return .json(fileURL: URL(filePath: googleApplicationCredential))
        }
    }

    ///  `~/.config/gcloud/application_default_credentials.json`
    public static var configFile: CredentialFactory {
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

        return CredentialFactory { context in
            let fileURL = defaultGcloudCredentialURL()
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                throw CredentialError(message: "\(fileURL) is not found")
            }
            return .json(fileURL: fileURL)
        }
    }

    public static func selector(_ providers: CredentialFactory...) -> CredentialFactory {
        CredentialFactory { context in
            var errors: [(String, any Error)] = []
            for provider in providers {
                do {
                    return try await provider.makeCredential(context: context)
                } catch {
                    errors.append(("\(type(of: provider))", error))
                }
            }
            throw CredentialError(message: "no avaliable credentials. errors=[\(errors.map({ "\($0): \($1)" }).joined(separator: ", "))]")
        }
    }

    public static func emulator() -> CredentialFactory {
        CredentialFactory { _ in
            EmulatorCredential()
        }
    }
}
