struct EmulatorCredential: Credential & Sendable {
    func getAccessToken() async throws -> GoogleOAuthAccessToken {
        GoogleOAuthAccessToken(
            accessToken: "owner",
            exipresIn: 3600
        )
    }
}
