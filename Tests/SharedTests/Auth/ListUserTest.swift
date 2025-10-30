import AsyncHTTPClient
@testable import FirebaseAdmin
import NIOPosix
import Testing
import Logging

private let testingProjectID = "testing-project-id"

extension AuthTest {
    struct ListUserTest {}
}

extension AuthTest.ListUserTest {
    private func makeAuth() throws -> Auth {
        try Auth(
            client: .mockCredentialClient,
            projectID: testingProjectID
        )
    }

    @Test func listUser() async throws {
        let auth = try makeAuth()

        for index in 0..<90 {
            _ = try await auth.createUser(
                .init(
                    displayName: "\(index)",
                    email: "\(index)@firebase.com",
                    password: "000000"
                )
            ).get()
        }

        var founds: [Int: UserRecord] = [:]
        var callCount = 0
        var pageToken: String? = nil
        while true {
            callCount += 1
            let result = try await auth.listUsers(pageSize: 20, pageToken: pageToken).get()
            if callCount == 5 {
                #expect(result.users.count == 10)
            } else {
                #expect(result.users.count == 20)
            }
            for user in result.users {
                let displayName = try #require(user.displayName)
                let index = try #require(Int(displayName))
                #expect(user.email == "\(displayName)@firebase.com")
                founds[index] = user
            }
            guard let nextPageToken = result.nextPageToken else {
                break
            }
            pageToken = nextPageToken
        }

        #expect(callCount == 5)

        let foundIDs = Set(founds.keys)
        #expect(foundIDs == Set(0..<90))
    }
}
