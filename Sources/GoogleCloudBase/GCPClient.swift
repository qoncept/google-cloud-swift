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
    public static let loggingDisabled = Logger(label: "GCP-no-op-logger", factory: { _ in SwiftLogNoOpLogHandler() })

    public let httpClient: HTTPClient
    package let httpClientCompressionEnabled: Bool
    internal var clientLogger: Logger
    internal let isShutdown = ManagedAtomic<Bool>(false)

    public enum HTTPClientProvider: Sendable {
        case shared(HTTPClient)
        case createNewWithEventLoopGroup(any EventLoopGroup)
        case createNew

        func build(logger: Logger?) -> (HTTPClient, compressionEnabled: Bool) {
            var httpClientConfig = AsyncHTTPClient.HTTPClient.Configuration(
                timeout: .init(connect: .seconds(10)),
                decompression: .enabled(limit: .none) // INFO: decompression limit has serious bug so not usable. https://github.com/apple/swift-nio-extras/pull/221
            )
            httpClientConfig.httpVersion = .http1Only // INFO: AHC or NIO may be wrong somewhere and sometimes not correctly handle gziped responses in http/2
            switch self {
            case .shared(let providedHTTPClient):
                return (providedHTTPClient, false)
            case .createNewWithEventLoopGroup(let elg):
                let httpClient = AsyncHTTPClient.HTTPClient(
                    eventLoopGroupProvider: .shared(elg),
                    configuration: httpClientConfig,
                    backgroundActivityLogger: logger ?? GCPClient.loggingDisabled
                )
                return (httpClient, true)
            case .createNew:
                let httpClient = AsyncHTTPClient.HTTPClient(
                    eventLoopGroupProvider: .singleton,
                    configuration: httpClientConfig,
                    backgroundActivityLogger: logger ?? GCPClient.loggingDisabled
                )
                return (httpClient, true)
            }
        }
    }
    internal var httpClientProvider: HTTPClientProvider

    public struct Options: Sendable {
        public var requestLogLevel: Logger.Level
        public var errorLogLevel: Logger.Level

        public init(
            requestLogLevel: Logger.Level = .debug,
            errorLogLevel: Logger.Level = .error
        ) {
            self.requestLogLevel = requestLogLevel
            self.errorLogLevel = errorLogLevel
        }
    }
    internal var options: Options

    public var credential: any Credential

    public init(
        credentialFactory: SyncCredentialFactory,
        options: Options = Options(),
        httpClientProvider: HTTPClientProvider = .createNew,
        logger clientLogger: Logger = Self.loggingDisabled
    ) throws {
        self.httpClientProvider = httpClientProvider
        (httpClient, httpClientCompressionEnabled) = httpClientProvider.build(logger: clientLogger)
        self.clientLogger = clientLogger
        self.options = options
        do {
            self.credential = try credentialFactory.makeCredential(
                context: .init(httpClient: httpClient, logger: clientLogger)
            )
        } catch {
            Task { [httpClient, httpClientProvider] in
                try await Self.shutdownHTTPClient(client: httpClient, provider: httpClientProvider)
            }
            throw error
        }
    }

    @_disfavoredOverload
    public init(
        credentialFactory: some AsyncCredentialFactoryProtocol = .applicationDefault,
        options: Options = Options(),
        httpClientProvider: HTTPClientProvider = .createNew,
        logger clientLogger: Logger = Self.loggingDisabled
    ) async throws {
        self.httpClientProvider = httpClientProvider
        (httpClient, httpClientCompressionEnabled) = httpClientProvider.build(logger: clientLogger)
        self.clientLogger = clientLogger
        self.options = options
        do {
            self.credential = try await credentialFactory.makeCredential(
                context: .init(httpClient: httpClient, logger: clientLogger)
            )
        } catch {
            Task { [httpClient, httpClientProvider] in
                try await Self.shutdownHTTPClient(client: httpClient, provider: httpClientProvider)
            }
            throw error
        }
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

        do {
            try await Self.shutdownHTTPClient(client: httpClient, provider: httpClientProvider)
        } catch {
            clientLogger.log(level: self.options.errorLogLevel, "Error shutting down HTTP client", metadata: [
                "aws-error": "\(error)",
            ])
            throw error
        }
    }

    private static func shutdownHTTPClient(
        client: HTTPClient,
        provider: HTTPClientProvider
    ) async throws {
        switch provider {
        case .shared:
            return
        case .createNew, .createNewWithEventLoopGroup:
            try await client.shutdown()
        }
    }
}
