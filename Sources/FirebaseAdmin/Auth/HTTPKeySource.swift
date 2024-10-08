import AsyncHTTPClient
import GoogleCloudBase
import Foundation
import JWTKit
import NIOConcurrencyHelpers
import NIOFoundationCompat

/// Cache-Control ヘッダーに含まれる max-age の値に応じて公開鍵を更新する必要がある
private let publicKeysURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

enum HTTPKeySourceError: Error, LocalizedError {
    case noCacheControl
    case noMaxAge
    case invalidBody

    var errorDescription: String? {
        switch self {
        case .noCacheControl:
            return "Could not find expiry time from HTTP headers"
        case .noMaxAge:
            return "Could not find expiry time from HTTP headers"
        case .invalidBody:
            return "Could not decode body"
        }
    }
}

struct HTTPKeySource {
    private var client: HTTPClient
    private var rotating: AutoRotatingValue<JWTKeyCollection>

    private var willRefreshKeys: NIOLockedValueBox<(@Sendable () -> ())?>
    func setWillRefreshKeys(_ c: (@Sendable () -> ())?) {
        willRefreshKeys.withLockedValue { value in
            value = c
        }
    }

    init(client: HTTPClient, clock: some Clock<Duration> = .continuous) {
        self.client = client
        let willRefreshKeys = NIOLockedValueBox<(@Sendable () -> ())?>(nil)
        self.willRefreshKeys = willRefreshKeys
        self.rotating = AutoRotatingValue(clock: clock) {
            willRefreshKeys.withLockedValue { $0?() }
            let res = try await client.execute(HTTPClientRequest(url: publicKeysURL), timeout: .seconds(10))
            let body = try await res.body.collect(upTo: .max)
            guard let bodyDictionary = try? JSONDecoder().decode([String: String].self, from: body),
                  !bodyDictionary.isEmpty
            else {
                throw HTTPKeySourceError.invalidBody
            }

            let newSigners = JWTKeyCollection()
            for (id, pem) in bodyDictionary {
                //            print("id:", id, "pem:", pem)
                await newSigners.add(
                    rsa: try Insecure.RSA.PublicKey(certificatePEM: pem),
                    digestAlgorithm: .sha256,
                    kid: JWKIdentifier(string: id)
                )
            }

            let maxAge = try Self.findMaxAge(res: res)
            return (newSigners, maxAge)
        }
    }

    func publicKeys() async throws -> JWTKeyCollection {
        return try await rotating.getValue()
    }

    private static func findMaxAge(res: HTTPClientResponse) throws -> Duration {
        guard let cacheControl = res.headers.first(name: "cache-control") else {
            throw HTTPKeySourceError.noCacheControl
        }

        for value in cacheControl.split(separator: ",") {
            let value = value.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("max-age="), let eqIndex = value.firstIndex(of: "=") {
                let secondsString = value.suffix(from: value.index(after: eqIndex))
//                print("secondsString", secondsString)
                if let duration = Double(secondsString) {
                    return .seconds(duration)
                }
            }
        }

        throw HTTPKeySourceError.noMaxAge
    }
}
