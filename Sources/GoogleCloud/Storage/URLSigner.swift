import Crypto
import Foundation
import GoogleCloudBase
import NIOHTTP1

// INFO: https://github.com/googleapis/nodejs-storage/blob/main/src/signer.ts

private let pathStyledHost = URL(string: "https://storage.googleapis.com")!
private let sevenDays: TimeInterval = 604800
private let stampFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
        .withYear, .withMonth, .withDay,
    ]
    return f
}()
private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
        .withYear, .withMonth, .withDay,
        .withTime, .withTimeZone,
    ]
    return f
}()

struct URLSignerError: Error, LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

struct URLSigner {
    let authorizedClient: AuthorizedClient
    let file: StorageFile

    enum SigningVersion {
        case v4
    }

    func sign(config: SignerGetSignedURLConfig) async throws -> URL {
        guard (0...sevenDays).contains(config.expires) else {
            throw URLSignerError(message: "expiration must be in 0...\(sevenDays)")
        }
        let accessibleAt = config.accessibleAt ?? Date()

        let customHost: URL?
        if let cname = config.cname {
            customHost = cname
        } else if config.virtualHostedStyle == true {
            customHost = URL(string: "https://\(file.bucket).storage.googleapis.com")!
        } else {
            customHost = nil
        }

        let query: [URLQueryItem]
        switch config.version {
        case .v4:
            query = try await signedURLv4(
                config: config,
                accessibleAt: accessibleAt,
                customHost: customHost
            )
        }

        guard var components = URLComponents(url: customHost ?? pathStyledHost, resolvingAgainstBaseURL: false) else {
            throw URLSignerError(message: "invalid host")
        }
        components.path = resourcePath(hasCname: config.cname != nil)
        components.queryItems = query
        components.queryItems?.append(contentsOf: config.queryParams ?? [])
        guard let signedURL = components.url else {
            throw URLSignerError(message: "some url parameters wrong")
        }
        return signedURL
    }

    private func signedURLv4(
        config: SignerGetSignedURLConfig,
        accessibleAt: Date,
        customHost: URL?
    ) async throws -> [URLQueryItem] {
        var extensionHeaders = config.extensionHeaders ?? .init()
        let fqdn = config.cname ?? pathStyledHost
        extensionHeaders.replaceOrAdd(name: "host", value: fqdn.host ?? "")
        if let md5 = config.contentMD5 {
            extensionHeaders.replaceOrAdd(name: "content-md5", value: md5)
        }
        if let contentType = config.contentType {
            extensionHeaders.replaceOrAdd(name: "content-type", value: contentType)
        }

        let contentSHA256: String?
        if let sha256Header = config.extensionHeaders?.first(name: "x-goog-content-sha256") {
            guard sha256Header.count == 40,
                  sha256Header.trimmingCharacters(in: .alphanumerics).isEmpty
            else {
                throw URLSignerError(message: "The header X-Goog-Content-SHA256 must be a hexadecimal string.")
            }
            contentSHA256 = sha256Header
        } else {
            contentSHA256 = nil
        }

        let signedHeaders = extensionHeaders.map { (name: String, value: String) in
            name.lowercased()
        }
            .sorted()
            .joined(separator: ";")

        let datestamp = stampFormatter.string(from: accessibleAt)
        let credentialScope = "\(datestamp)/auto/storage/goog4_request"

        let credential = authorizedClient.credentialStore.compilersafeCredential
        guard let credential = credential as? RichCredential else {
            throw URLSignerError(message: "\(type(of: credential)) does not support signing.")
        }
        let dateISO = isoFormatter.string(from: accessibleAt)

        let queryParams: [URLQueryItem] = [
            URLQueryItem(name: "X-Goog-Algorithm", value: "GOOG4-RSA-SHA256"),
            URLQueryItem(name: "X-Goog-Credential", value: "\(credential.clientEmail)/\(credentialScope)"),
            URLQueryItem(name: "X-Goog-Date", value: dateISO),
            URLQueryItem(name: "X-Goog-Expires", value: String(Int(config.expires))),
            URLQueryItem(name: "X-Goog-SignedHeaders", value: signedHeaders),
        ] + (config.queryParams ?? [])

        let canonicalRequest: String = [
            config.method.rawValue,
            resourcePath(hasCname: config.cname != nil),
            try canonicalize(queryParams: queryParams),
            canonicalize(headers: extensionHeaders),
            signedHeaders,
            contentSHA256 ?? "UNSIGNED-PAYLOAD",
        ].joined(separator: "\n")

        let hash = SHA256.hash(data: Data(canonicalRequest.utf8))
            .hexEncodedString()

        let blobToSign = [
            "GOOG4-RSA-SHA256",
            dateISO,
            credentialScope,
            hash,
        ].joined(separator: "\n")

//        print("StringToSign:", blobToSign)
//        print("CanonicalRequest:", canonicalRequest)

        let signature = try await credential.sign(data: Data(blobToSign.utf8))

        return queryParams + CollectionOfOne(
            URLQueryItem(name: "X-Goog-Signature", value: signature.hexEncodedString())
        )
    }

    private func resourcePath(hasCname: Bool) -> String {
        let pathWithS: String
        if file.name.starts(with: "/") {
            pathWithS = file.name
        } else {
            pathWithS = "/" + file.name
        }

        if hasCname {
            return pathWithS
        }
        return "/\(file.bucket)\(pathWithS)"
    }
}

private let whitespaceRegex = try! NSRegularExpression(pattern: #"\s{2,}"#, options: [])

private func canonicalize(headers: HTTPHeaders) -> String {
    let sortedKeys = Set(headers.map { $0.name.lowercased() })
        .sorted()
    return sortedKeys
        .map { key in
            let values = headers[canonicalForm: key]
            let canonicalValue = values.map({ value in
                let v = String(value)
                return whitespaceRegex.stringByReplacingMatches(in: v, options: [], range: NSRange(0..<v.count), withTemplate: " ")
            }).joined(separator: ",")
            return "\(key):\(canonicalValue)\n"
        }
        .joined()
}

private func canonicalize(queryParams: [URLQueryItem]) throws -> String {
    let set = CharacterSet.alphanumerics.union(.init(charactersIn: "~-._"))
    return queryParams.map { item in
        (
            key: item.name.addingPercentEncoding(withAllowedCharacters: set)!,
            value: item.value.map { $0.addingPercentEncoding(withAllowedCharacters: set)! }
        )
    }
    .sorted { $0.key < $1.key }
    .map { "\($0.key)=\($0.value ?? "")" }
    .joined(separator: "&")
}

public struct SignerGetSignedURLConfig {
    public init(method: HTTPMethod = .GET, expires: TimeInterval, accessibleAt: Date? = nil, virtualHostedStyle: Bool? = nil, cname: URL? = nil, extensionHeaders: HTTPHeaders? = nil, queryParams: [URLQueryItem]? = nil, contentMD5: String? = nil, contentType: String? = nil) {
        self.method = method
        self.expires = expires
        self.accessibleAt = accessibleAt
        self.virtualHostedStyle = virtualHostedStyle
        self.cname = cname
        self.extensionHeaders = extensionHeaders
        self.queryParams = queryParams
        self.contentMD5 = contentMD5
        self.contentType = contentType
    }

    public var method: HTTPMethod = .GET
    public var expires: TimeInterval
    public var accessibleAt: Date?
    public var virtualHostedStyle: Bool?
    let version = URLSigner.SigningVersion.v4
    public var cname: URL?
    public var extensionHeaders: HTTPHeaders?
    public var queryParams: [URLQueryItem]?
    public var contentMD5: String?
    public var contentType: String?
}
