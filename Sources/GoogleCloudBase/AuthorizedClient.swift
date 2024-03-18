import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import NIOHTTP1

private let sdkVersion = "1.0.0"

package struct AuthorizedClient: Sendable {
    package var baseURL: URL
    package var gcpClient: GCPClient
    package var credential: any Credential

    package init(
        baseURL: URL,
        gcpClient: GCPClient,
        credential: (any Credential)? = nil
    ) {
        self.baseURL = baseURL
        self.gcpClient = gcpClient
        self.credential = credential ?? gcpClient.credential
    }

    private func token() async throws -> AccessToken {
        return try await credential.getAccessToken()
    }

    package struct Empty: Codable {}

    package enum Payload<JSONType: Encodable> {
        case none
        case json(JSONType)
        case raw(ByteBuffer)
    }

    package func execute<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        payload: Payload<some Any> = Payload<Empty>.none,
        headers: HTTPHeaders = HTTPHeaders(),
        timeout: TimeAmount = .seconds(20),
        logger: Logger?,
        responseType: Response.Type = Empty.self
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.concattingPath(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var req = HTTPClientRequest(url: components.url!.absoluteString)
        req.method = method
        req.headers = try await mergedHeaders(headers)

        switch payload {
        case .none: break
        case .json(let encodable):
            req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(encodable, allocator: ByteBufferAllocator()))
            if !req.headers.contains(name: "Content-Type") {
                req.headers.add(name: "Content-Type", value: "application/json")
            }
        case .raw(let buffer):
            req.body = .bytes(buffer)
        }

        logger?.log(level: gcpClient.options.requestLogLevel, "\(req.method.rawValue) \(req.url)")
        let res = try await gcpClient.httpClient.execute(req, timeout: timeout, logger: logger)

        if responseType == Empty.self {
            return Empty() as! Response
        } else {
            let resBody = try await res.body.collect(upTo: .max)

            if UInt(400)..<600 ~= res.status.code {
                let errorResponse: ErrorResponse
                do {
                    errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: resBody)
                } catch {
                    if let data = resBody.getData(at: resBody.readerIndex, length: resBody.readableBytes),
                       let string = String(data: data, encoding: .utf8) {
                        // 404のときなど、JSONでないレスポンスが返ることがある
                        throw ErrorResponse(error: .init(code: Int(res.status.code), message: string))
                    }
                    throw error
                }
                throw errorResponse
            }

            return try JSONDecoder().decode(Response.self, from: resBody)
        }
    }

    private func mergedHeaders(_ headers: HTTPHeaders) async throws -> HTTPHeaders {
        var headers = headers
        headers.add(contentsOf: [
            "X-Client-Version": "Swift/Admin/\(sdkVersion)",
            "Authorization": "Bearer \(try await token())",
        ])
        return headers
    }
}

extension URL {
    fileprivate func concattingPath(_ component: String) -> URL {
        if component.isEmpty || component == "/" { return self }
        return URL(string: absoluteString.addingSlashSuffix + component.choppingSlashPrefix) ?? self
    }
}

extension AuthorizedClient.Payload where JSONType == AuthorizedClient.Empty {
    package static func data(_ data: Data) -> Self {
        return .raw(ByteBuffer(data: data))
    }

    package static func buffer(_ buffer: ByteBuffer) -> Self {
        return .raw(buffer)
    }
}
