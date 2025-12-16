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

func gcpClientOverload() throws {
    _ = try GCPClient(credentialFactory: .selector(.environment, .configFile))
}

func gcpClientOverloadAsync() async throws {
    _ = try await GCPClient()
    _ = try await GCPClient(credentialFactory: .applicationDefault)
}
