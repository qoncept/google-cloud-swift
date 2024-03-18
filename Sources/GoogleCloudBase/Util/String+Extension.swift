import Foundation

extension String {
    package var choppingSlashPrefix: String {
        if hasPrefix("/") {
            var ret = self
            ret.removeFirst()
            return ret
        } else {
            return self
        }
    }

    package var addingSlashSuffix: String {
        if hasSuffix("/") {
            return self
        } else {
            return self + "/"
        }
    }
}
