import Foundation
import Crypto

public struct HexEncodingOptions: OptionSet {
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int
    public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
}

extension Data {
    public func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef"
        let utf8Digits = Array(hexDigits.utf8)
        return String(unsafeUninitializedCapacity: 2 * self.count) { (ptr) -> Int in
            var p = ptr.baseAddress!
            for byte in self {
                p[0] = utf8Digits[Int(byte / 16)]
                p[1] = utf8Digits[Int(byte % 16)]
                p += 2
            }
            return 2 * self.count
        }
    }
}

extension Digest {
    public func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef"
        let utf8Digits = Array(hexDigits.utf8)
        return String(unsafeUninitializedCapacity: 2 * Self.byteCount) { (ptr) -> Int in
            var p = ptr.baseAddress!
            for byte in self.makeIterator() {
                p[0] = utf8Digits[Int(byte / 16)]
                p[1] = utf8Digits[Int(byte % 16)]
                p += 2
            }
            return 2 * Self.byteCount
        }
    }
}
