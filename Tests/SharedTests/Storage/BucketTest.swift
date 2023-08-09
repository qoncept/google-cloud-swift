@testable import GoogleCloud
import NIOPosix
import XCTest

final class BucketTest: XCTestCase {
    private static let client = AsyncHTTPClient.HTTPClient(eventLoopGroupProvider: .singleton)

    override class func setUp() {
        super.setUp()
        initLogger()
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
        try XCTSkipIf(ProcessInfo.processInfo.environment[storageEmulatorHostEnvVar] == nil, "BucketTest uses Cloud Storage Emulator.")
    }

    private func makeBucket() -> Bucket {
        Storage(
            credentialStore: CredentialStore(credential: MockCredential()),
            client: Self.client
        )
            .bucket(name: "test-bucket")
    }

    func testFiles() async throws {
        let bucket = makeBucket()

        let response = try await bucket.files(prefix: "testFiles/")
        XCTAssertEqual(Set(response.map(\.name)), ["testFiles/bar.png", "testFiles/baz.jpg"])
    }

    func testUpload() async throws {
        let bucket = makeBucket()

        let name = "testUpload/foo??bar.txt"
        let data = Data(name.utf8)
        let response = try await bucket.uploadSimple(name: name, media: data)
        XCTAssertEqual(response.name, name)
    }

    func testDelete() async throws {
        let bucket = makeBucket()

        let names = [
            "testDelete/foo??bar.txt",
            "testDelete/foo/bar.txt",
            "testDelete/foo&bar().txt",
        ]
        for name in names {
            let data = Data(name.utf8)
            _ = try await bucket.uploadSimple(name: name, media: data)
            let files = try await bucket.files(prefix: name)
            XCTAssertFalse(files.isEmpty)

            try await bucket.delete(name: name)
            let filesAfter = try await bucket.files(prefix: name)
            XCTAssertTrue(filesAfter.isEmpty)
        }
    }
}
