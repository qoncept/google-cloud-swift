import AsyncHTTPClient
import Atomics
import NIO
import NIOConcurrencyHelpers
import Logging
import Foundation

public enum GCPClientError: Error {
    case alreadyShutdown
}

public struct GCPClient: Sendable {
    internal var credentialFactory: CredentialFactory

    public let httpClient: HTTPClient
    public var clientLogger: Logger
    internal let isShutdown = ManagedAtomic<Bool>(false)

    public enum HTTPClientProvider: Sendable {
        case shared(HTTPClient)
        case createNewWithEventLoopGroup(any EventLoopGroup)
        case createNew
    }
    internal var httpClientProvider: HTTPClientProvider

    public struct Options: Sendable {
        public var requestLogLevel: Logger.Level
        public var errorLogLevel: Logger.Level

        public init(
            requestLogLevel: Logger.Level = .debug,
            errorLogLevel: Logger.Level = .debug
        ) {
            self.requestLogLevel = requestLogLevel
            self.errorLogLevel = errorLogLevel
        }
    }
    public var options: Options

    public init(
        credentialFactory: CredentialFactory = .applicationDefault,
        options: Options = Options(),
        httpClientProvider: HTTPClientProvider,
        logger clientLogger: Logger = Logger(label: "GCP-no-op-logger", factory: { _ in SwiftLogNoOpLogHandler() })
    ) {
        let httpClientConfig = AsyncHTTPClient.HTTPClient.Configuration(
            timeout: .init(connect: .seconds(10)),
            decompression: .enabled(limit: .ratio(20))
        )
        self.httpClientProvider = httpClientProvider
        switch httpClientProvider {
        case .shared(let providedHTTPClient):
            httpClient = providedHTTPClient
        case .createNewWithEventLoopGroup(let elg):
            httpClient = AsyncHTTPClient.HTTPClient(
                eventLoopGroupProvider: .shared(elg),
                configuration: httpClientConfig
            )
        case .createNew:
            httpClient = AsyncHTTPClient.HTTPClient(
                eventLoopGroupProvider: .singleton,
                configuration: httpClientConfig
            )
        }

        let credentialProvider = credentialProviderFactory.createProvider(context: .init(
            httpClient: httpClient,
            logger: clientLogger,
            options: options
        ))
        self.credentialProvider = credentialProvider
        self.clientLogger = clientLogger
        self.options = options
    }

    @available(*, noasync, message: "syncShutdown() can block indefinitely, prefer shutdown()", renamed: "shutdown()")
    public func syncShutdown() throws {
        let errorStorage: NIOLockedValueBox<(any Error)?> = .init(nil)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await shutdown()
            } catch {
                errorStorage.withLockedValue { errorStorage in
                    errorStorage = error
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
        try errorStorage.withLockedValue { errorStorage in
            if let error = errorStorage {
                throw error
            }
        }
    }

    public func shutdown() async throws {
        guard isShutdown.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged else {
            throw GCPClientError.alreadyShutdown
        }


        switch httpClientProvider {
        case .createNew, .createNewWithEventLoopGroup:
            do {
                try await httpClient.shutdown()
            } catch {
                clientLogger.log(level: self.options.errorLogLevel, "Error shutting down HTTP client", metadata: [
                    "aws-error": "\(error)",
                ])
                throw error
            }
        case .shared:
            return
        }
    }
}
