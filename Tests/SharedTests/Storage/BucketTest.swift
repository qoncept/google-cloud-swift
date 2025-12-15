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

    @Test(.disabled("fake-gcs-server doesn't support 'move'."))
    func move() async throws {
        let bucket = makeBucket()

        let srcName = "testMove/src/Foo.txt"
        let dstName = "testMove/dst/Foo_renamed.txt"
        _ = try await bucket.uploadSimple(name: srcName, media: Data(#function.utf8))

        let filesBefore = try await bucket.files(prefix: srcName)
        #expect(!filesBefore.isEmpty)

        let movedFile = try await bucket.move(src: srcName, dst: dstName)
        #expect(movedFile.name == dstName)

        let filesAfterSrc = try await bucket.files(prefix: srcName)
        #expect(filesAfterSrc.isEmpty)
        let filesAfterDst = try await bucket.files(prefix: dstName)
        #expect(!filesAfterDst.isEmpty)
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
