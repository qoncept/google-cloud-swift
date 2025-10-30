import Foundation
@testable import GoogleCloud
import NIOPosix
import Testing

@Suite(
    .gcpClient,
    .enabled(if: ProcessInfo.processInfo.environment[storageEmulatorHostEnvVar] != nil, "BucketTest uses Cloud Storage Emulator.")
) struct BucketTest: ~Copyable {
    private func makeBucket() -> Bucket {
        Storage(client: .mockCredentialClient)
            .bucket(name: "test-bucket")
    }

    @Test func files() async throws {
        let bucket = makeBucket()

        let response = try await bucket.files(prefix: "testFiles/")
        #expect(Set(response.map(\.name)) == ["testFiles/bar.png", "testFiles/baz.jpg"])
    }

    @Test func upload() async throws {
        let bucket = makeBucket()

        let name = "testUpload/foo??bar.txt"
        let data = Data(name.utf8)
        let response = try await bucket.uploadSimple(name: name, media: data)
        #expect(response.name == name)
    }

    @Test func delete() async throws {
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
            #expect(!files.isEmpty)

            try await bucket.delete(name: name)
            let filesAfter = try await bucket.files(prefix: name)
            #expect(filesAfter.isEmpty)
        }
    }
}
