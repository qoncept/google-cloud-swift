@testable import FirebaseAdmin
import NIOPosix
import XCTest
import Logging

private let testingProjectID = "testing-project-id"

final class ListUserTest: XCTestCase {
    private static let client = try! GCPClient(credentialFactory: .custom { _ in
        MockCredential()
    })

    private static var emulatorURL: URL? = Auth.emulatorBaseURL()

    override class func setUp() {
        super.setUp()
        initLogger()

        if let url = Self.emulatorURL {
            let endpoint = Auth.emulatorAPIBaseURL(url: url)!.appendingPathComponent("projects/\(testingProjectID)/accounts")
            do {
                let request = try HTTPClient.Request(url: endpoint, method: .DELETE)
                _ = try client.httpClient.execute(request: request).wait()
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
        try XCTSkipIf(Self.emulatorURL == nil, "ListUserTest uses Firebase Auth Emulator.")
    }

    private func makeAuth() throws -> Auth {
        try Auth(
            client: Self.client,
            projectID: testingProjectID
        )
    }

    func testListUser() async throws {
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
                XCTAssertEqual(result.users.count, 10)
            } else {
                XCTAssertEqual(result.users.count, 20)
            }
            for user in result.users {
                let index = Int(user.displayName!)!
                XCTAssertEqual(user.email, "\(index)@firebase.com")
                founds[index] = user
            }
            guard let nextPageToken = result.nextPageToken else {
                break
            }
            pageToken = nextPageToken
        }

        XCTAssertEqual(callCount, 5)

        let foundIDs = Set(founds.keys)
        XCTAssertEqual(foundIDs, Set(0..<90))
    }
}
