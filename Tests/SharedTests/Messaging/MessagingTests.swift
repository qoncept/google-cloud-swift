import AsyncHTTPClient
@testable import FirebaseAdmin
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOConcurrencyHelpers
import Testing

@Suite struct MessagingTests {
    @Test func encodesTargetsAndPayload() throws {
        let targets: [(Message.Target, String)] = [(.token("device"), "token"), (.topic("news"), "topic"), (.condition("'news' in topics"), "condition")]
        for (target, key) in targets {
            let message = Message(target: target, notification: .init(title: "Title", body: "Body", image: URL(string: "https://example.com/image.png")!),
                                  data: ["payload": "{\"id\":1}"], android: .init(priority: .high, ttl: "120s"))
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any])
            #expect(json[key] != nil)
            #expect(["token", "topic", "condition"].filter { json[$0] != nil }.count == 1)
            #expect((json["notification"] as? [String: String]) == ["title": "Title", "body": "Body", "image": "https://example.com/image.png"])
            #expect((json["data"] as? [String: String]) == ["payload": "{\"id\":1}"])
            #expect((json["android"] as? [String: String]) == ["priority": "HIGH", "ttl": "120s"])
        }
    }

    @Test func identifiesOnlyFCMUnregistered() throws {
        let cases = [
            (#"{"error":{"code":404,"message":"gone","status":"NOT_FOUND","details":[{"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[]},{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}"#, true),
            (#"{"error":{"code":404,"message":"gone","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"INVALID_ARGUMENT"}]}}"#, false),
            (#"{"error":{"code":404,"message":"gone","details":[{"@type":"other","errorCode":"UNREGISTERED"}]}}"#, false),
        ]
        for (body, expected) in cases {
            let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(body.utf8))
            let error = MessagingError(response)
            #expect(error.statusCode == 404)
            #expect(error.isUnregistered == expected)
        }
    }

    @Test func preservesAndDecodesErrorDetails() throws {
        struct BadRequest: Decodable {
            struct Violation: Decodable { let field: String }
            let fieldViolations: [Violation]
        }
        let body = #"{"error":{"code":400,"message":"invalid","details":[{"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[{"field":"message.data"}]},{"@type":"example.com/unknown","nested":{"enabled":true,"values":[null,42]}}]}}"#
        let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(body.utf8))
        let details = try #require(response.error.details)
        #expect(try details[0].decode(BadRequest.self).fieldViolations.first?.field == "message.data")
        let encoded = try JSONEncoder().encode(details[1])
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let nested = try #require(object["nested"] as? [String: Any])
        #expect(nested["enabled"] as? Bool == true)
        #expect((nested["values"] as? [Any])?.count == 2)
    }

    @Test func sendsAuthenticatedRequestAndPropagatesErrors() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let captured = NIOLockedValueBox<[CapturedRequest]>([])
        let channel = try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(FCMTestHandler(captured: captured))
                }
            }
            .bind(host: "127.0.0.1", port: 0).get()
        do {
            let port = try #require(channel.localAddress?.port)
            let client = try GCPClient(credentialFactory: .custom { _ in TestCredential() })
            do {
                let messaging = try Messaging(client: client, projectID: "test-project", baseURL: URL(string: "http://127.0.0.1:\(port)/v1")!)
                let message = Message(target: .token("device"), notification: .init(title: "Title"))
                #expect(try await messaging.send(message, validateOnly: true) == "projects/test-project/messages/123")
                do {
                    _ = try await messaging.send(message)
                    Issue.record("Expected an FCM error")
                } catch let error as MessagingError {
                    #expect(error.statusCode == 404)
                    #expect(error.headers.first(name: "Retry-After") == "120")
                    #expect(error.fcmErrorCode == "UNREGISTERED")
                    #expect(error.isUnregistered)
                    #expect(error.message == "gone")
                }
                let requests = captured.withLockedValue { $0 }
                #expect(requests.count == 2)
                let first = try #require(requests.first)
                #expect(first.path == "/v1/projects/test-project/messages:send")
                #expect(first.method == .POST)
                #expect(first.authorization == "Bearer test-access-token")
                #expect(first.contentType == "application/json")
                let json = try #require(JSONSerialization.jsonObject(with: first.body) as? [String: Any])
                #expect(json["validate_only"] as? Bool == true)
                #expect((json["message"] as? [String: Any])?["token"] as? String == "device")
                try await client.shutdown()
            } catch {
                try? await client.shutdown()
                throw error
            }
            try await channel.close().get()
            try await group.shutdownGracefully()
        } catch {
            try? await channel.close().get()
            try? await group.shutdownGracefully()
            throw error
        }
    }
}

private struct TestCredential: Credential {
    func getAccessToken() async throws -> AccessToken { AccessToken(rawValue: "test-access-token") }
}

private struct CapturedRequest: Sendable {
    var path: String
    var method: HTTPMethod
    var authorization: String?
    var contentType: String?
    var body: Data
}

private final class FCMTestHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    let captured: NIOLockedValueBox<[CapturedRequest]>
    var request: CapturedRequest?
    init(captured: NIOLockedValueBox<[CapturedRequest]>) { self.captured = captured }
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            request = CapturedRequest(path: head.uri, method: head.method, authorization: head.headers.first(name: "Authorization"),
                                      contentType: head.headers.first(name: "Content-Type"), body: Data())
        case .body(var buffer):
            request?.body.append(contentsOf: buffer.readBytes(length: buffer.readableBytes) ?? [])
        case .end:
            guard let request else { return }
            let count = captured.withLockedValue { requests in requests.append(request); return requests.count }
            let body = count == 1 ? #"{"name":"projects/test-project/messages/123"}"# : #"{"error":{"code":404,"message":"gone","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}"#
            var headers = HTTPHeaders()
            headers.add(name: "Content-Length", value: String(body.utf8.count))
            headers.add(name: "Retry-After", value: "120")
            context.write(wrapOutboundOut(.head(.init(version: .http1_1, status: count == 1 ? .ok : .notFound, headers: headers))), promise: nil)
            var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            self.request = nil
        }
    }
}
