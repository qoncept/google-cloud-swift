#if ServiceLifecycleSupport

import ServiceLifecycle

extension GCPClient: Service {
    public func run() async throws {
        try? await gracefulShutdown()
        try await self.shutdown()
    }
}

#endif  // ServiceLifecycleSupport
