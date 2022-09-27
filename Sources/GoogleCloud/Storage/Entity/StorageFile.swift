import Foundation

/// INFO: https://cloud.google.com/storage/docs/json_api/v1/objects
/// varとletは↑のwritableかどうかに対応してるけど、意味はわかっていない
public struct StorageFile: Decodable {
    public init(name: String, bucket: String) {
        self.name = name
        self.bucket = bucket
    }

    public var name: String /// 直感的にはpath
    public let bucket: String /// バケット名
}
