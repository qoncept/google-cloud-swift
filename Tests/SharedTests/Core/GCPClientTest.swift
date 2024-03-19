import GoogleCloudBase

func testGCPClientOverload() throws {
    _ = try GCPClient(credentialFactory: .selector(.environment, .configFile))
}

func testGCPClientOverloadAsync() async throws {
    _ = try await GCPClient()
    _ = try await GCPClient(credentialFactory: .applicationDefault)
}
