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

    package struct EmptyResponse: Decodable {}

    package enum Payload {
        case none
        case json(any Encodable)
        case data(ByteBuffer)
    }

    package func execute<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        payload: Payload = .none,
        headers: HTTPHeaders = HTTPHeaders(),
        timeout: TimeAmount = .seconds(20),
        logger: Logger?,
        responseType: Response.Type = EmptyResponse.self
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
        case .data(let buffer):
            req.body = .bytes(buffer)
        }

        logger?.log(level: gcpClient.options.requestLogLevel, "\(req.method.rawValue) \(req.url)")
        let res = try await gcpClient.httpClient.execute(req, timeout: timeout, logger: logger)

        if responseType == EmptyResponse.self {
            return EmptyResponse() as! Response
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

//    package func post<Body: Encodable, Response: Decodable>(
//        path: String,
//        headers: HTTPHeaders = HTTPHeaders(),
//        queryItems: [URLQueryItem] = [],
//        payload: Body,
//        responseType: Response.Type
//    ) async throws -> Response {
//        return try await post(
//            path: path,
//            headers: headers,
//            queryItems: queryItems,
//            payload: try JSONEncoder().encode(payload),
//            responseType: responseType
//        )
//    }
//
//    package func post<Response: Decodable>(
//        path: String,
//        headers: HTTPHeaders = HTTPHeaders(),
//        queryItems: [URLQueryItem] = [],
//        payload: Data,
//        responseType: Response.Type
//    ) async throws -> Response {
//        var components = URLComponents(url: baseURL.concattingPath(path), resolvingAgainstBaseURL: false)!
//        components.queryItems = queryItems
//
//        var headers = try await mergedHeaders(headers)
//        if !headers.contains(name: "Content-Length") {
//            headers.add(name: "Content-Length", value: "\(payload.count)")
//        }
//
//        let req = try HTTPClient.Request(
//            url: components.url!,
//            method: .POST,
//            headers: try await mergedHeaders(headers),
//            body: .data(payload)
//        )
//        logger.debug("POST \(req.url.absoluteString)")
//        let res = try await send(request: req)
//
//        return try handleResponse(res: res)
//    }
//
//    package func delete(
//        path: String,
//        headers: HTTPHeaders = HTTPHeaders()
//    ) async throws {
//        let req = try HTTPClient.Request(
//            url: baseURL.concattingPath(path),
//            method: .DELETE,
//            headers: try await mergedHeaders(headers)
//        )
//        logger.debug("DELETE \(req.url.absoluteString)")
//        let res = try await send(request: req)
//        
//        return try handleResponse(res: res)
//    }

    private func mergedHeaders(_ headers: HTTPHeaders) async throws -> HTTPHeaders {
        var headers = headers
        headers.add(contentsOf: [
            "X-Client-Version": "Swift/Admin/\(sdkVersion)",
            "Authorization": "Bearer \(try await token())",
        ])
        return headers
    }

//    private func handleResponse<Response: Decodable>(res: HTTPClientResponse, responseType: Response.Type = Response.self) async throws -> Response {
//        let body = try await res.body.collect(upTo: .max)
//
//        if UInt(400)..<600 ~= res.status.code {
//            let errorResponse: ErrorResponse
//            do {
//                errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: body)
//            } catch {
//                if let data = body.getData(at: body.readerIndex, length: body.readableBytes),
//                   let string = String(data: data, encoding: .utf8) {
//                    // 404のときなど、JSONでないレスポンスが返ることがある
//                    throw ErrorResponse(error: .init(code: Int(res.status.code), message: string))
//                }
//                throw error
//            }
//            throw errorResponse
//        }
//
//        return try JSONDecoder().decode(Response.self, from: body)
//    }
//
//    private func handleResponse(res: HTTPClientResponse) async throws {
//        if UInt(400)..<600 ~= res.status.code {
//            let body = try await res.body.collect(upTo: .max)
//
//            let errorResponse: ErrorResponse
//            do {
//                errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: body)
//            } catch {
//                if let data = body.getData(at: body.readerIndex, length: body.readableBytes),
//                   let string = String(data: data, encoding: .utf8) {
//                    // 404のときなど、JSONでないレスポンスが返ることがある
//                    throw ErrorResponse(error: .init(code: Int(res.status.code), message: string))
//                }
//                throw error
//            }
//            throw errorResponse
//        }
//    }
}

extension URL {
    fileprivate func concattingPath(_ component: String) -> URL {
        if component.isEmpty || component == "/" { return self }
        return URL(string: absoluteString.addingSlashSuffix + component.choppingSlashPrefix) ?? self
    }
}
