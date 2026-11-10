import GoogleCloudBase
import Testing

extension SuiteTrait where Self == GCPClientTrait {
    static var gcpClient: Self { .init() }
    static func gcpClient(
        _ configure: @escaping @Sendable (isolated MockCredential) -> Void
    ) -> Self {
        .init(configureCredential: configure)
    }

}

extension GCPClient {
    @TaskLocal static var mockCredentialClient: GCPClient!
}

struct GCPClientTrait: SuiteTrait, TestScoping {
    var configureCredential: @Sendable (isolated MockCredential) -> Void = { _ in }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        initLogger()

        let credential = MockCredential()
        await configureCredential(credential)

        let client = try GCPClient(
            credentialFactory: .mock(credential: credential)
        )
        defer {
            do {
                try await client.shutdown()
            } catch {
                Issue.record(error)
            }
        }
        try await GCPClient.$mockCredentialClient.withValue(client) {
            try await function()
        }
    }
}
