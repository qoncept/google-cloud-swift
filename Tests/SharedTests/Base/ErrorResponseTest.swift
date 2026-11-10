import Foundation
import GoogleCloud
import Testing

@Suite struct ErrorResponseTest {
    @Test func preservesAndDecodesErrorDetails() throws {
        struct BadRequest: Decodable {
            struct Violation: Decodable {
                var field: String
            }
            var fieldViolations: [Violation]
        }

        let body = #"""
        {
            "error": {
                "code": 400,
                "message": "invalid",
                "details": [
                    {
                        "@type": "type.googleapis.com/google.rpc.BadRequest",
                        "fieldViolations": [{"field": "message.data"}]
                    },
                    {
                        "@type": "example.com/unknown",
                        "nested": {"enabled": true, "values": [null, 42]}
                    }
                ]
            }
        }
        """#
        let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(body.utf8))
        let details = try #require(response.error.details)

        #expect(try details[0].decode(BadRequest.self).fieldViolations.first?.field == "message.data")

        let encoded = try JSONEncoder().encode(details[1])
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let nested = try #require(object["nested"] as? [String: Any])

        #expect(nested["enabled"] as? Bool == true)
        #expect((nested["values"] as? [Any])?.count == 2)
    }
}
