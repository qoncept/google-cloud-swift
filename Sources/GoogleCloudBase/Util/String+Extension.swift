import Foundation

extension String {
    public var choppingSlashPrefix: String {
        if hasPrefix("/") {
            var ret = self
            ret.removeFirst()
            return ret
        } else {
            return self
        }
    }

    public var addingSlashSuffix: String {
        if hasSuffix("/") {
            return self
        } else {
            return self + "/"
        }
    }
}
