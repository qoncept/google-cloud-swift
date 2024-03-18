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

package struct AuthorizedClient: Sendable {
    package var baseURL: URL
    package var credential: any Credential
    package var httpClient: AsyncHTTPClient.HTTPClient
    private let logger: Logger = .init(label: "AuthorizedClient")

    package init(
        baseURL: URL,
        credential: any Credential,
        httpClient: HTTPClient
    ) {
        self.baseURL = baseURL
        self.credential = credential
        self.httpClient = httpClient
    }

    private func token() async throws -> AccessToken {
        return try await credential.getAccessToken()
    }

    package func get<Response: Decodable>(
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
        let res = try await send(request: req)

        return try handleResponse(res: res)
    }

    package func post<Body: Encodable, Response: Decodable>(
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

    package func post<Response: Decodable>(
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
        let res = try await send(request: req)

        return try handleResponse(res: res)
    }

    package func delete(
        path: String,
        headers: HTTPHeaders = HTTPHeaders()
    ) async throws {
        let req = try HTTPClient.Request(
            url: baseURL.concattingPath(path),
            method: .DELETE,
            headers: try await mergedHeaders(headers)
        )
        logger.debug("DELETE \(req.url.absoluteString)")
        let res = try await send(request: req)
        
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

    private func send(request: HTTPClient.Request) async throws -> HTTPClient.Response {
        let accumulator = ResponseAccumulator(request: request)
        let task = httpClient.execute(
            request: request,
            delegate: accumulator,
            deadline: .now() + .seconds(25),
            logger: logger
        )
        return try await withTaskCancellationHandler {
            try await task.get()
        } onCancel: {
            task.cancel()
        }
    }

    private func handleResponse<Response: Decodable>(res: HTTPClient.Response, responseType: Response.Type = Response.self) throws -> Response {
        guard let body = res.body else {
            throw AuthorizedClientError(message: "no body")
        }

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

extension URL {
    fileprivate func concattingPath(_ component: String) -> URL {
        if component.isEmpty || component == "/" { return self }
        return URL(string: absoluteString.addingSlashSuffix + component.choppingSlashPrefix) ?? self
    }
}
