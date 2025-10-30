import AsyncHTTPClient
@testable import FirebaseAdmin
import NIOPosix
import Testing
import Logging

private let testingProjectID = "testing-project-id"

@Suite(
    .gcpClient,
    .serialized,
    .enabled(if: Auth.emulatorBaseURL() != nil, "AuthTest uses Firebase Auth Emulator.")
) struct AuthTest {
    init() async throws {
        if let url = Auth.emulatorBaseURL() {
            let endpoint = Auth.emulatorAPIBaseURL(url: url)!.appendingPathComponent("projects/\(testingProjectID)/accounts")
            var request = HTTPClientRequest(url: endpoint.absoluteString)
            request.method = .DELETE
            _ = try await HTTPClient.shared.execute(request, timeout: .seconds(1))
        }
    }

    private func makeAuth() throws -> Auth {
        try Auth(
            client: .mockCredentialClient,
            projectID: testingProjectID
        )
    }

    @Test func createUser() async throws {
        let auth = try makeAuth()

        do {
            let uid = try await auth.createUser(UserToCreate(
                email: "testCreateUser@example.com",
                password: "012345"
            )).get()
            #expect(!uid.isEmpty)
        } catch {
            dump(error)
            Issue.record("\(error)")
        }
    }

    @Test func createUserWithID() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(UserToCreate(
            localId: "tama",
            email: "testCreateUserWithID@example.com",
            password: "012345"
        )).get()
        #expect(uid == "tama")
    }

    @Test func createUserErrorEmailExists() async throws {
        let auth = try makeAuth()

        let email = "testCreateUserErrorEmailExists@example.com"

        let _ = try await auth.createUser(.init(
            email: email,
            password: "123456"
        )).get()

        let ret = try await auth.createUser(.init(
            email: email,
            password: "123456"
        ))
        let error = try #require(ret.failure)
        #expect(error.code == .emailExists)
    }

    @Test func getUser() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(UserToCreate(
            email: "testGetUser@example.com",
            password: "111111"
        )).get()

        let result = try #require(try await auth.user(for: uid))
        #expect(result.uid == uid)
        #expect(result.email == "testGetUser@example.com".lowercased())
        #expect(result.providers.first?.providerID == "password")
        #expect(try #require(result.passwordHash).hasSuffix("password=111111"))
    }

    @Test func getUserNotFound() async throws {
        let auth = try makeAuth()

        #expect(try await auth.user(for: "aaaaaaaaaaaaaaaaaaaaa") == nil)
    }

    @Test func getUserEmail() async throws {
        let auth = try makeAuth()

        _ = try await auth.createUser(UserToCreate(
            email: "testGetUserEmail@example.com",
            password: "012345"
        ))

        let user = try await auth.user(byEmail: "testGetUserEmail@example.com".lowercased())
        #expect(user != nil)
    }

    @Test func getUserEmailNotFound() async throws {
        let auth = try makeAuth()

        let user = try await auth.user(byEmail: "xxxxxx@example.com")
        #expect(user == nil)
    }

    @Test func getUsers() async throws {
        let auth = try makeAuth()

        let ids = [
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.0@example.com",
                password: "123456"
            )).get(),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.1@example.com",
                password: "123456"
            )).get(),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.2@example.com",
                password: "123456"
            )).get(),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.3@example.com",
                password: "123456"
            )).get(),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.4@example.com",
                password: "123456"
            )).get(),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.5@example.com",
                password: "123456"
            )).get()
        ]

        let users = try await auth.users(for: [
            .uid(ids[0]),
            .uid(ids[1]),
            .email("testGetUsers.1@example.com".lowercased()),
            .email("testGetUsers.3@example.com".lowercased())
        ])
        
        #expect(
            Set(users.map { $0.uid }) == [ids[0], ids[1], ids[3]]
        )
    }

    @Test func getUsersEmpty() async throws {
        let auth = try makeAuth()

        let users = try await auth.users(for: [])

        #expect(users.count == 0)
    }

    @Test func updateUserConsistentID() async throws {
        let auth = try makeAuth()
        let uid = try await auth.createUser(
            UserToCreate(email: "testUpdateUserID@example.com", password: "123456")
        ).get()
        let user0o = try await auth.user(for: uid)
        let user0 = try #require(user0o)
        #expect(!user0.disabled)

        try await auth.updateUser(.init(disabled: true), for: uid).get()
        let user1o = try await auth.user(for: uid)
        let user1 = try #require(user1o)
        #expect(user1.uid == uid)
        #expect(user1.disabled)
    }

    private func runUpdateUser(
        create modifyCreate: ((inout UserToCreate) -> Void)? = nil,
        properties: UpdateUserProperties,
        line: UInt = #line
    ) async throws -> Result<UserRecord, UpdateUserError> {
        var create = UserToCreate(
            displayName: "cat",
            email: "updateUser_\(line)@example.com",
            password: "123456"
        )
        modifyCreate?(&create)

        let auth = try makeAuth()
        let uid0 = try await auth.createUser(create).get()
        switch try await auth.updateUser(properties, for: uid0) {
        case .failure(let error): return .failure(error)
        case .success: break
        }
        let usero = try await auth.user(for: uid0)
        return .success(try #require(usero))
    }

    @Test func updateUserDisplayName() async throws {
        let u = try await runUpdateUser(
            properties: .init(displayName: .set("dog"))
        ).get()
        #expect(u.displayName == "dog")
    }

    @Test func updateUserDeleteDisplayName() async throws {
        let u = try await runUpdateUser(
            properties: .init(displayName: .delete)
        ).get()
        #expect(u.displayName == nil)
    }

    @Test func updateUserErrorEmptyDisplayName() async throws {
        let result = try await runUpdateUser(
            properties: .init(displayName: .set(""))
        )
        let error = try #require(result.failure)
        #expect(error.code == .invalidDisplayName)
        #expect(error.message == "display name must be a non-empty string")
    }

    @Test func updateUserEmail() async throws {
        let u = try await runUpdateUser(
            properties: .init(email: "testUpdateUserEmail.updated@example.com")
        ).get()
        #expect(u.email == "testUpdateUserEmail.updated@example.com".lowercased())
    }

    @Test func updateUserDeletePhoneNumber() async throws {
        let u = try await runUpdateUser(
            create: { $0.phoneNumber = "+81-090-1234-1234" },
            properties: .init(phoneNumber: .delete)
        ).get()
        #expect(u.phoneNumber == nil)
    }

    @Test func updateUserPassword() async throws {
        let u = try await runUpdateUser(
            properties: .init(password: "987654")
        ).get()
        // TODO: attempt to login
        _ = u
    }

    @Test func updateUserPhotoURL() async throws {
        let u = try await runUpdateUser(
            properties: .init(photoURL: .set("https://example.com/cat.jpeg"))
        ).get()
        #expect(u.photoURL == "https://example.com/cat.jpeg")
    }

    @Test func updateUserErrorInvalidEmail() async throws {
        let auth = try makeAuth()
        let id = try await auth.createUser(.init(
            email: "testUpdateUserErrorInvalidEmail@example.com",
            password: "123456"
        )).get()
        let result = try await auth.updateUser(
            .init(email: "a"), for: id
        )
        let error = try #require(result.failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "malformed email string: a")
    }

    @Test func updateUserErrorEmailExists() async throws {
        let auth = try makeAuth()

        let email0 = "testUpdateUserErrorEmailExists.0@example.com"
        let email1 = "testUpdateUserErrorEmailExists.1@example.com"

        _ = try await auth.createUser(.init(email: email0, password: "123456")).get()
        let id = try await auth.createUser(.init(email: email1, password: "123456")).get()

        let result = try await auth.updateUser(.init(email: email0), for: id)
        let error: UpdateUserError = try #require(result.failure)
        #expect(error.code == .emailExists)
        #expect(error.message == nil)
    }

    @Test func updateUserErrorInvalidPhoneNumber() async throws {
        let auth = try makeAuth()

        let id = try await auth.createUser(.init(
            email: "testUpdateUserErrorInvalidPhoneNumber@example.com",
            password: "123456"
        )).get()
        let result = try await auth.updateUser(
            .init(phoneNumber: .set("aaa")), for: id
        )
        let error = try #require(result.failure)
        #expect(error.code == .invalidPhoneNumber)
        #expect(error.message == "phone number must be a valid, E.164 compliant identifier")
    }

    @Test func updateUserErrorEmptyPhotoURL() async throws {
        let auth = try makeAuth()
        let id = try await auth.createUser(.init(
            email: "testUpdateUserErrorInvalidPhotoURL@example.com",
            password: "123456"
        )).get()
        let result = try await auth.updateUser(
            .init(photoURL: .set("")), for: id
        )
        let error = try #require(result.failure)
        #expect(error.code == .invalidPhotoURL)
        #expect(error.message == "photoURL must be a non-empty string")
    }

    @Test func updateUserErrorWeakPassword() async throws {
        let auth = try makeAuth()

        let id = try await auth.createUser(.init(
            email: "testUpdateUserErrorWeakPassword@example.com",
            password: "123456"
        )).get()
        let result = try await auth.updateUser(.init(password: "123"), for: id)
        let error: UpdateUserError = try #require(result.failure)
        #expect(error.code == .weakPassword)
        #expect(error.message == "password must be a string at least 6 characters long")
    }

    @Test func setCustomClaims() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(UserToCreate(
            email: "testSetCustomClaims@example.com",
            password: "012345"
        )).get()

        try await auth.setCustomUserClaims([
            "key1": "value1",
            "key2": "value2",
        ], for: uid)

        let result = try #require(try await auth.user(for: uid))
        #expect(result.customClaims["key1"] == "value1")
        #expect(result.customClaims["key2"] == "value2")
    }

    @Test func deleteUser() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(UserToCreate(
            email: "testDeleteUser_\(#line)@example.com",
            password: "012345"
        )).get()
        let userBeforeRemoved = try await auth.user(for: uid)
        #expect(userBeforeRemoved != nil)

        try await auth.deleteUser(for: uid)

        let userRemoved = try await auth.user(for: uid)
        #expect(userRemoved == nil)
    }
}
