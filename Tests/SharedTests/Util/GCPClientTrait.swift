import GoogleCloudBase
import Testing

extension SuiteTrait where Self == GCPClientTrait {
    static var gcpClient: Self { .init() }
}

extension GCPClient {
    @TaskLocal static var mockCredentialClient: GCPClient!
}

struct GCPClientTrait: SuiteTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        initLogger()

        let client = try GCPClient(credentialFactory: .mock())

        var didShutdown = false
        defer {
            if !didShutdown {
                Task {
                    try await client.shutdown()
                }
            }
        }
        try await GCPClient.$mockCredentialClient.withValue(client, operation: function)
        didShutdown = true
        try await client.shutdown()
    }
}
