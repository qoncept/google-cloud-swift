import AsyncHTTPClient
import Foundation
import GoogleCloudBase

public struct Bucket: Sendable {
    public let bucketName: String
    private let authorizedClient: AuthorizedClient

    init(name: String, authorizedClient: AuthorizedClient) {
        self.bucketName = name
        self.authorizedClient = authorizedClient
    }

    // INFO: https://cloud.google.com/storage/docs/json_api/v1/objects/list
    public func files(prefix: String) async throws -> [StorageFile] {
        return try await authorizedClient.get(
            path: "storage/v1/b/\(bucketName)/o",
            queryItems: [
                URLQueryItem(name: "autoPaginate", value: "false"),
                URLQueryItem(name: "delimiter", value: "/"),
                URLQueryItem(name: "prefix", value: prefix),
            ],
            responseType: ObjectsListResponse.self
        ).items ?? []
    }

    // INFO: https://cloud.google.com/storage/docs/json_api/v1/objects/delete
    public func delete(name: String) async throws {
        let name = Self.nameOnPath(name: name)
        try await authorizedClient.delete(
            path: "storage/v1/b/\(bucketName)/o" + (name.hasPrefix("/") ? name : "/" + name)
        )
    }

    public func recursiveDelete(prefix: String) async throws {
        let files = try await files(prefix: prefix)
        for file in files {
            try await delete(name: file.name)
        }
    }

    public func uploadSimple(name: String, media: Data, contentType: String? = nil) async throws -> StorageFile {
        return try await authorizedClient.post(
            path: "upload/storage/v1/b/\(bucketName)/o",
            headers: [
                "Content-Type": contentType ?? Mimetype.detect(name)
            ],
            queryItems: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "uploadType", value: "media"),
            ],
            payload: media,
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
