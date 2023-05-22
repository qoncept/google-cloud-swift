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
                email: "test@example.com",
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
                email: "test2@example.com",
                password: "012345"
            ))
        }

        let result = try await XCTUnwrap {
            try await auth.getUser(uid: uid)
        }
        XCTAssertEqual(result.uid, uid)
        XCTAssertEqual(result.email, "test2@example.com")
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
            email: "test3@example.com",
            password: "012345"
        ))

        let user = try await auth.getUser(email: "test3@example.com")
        XCTAssertNotNil(user)
    }

    func testGetUserEmailNotFound() async throws {
        let auth = try makeAuth()

        let user = try await auth.getUser(email: "xxxxxx@example.com")
        XCTAssertNil(user)
    }

    func testSetCustomClaims() async throws {
        let auth = try makeAuth()

        let uid = try await XCTAssertNoThrow {
            try await auth.createUser(user: UserToCreate(
                email: "test3@example.com",
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
            email: "\(#line)@example.com",
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
