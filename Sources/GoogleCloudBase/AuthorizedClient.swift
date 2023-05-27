import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import NIOHTTP1

private let sdkVersion = "0.0.1"
private let emulatorToken = "owner"

struct AuthorizedClientError: Error, CustomStringConvertible, LocalizedError {
    var message: String
    var description: String { message }
    var errorDescription: String? { message }
}

public struct AuthorizedClient: Sendable {
    public var baseURL: URL
    public var credentialStore: CredentialStore
    public var httpClient: AsyncHTTPClient.HTTPClient
    public var isEmulator: Bool
    private let logger: Logger = .init(label: "AuthorizedClient")

    public init(baseURL: URL, credentialStore: CredentialStore, httpClient: HTTPClient, isEmulator: Bool = false) {
        self.baseURL = baseURL
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.isEmulator = isEmulator
    }

    private func token() async throws -> String {
        if isEmulator {
            return emulatorToken
        }
        return try await credentialStore.accessToken()
    }

    public func get<Response: Decodable>(
        path: String,
        headers: HTTPHeaders = HTTPHeaders(),
        queryItems: [URLQueryItem] = [],
        responseType: Response.Type
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.concattingPath(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        let req = try HTTPClient.Request(
            url: components.url!,
            method: .GET,
            headers: try await mergedHeaders(headers)
        )
        logger.debug("GET \(req.url.absoluteString)")
        let res = try await httpClient.execute(
            request: req,
            deadline: .now() + .milliseconds(25000),
            logger: logger
        ).get()

        return try handleResponse(res: res)
    }

    public func post<Body: Encodable, Response: Decodable>(
        path: String,
        headers: HTTPHeaders = HTTPHeaders(),
        queryItems: [URLQueryItem] = [],
        payload: Body,
        responseType: Response.Type
    ) async throws -> Response {
        return try await post(
            path: path,
            headers: headers,
            queryItems: queryItems,
            payload: try JSONEncoder().encode(payload),
            responseType: responseType
        )
    }

    public func post<Response: Decodable>(
        path: String,
        headers: HTTPHeaders = HTTPHeaders(),
        queryItems: [URLQueryItem] = [],
        payload: Data,
        responseType: Response.Type
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.concattingPath(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var headers = try await mergedHeaders(headers)
        if !headers.contains(name: "Content-Length") {
            headers.add(name: "Content-Length", value: "\(payload.count)")
        }

        let req = try HTTPClient.Request(
            url: components.url!,
            method: .POST,
            headers: try await mergedHeaders(headers),
            body: .data(payload)
        )
        logger.debug("POST \(req.url.absoluteString)")
        let res = try await httpClient.execute(
            request: req,
            deadline: .now() + .milliseconds(25000),
            logger: logger
        ).get()

        return try handleResponse(res: res)
    }

    public func delete(
        path: String,
        headers: HTTPHeaders = HTTPHeaders()
    ) async throws {
        let req = try HTTPClient.Request(
            url: baseURL.concattingPath(path),
            method: .DELETE,
            headers: try await mergedHeaders(headers)
        )
        logger.debug("DELETE \(req.url.absoluteString)")
        let res = try await httpClient.execute(
            request: req,
            deadline: .now() + .milliseconds(25000),
            logger: logger
        ).get()

        return try handleResponse(res: res)
    }

    private func mergedHeaders(_ headers: HTTPHeaders) async throws -> HTTPHeaders {
        var headers = headers
        headers.add(contentsOf: [
            "X-Client-Version": "Swift/Admin/\(sdkVersion)",
            "Authorization": "Bearer \(try await token())",
        ])
        if !headers.contains(name: "Content-Type") {
            headers.add(name: "Content-Type", value: "application/json")
        }
        return headers
    }

    private func handleResponse<Response: Decodable>(res: HTTPClient.Response, responseType: Response.Type = Response.self) throws -> Response {
        guard let body = res.body else {
            throw AuthorizedClientError(message: "no body")
        }

//        print(String(buffer: body))

        if UInt(400)..<600 ~= res.status.code {
            let errorResponse: ErrorResponse
            do {
                errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: body)
            } catch {
                if let data = body.getData(at: body.readerIndex, length: body.readableBytes),
                   let string = String(data: data, encoding: .utf8) {
                    // 404のときなど、JSONでないレスポンスが返ることがある
                    throw ErrorResponse(error: .init(code: Int(res.status.code), message: string))
                }
                throw error
            }
            throw errorResponse
        }

        return try JSONDecoder().decode(Response.self, from: body)
    }

    private func handleResponse(res: HTTPClient.Response) throws {
        if UInt(400)..<600 ~= res.status.code {
            guard let body = res.body else {
                throw ErrorResponse(error: .init(code: Int(res.status.code), message: ""))
            }

            let errorResponse: ErrorResponse
            do {
                errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: body)
            } catch {
                if let data = body.getData(at: body.readerIndex, length: body.readableBytes),
                   let string = String(data: data, encoding: .utf8) {
                    // 404のときなど、JSONでないレスポンスが返ることがある
                    throw ErrorResponse(error: .init(code: Int(res.status.code), message: string))
                }
                throw error
            }
            throw errorResponse
        }
    }
}

public struct ErrorResponse: Decodable, Error, CustomStringConvertible, LocalizedError {
    public struct Error: Decodable {
        public var code: Int
        public var message: String
        public var status: String?
        public var errors: [[String: String]]?
    }
    public var error: Error
    public var description: String { "\(error.message)(\(error.code))" }
    public var errorDescription: String? { description }
}

extension URL {
    fileprivate func concattingPath(_ component: String) -> URL {
        if component.isEmpty || component == "/" { return self }
        return URL(string: absoluteString.addingSlashSuffix + component.choppingSlashPrefix) ?? self
    }
}
