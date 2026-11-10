@testable import FirebaseAdmin
import Foundation
import Testing

@Suite struct MessagingTests {
    @Test(arguments: [
        (Message.Target.token("device"), "token", "device"),
        (.topic("news"), "topic", "news"),
        (.condition("'news' in topics"), "condition", "'news' in topics"),
    ])
    func encodesTargetsAndPayload(target: Message.Target, key: String, value: String) throws {
        let message = Message(
            target: target,
            notification: .init(title: "Title", body: "Body", image: URL(string: "https://example.com/image.png")!),
            data: ["payload": "{\"id\":1}"],
            android: .init(priority: .high, ttl: "120s")
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any])

        #expect(json[key] as? String == value)
        #expect(["token", "topic", "condition"].count(where: { json.index(forKey: $0) != nil }) == 1)
        #expect((json["notification"] as? [String: String]) == ["title": "Title", "body": "Body", "image": "https://example.com/image.png"])
        #expect((json["data"] as? [String: String]) == ["payload": "{\"id\":1}"])
        #expect((json["android"] as? [String: String]) == ["priority": "HIGH", "ttl": "120s"])
    }

    @Test(arguments: [
        (#"""
        {"error":{"code":404,"message":"gone","status":"NOT_FOUND","details":[
            {"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[]},
            {"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}
        ]}}
        """#, true),
        (#"""
        {"error":{"code":404,"message":"gone","details":[
            {"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"INVALID_ARGUMENT"}
        ]}}
        """#, false),
        (#"""
        {"error":{"code":404,"message":"gone","details":[
            {"@type":"other","errorCode":"UNREGISTERED"}
        ]}}
        """#, false),
    ])
    func identifiesOnlyFCMUnregistered(body: String, expected: Bool) throws {
        let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(body.utf8))
        let error = MessagingError(response)

        #expect(error.statusCode == 404)
        #expect(error.isUnregistered == expected)
    }
}
