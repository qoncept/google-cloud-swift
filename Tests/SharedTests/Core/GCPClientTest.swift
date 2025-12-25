import GoogleCloudBase
import Testing

@Suite struct GCPClientTest {
    enum MyError: Error {
        case failure
    }

    @Test func makeCredentialFailed() async {
        // sync
        #expect(throws: MyError.self) {
            _ = try GCPClient(credentialFactory: SyncCredentialFactory.custom { _ in
                throw MyError.failure
            })
        }

        // async
        await #expect(throws: MyError.self) {
            _ = try await GCPClient(credentialFactory: AsyncCredentialFactory.custom { _ in
                throw MyError.failure
            })
        }
    }
}

#if ServiceLifecycleSupport

import Logging
import ServiceLifecycle

extension GCPClientTest {
    @Test func serviceLifecycle() async throws {
        let logger = Logger(label: "GCPClientTest.\(#function)")

        let client = try GCPClient(credentialFactory: .mock(), logger: logger)
        let serviceGroup = ServiceGroup(services: [client], logger: logger)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) {
                try await serviceGroup.run()
            }
            group.addTask(priority: .low) {
                await serviceGroup.triggerGracefulShutdown()
            }
            try await group.waitForAll()
        }
    }
}
#endif  // ServiceLifecycleSupport

func gcpClientOverload() throws {
    _ = try GCPClient(credentialFactory: .selector(.environment, .configFile))
}

func gcpClientOverloadAsync() async throws {
    _ = try await GCPClient()
    _ = try await GCPClient(credentialFactory: .applicationDefault)
}
