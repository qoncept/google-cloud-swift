import AsyncHTTPClient
import GoogleCloudBase
import Foundation
import JWTKit
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

actor HTTPKeySource {
    private let client: HTTPClient
    private let clock: Clock
    private var willRefreshKeys: (() -> ())?
    func setWillRefreshKeys(_ c: (() -> ())?) {
        willRefreshKeys = c
    }

    init(client: HTTPClient, clock: Clock = .default) {
        self.client = client
        self.clock = clock
    }

    private var cachedKeys: JWTSigners?
    private var expiryTime: Date = .init(timeIntervalSince1970: 0)
    private var refreshingTask: Task<Void, Error>?

    func publicKeys() async throws -> JWTSigners {
        if cachedKeys == nil || hasExpired {
            try await refreshKeys()
        }
        return cachedKeys!
    }

    func withPublicKeys<T>(_ run: @Sendable (JWTSigners) throws -> T) async throws -> T {
        let signers = try await publicKeys()
        return try run(signers)
    }

    private var hasExpired: Bool {
        expiryTime < clock.now()
    }

    private func refreshKeys() async throws {
        if let refreshingTask = refreshingTask {
            return try await refreshingTask.value
        }

        let task = Task {
            willRefreshKeys?()
            let res = try await client.execute(url: publicKeysURL).get()
            
            let maxAge = try Self.findMaxAge(res: res)
            expiryTime = clock.now().addingTimeInterval(maxAge)

            guard let body = res.body,
                  let bodyDictionary = try? JSONDecoder().decode([String: String].self, from: body),
                  !bodyDictionary.isEmpty
            else {
                throw HTTPKeySourceError.invalidBody
            }
            
            let newSigners = JWTSigners()
            for (id, pem) in bodyDictionary {
                //            print("id:", id, "pem:", pem)
                newSigners.use(.rs256(key: try .certificate(pem: pem)), kid: JWKIdentifier(string: id))
            }
            cachedKeys = newSigners
        }

        refreshingTask = task
        defer { refreshingTask = nil }

        return try await task.value
    }

    private static func findMaxAge(res: HTTPClient.Response) throws -> TimeInterval {
        guard let cacheControl = res.headers.first(name: "cache-control") else {
            throw HTTPKeySourceError.noCacheControl
        }

        for value in cacheControl.split(separator: ",") {
            let value = value.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("max-age="), let eqIndex = value.firstIndex(of: "=") {
                let secondsString = value.suffix(from: value.index(after: eqIndex))
//                print("secondsString", secondsString)
                if let duration = TimeInterval(secondsString) {
                    return duration
                }
            }
        }

        throw HTTPKeySourceError.noMaxAge
    }
}
