@testable import FirebaseAdmin
import NIOPosix
import XCTest
import Logging

private let testingProjectID = "testing-project-id"

final class AuthTest: XCTestCase {
    private static let client = AsyncHTTPClient.HTTPClient(eventLoopGroupProvider: .createNew)

    override class func setUp() {
        super.setUp()
        initLogger()

        if let authEmulatorHost = ProcessInfo.processInfo.environment[emulatorHostEnvVar] {
            let endpoint = "http://\(authEmulatorHost)/emulator/v1/projects/\(testingProjectID)/accounts"
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
        try XCTSkipIf(ProcessInfo.processInfo.environment[emulatorHostEnvVar] == nil, "AuthTest uses Firebase Auth Emulator.")
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
            let uid = try await auth.createUser(user: UserToCreate(
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
            try await auth.createUser(user: UserToCreate(
                email: "testGetUser@example.com",
                password: "012345"
            ))
        }

        let result = try await XCTUnwrap {
            try await auth.getUser(uid: uid)
        }
        XCTAssertEqual(result.uid, uid)
        XCTAssertEqual(result.email, "testGetUser@example.com".lowercased())
        XCTAssertEqual(result.providers.first?.providerID, "password")
    }

    func testGetUserNotFound() async throws {
        let auth = try makeAuth()

        let result = try await XCTAssertNoThrow {
            try await auth.getUser(uid: "aaaaaaaaaaaaaaaaaaaaa")
        }
        XCTAssertNil(result)
    }

    func testGetUserEmail() async throws {
        let auth = try makeAuth()

        _ = try await auth.createUser(user: UserToCreate(
            email: "testGetUserEmail@example.com",
            password: "012345"
        ))

        let user = try await auth.getUser(email: "testGetUserEmail@example.com".lowercased())
        XCTAssertNotNil(user)
    }

    func testGetUserEmailNotFound() async throws {
        let auth = try makeAuth()

        let user = try await auth.getUser(email: "xxxxxx@example.com")
        XCTAssertNil(user)
    }

    func testUpdateUserConsistentID() async throws {
        let auth = try makeAuth()
        let uid0 = try await auth.createUser(
            user: UserToCreate(email: "testUpdateUserID@example.com", password: "123456")
        )
        let user0o = try await auth.getUser(uid: uid0)
        let user0 = try XCTUnwrap(user0o)
        XCTAssertFalse(user0.disabled)

        let uid1 = try await auth.updateUser(uid: uid0, properties: .init(disabled: true))
        XCTAssertEqual(uid1, uid0)
        let user1o = try await auth.getUser(uid: uid1)
        let user1 = try XCTUnwrap(user1o)
        XCTAssertEqual(user1.uid, uid1)
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
        let uid0 = try await auth.createUser(user: create)
        let uid1 = try await auth.updateUser(uid: uid0, properties: properties)
        let usero = try await auth.getUser(uid: uid1)
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

    func testSetCustomClaims() async throws {
        let auth = try makeAuth()

        let uid = try await XCTAssertNoThrow {
            try await auth.createUser(user: UserToCreate(
                email: "testSetCustomClaims@example.com",
                password: "012345"
            ))
        }

        await XCTAssertNoThrow {
            try await auth.setCustomUserClaims(uid: uid, claims: [
                "key1": "value1",
                "key2": "value2",
            ])
        }

        let result = try await XCTUnwrap {
            try await auth.getUser(uid: uid)
        }
        XCTAssertEqual(result.customClaims["key1"], "value1")
        XCTAssertEqual(result.customClaims["key2"], "value2")
    }

    func testDeleteUser() async throws {
        let auth = try makeAuth()

        let uid = try await auth.createUser(user: UserToCreate(
            email: "testDeleteUser_\(#line)@example.com",
            password: "012345"
        ))
        let userBeforeRemoved = try await XCTAssertNoThrow { try await auth.getUser(uid: uid) }
        XCTAssertNotNil(userBeforeRemoved)

        await XCTAssertNoThrow {
            try await auth.deleteUser(uid: uid)
        }

        let userRemoved = try await XCTAssertNoThrow { try await auth.getUser(uid: uid) }
        XCTAssertNil(userRemoved)
    }
}
