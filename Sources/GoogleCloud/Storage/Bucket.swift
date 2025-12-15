import AsyncHTTPClient
import Logging
import Foundation
import GoogleCloudBase

public struct Bucket: Sendable {
    public let bucketName: String
    private let authorizedClient: AuthorizedClient

    internal init(name: String, authorizedClient: AuthorizedClient) {
        self.bucketName = name
        self.authorizedClient = authorizedClient
    }

    // INFO: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/list
    public func files(
        prefix: String,
        logger: Logger? = nil
    ) async throws -> [StorageFile] {
        return try await authorizedClient.execute(
            method: .GET,
            path: "storage/v1/b/\(bucketName)/o",
            queryItems: [
                URLQueryItem(name: "autoPaginate", value: "false"),
                URLQueryItem(name: "delimiter", value: "/"),
                URLQueryItem(name: "prefix", value: prefix),
            ],
            logger: logger,
            responseType: ObjectsListResponse.self
        ).items ?? []
    }

    // INFO: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/move
    @discardableResult
    public func move(
        src: String,
        dst: String,
        logger: Logger? = nil
    ) async throws -> StorageFile {
        return try await authorizedClient.execute(
            method: .POST,
            path: "storage/v1/b/\(bucketName)/o/\(src.choppingSlashPrefix)/moveTo/o/\(dst.choppingSlashPrefix)",
            logger: logger,
            responseType: StorageFile.self
        )
    }

    // INFO: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/delete
    public func delete(
        name: String,
        logger: Logger? = nil
    ) async throws {
        let name = Self.nameOnPath(name: name)
        _ = try await authorizedClient.execute(
            method: .DELETE,
            path: "storage/v1/b/\(bucketName)/o/\(name.choppingSlashPrefix)",
            logger: logger
        )
    }

    public func recursiveDelete(prefix: String) async throws {
        let files = try await files(prefix: prefix)
        for file in files {
            try await delete(name: file.name)
        }
    }

    public func uploadSimple(
        name: String,
        media: Data,
        contentType: String? = nil,
        logger: Logger? = nil
    ) async throws -> StorageFile {
        return try await authorizedClient.execute(
            method: .POST,
            path: "upload/storage/v1/b/\(bucketName)/o",
            queryItems: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "uploadType", value: "media"),
            ],
            payload: .data(media),
            headers: [
                "Content-Type": contentType ?? Mimetype.detect(name)
            ],
            logger: logger,
            responseType: StorageFile.self
        )
    }

    // INFO: https://cloud.google.com/storage/docs/request-endpoints#encoding
    static func nameOnPath(name: String) -> String {
        let targets = CharacterSet(charactersIn: " !#$&'()*+,/:;=?@[]")
        return name.addingPercentEncoding(withAllowedCharacters: targets.inverted)!
    }
}

struct ObjectsListResponse: Decodable {
    var kind: String
    var nextPageToken: String?
    var items: [StorageFile]?
    var prefixes: [String]?
}
