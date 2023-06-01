@testable import FirebaseAdmin
import NIOPosix
import XCTest
import Logging

private let testingProjectID = "testing-project-id"

final class AuthTest: XCTestCase {
    private static let client = AsyncHTTPClient.HTTPClient(eventLoopGroupProvider: .createNew)

    private static var emulatorURL: URL? = Auth.emulatorBaseURL()

    override class func setUp() {
        super.setUp()
        initLogger()

        if let url = Self.emulatorURL {
            let endpoint = Auth.emulatorAPIBaseURL(url: url)!.appendingPathComponent("projects/\(testingProjectID)/accounts")
            do {
                let request = try HTTPClient.Request(url: endpoint, method: .DELETE)
                _ = try client.execute(request: request).wait()
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    override class func tearDown() {
        do {
            try client.syncShutdown()
        } catch {
            XCTFail("\(error)")
        }

        super.tearDown()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(Self.emulatorURL == nil, "AuthTest uses Firebase Auth Emulator.")
    }

    private func makeAuth() throws -> Auth {
        try Auth(
            credentialStore: CredentialStore(credential: MockCredential()),
            client: Self.client,
            projectID: testingProjectID
        )
    }

    func testCreateUser() async throws {
        let auth = try makeAuth()

        do {
            let uid = try await auth.createUser(UserToCreate(
                email: "testCreateUser@example.com",
                password: "012345"
            ))
            XCTAssertTrue(!uid.isEmpty)
        } catch {
            dump(error)
            XCTFail("\(error)")
        }
    }

    func testGetUser() async throws {
        let auth = try makeAuth()

        let uid = try await XCTAssertNoThrow {
            try await auth.createUser(UserToCreate(
                email: "testGetUser@example.com",
                password: "111111"
            ))
        }

        let result = try await XCTUnwrap {
            try await auth.user(for: uid)
        }
        XCTAssertEqual(result.uid, uid)
        XCTAssertEqual(result.email, "testGetUser@example.com".lowercased())
        XCTAssertEqual(result.providers.first?.providerID, "password")
        XCTAssertTrue(try XCTUnwrap(result.passwordHash).hasSuffix("password=111111"))
    }

    func testGetUserNotFound() async throws {
        let auth = try makeAuth()

        let result = try await XCTAssertNoThrow {
            try await auth.user(for: "aaaaaaaaaaaaaaaaaaaaa")
        }
        XCTAssertNil(result)
    }

    func testGetUserEmail() async throws {
        let auth = try makeAuth()

        _ = try await auth.createUser(UserToCreate(
            email: "testGetUserEmail@example.com",
            password: "012345"
        ))

        let user = try await auth.user(byEmail: "testGetUserEmail@example.com".lowercased())
        XCTAssertNotNil(user)
    }

    func testGetUserEmailNotFound() async throws {
        let auth = try makeAuth()

        let user = try await auth.user(byEmail: "xxxxxx@example.com")
        XCTAssertNil(user)
    }

    func testGetUsers() async throws {
        let auth = try makeAuth()

        let ids = [
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.0@example.com",
                password: "123456"
            )),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.1@example.com",
                password: "123456"
            )),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.2@example.com",
                password: "123456"
            )),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.3@example.com",
                password: "123456"
            )),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.4@example.com",
                password: "123456"
            )),
            try await auth.createUser(UserToCreate(
                email: "testGetUsers.5@example.com",
                password: "123456"
            ))
        ]

        let users = try await auth.users(for: [
            .uid(ids[0]),
            .uid(ids[1]),
            .email("testGetUsers.1@example.com".lowercased()),
            .email("testGetUsers.3@example.com".lowercased())
        ])
        
        XCTAssertEqual(
            Set(users.map { $0.uid }),
            [ids[0], ids[1], ids[3]]
        )
    }

    func testGetUsersEmpty() async throws {
        let auth = try makeAuth()

        let users = try await auth.users(for: [])

        XCTAssertEqual(users.count, 0)
    }

    func testUpdateUserConsistentID() async throws {
        let auth = try makeAuth()
        let uid = try await auth.createUser(
            UserToCreate(email: "testUpdateUserID@example.com", password: "123456")
        )
        let user0o = try await auth.user(for: uid)
        let user0 = try XCTUnwrap(user0o)
        XCTAssertFalse(user0.disabled)

        try await auth.updateUser(.init(disabled: true), for: uid)
        let user1o = try await auth.user(for: uid)
        let user1 = try XCTUnwrap(user1o)
        XCTAssertEqual(user1.uid, uid)
        XCTAssertTrue(user1.disabled)
    }

    private func runUpdateUser(
        create modifyCreate: ((inout UserToCreate) -> Void)? = nil,
        properties: UpdateUserProperties,
        line: UInt = #line
    ) async throws -> UserRecord {
        var create = UserToCreate(
            displayName: "cat",
            email: "updateUser_\(line)@example.com",
            password: "123456"
        )
        modifyCreate?(&create)

        let auth = try makeAuth()
        let uid0 = try await auth.createUser(create)
        try await auth.updateUser(properties, for: uid0)
        let usero = try await auth.user(for: uid0)
        return try XCTUnwrap(usero)
    }

    func testUpdateUserDisplayName() async throws {
        let u = try await runUpdateUser(
            properties: .init(displayName: .set("dog"))
        )
        XCTAssertEqual(u.displayName, "dog")
    }

    func testUpdateUserDeleteDisplayName() async throws {
        let u = try await runUpdateUser(
            properties: .init(displayName: .delete)
        )
        XCTAssertEqual(u.displayName, nil)
    }

    func testUpdateUserEmptyDisplayName() async throws {
        let u = try await runUpdateUser(
            properties: .init(displayName: .set(""))
        )
        XCTAssertEqual(u.displayName, "")
    }

    func testUpdateUserEmail() async throws {
        let u = try await runUpdateUser(
            properties: .init(email: "testUpdateUserEmail.updated@example.com")
        )
        XCTAssertEqual(u.email, "testUpdateUserEmail.updated@example.com".lowercased())
    }

    func testUpdateUserDeletePhoneNumber() async throws {
        let u = try await runUpdateUser(
            create: { $0.phoneNumber = "+81-090-1234-1234" },
            properties: .init(phoneNumber: .delete)
        )
        XCTAssertEqual(u.phoneNumber, nil)
    }

    func testUpdateUserPassword() async throws {
        let u = try await runUpdateUser(
            properties: .init(password: "987654")
        )
        // TODO: attempt to login
        _ = u
    }

    func testUpdateUserPhotoURL() async throws {
        let u = try await runUpdateUser(
            properties: .init(photoURL: .set("https://example.com/cat.jpeg"))
        )
        XCTAssertEqual(u.photoURL, "https://example.com/cat.jpeg")
    }

    func testSetCustomClaims() async throws {
        let auth = try makeAuth()

        let uid = try await XCTAssertNoThrow {
            try await auth.createUser(UserToCreate(
                email: "testSetCustomClaims@example.com",
                password: "012345"
            ))
        }

        await XCTAssertNoThrow {
            try await auth.setCustomUserClaims([
                "key1": "value1",
                "key2": "value2",
            ], for: uid)
        }

        let result = try await XCTUnwrap {
            try await auth.user(for: uid)
        }
        XCTAssertEqual(result.customClaims["key1"], "value1")
        XCTAssertEqual(result.customClaims["key2"], "value2")
    }

    func testDeleteUser() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(UserToCreate(
            email: "testDeleteUser_\(#line)@example.com",
            password: "012345"
        ))
        let userBeforeRemoved = try await XCTAssertNoThrow { try await auth.user(for: uid) }
        XCTAssertNotNil(userBeforeRemoved)

        await XCTAssertNoThrow {
            try await auth.deleteUser(for: uid)
        }

        let userRemoved = try await XCTAssertNoThrow { try await auth.user(for: uid) }
        XCTAssertNil(userRemoved)
    }
}
