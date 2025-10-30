import GoogleCloudBase

func gcpClientOverload() throws {
    _ = try GCPClient(credentialFactory: .selector(.environment, .configFile))
}

func gcpClientOverloadAsync() async throws {
    _ = try await GCPClient()
    _ = try await GCPClient(credentialFactory: .applicationDefault)
}
