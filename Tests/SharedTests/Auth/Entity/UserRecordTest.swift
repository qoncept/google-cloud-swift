@testable import FirebaseAdmin
import Foundation
import Testing

@Suite struct UserRecordTest {
    func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    @Test func getAccountInfoResponse() throws {
        struct Response: Decodable {
            var users: [UserRecord]
        }
        let json = """
{
    "kind": "identitytoolkit#GetAccountInfoResponse",
    "users": [
        {
            "localId": "yE2sJxMG6JDacAccEOoDyIgYPyzG",
            "createdAt": "1638245305598",
            "lastLoginAt": "1638245305598",
            "emailVerified": false,
            "email": "test2@example.com",
            "salt": "fakeSaltSkqiFRkJNbxPv9XW7IyQ",
            "passwordHash": "fakeHash:salt=fakeSaltSkqiFRkJNbxPv9XW7IyQ:password=012345",
            "passwordUpdatedAt": 1638245305598,
            "validSince": "1638245305",
            "providerUserInfo": [
                {
                    "providerId": "password",
                    "email": "test2@example.com",
                    "federatedId": "test2@example.com",
                    "rawId": "test2@example.com"
                }
            ]
        }
    ]
}
""".data(using: .utf8)!

        let decoded = try makeDecoder().decode(Response.self, from: json)
        let user = try #require(decoded.users.first)
        #expect(user.providers.first?.providerID == "password")
        #expect(user.createdAt > Date(timeIntervalSince1970: 1638245305))
    }

    @Test func manyAttributes() throws {
        let json = """
{
    "localId": "yE2sJxMG6JDacAccEOoDyIgYPyzG",
    "createdAt": "1638245305598",
    "lastLoginAt": "1638245305598",
    "emailVerified": true,
    "email": "test2@example.com",
    "salt": "fakeSaltMF0FMvHiYfMOrgPpwblb",
    "passwordHash": "fakeHash:salt=fakeSaltMF0FMvHiYfMOrgPpwblb:password=012345",
    "passwordUpdatedAt": 1638246241187,
    "validSince": "1638246241",
    "providerUserInfo": [
        {
            "providerId": "password",
            "email": "test2@example.com",
            "federatedId": "test2@example.com",
            "rawId": "test2@example.com",
            "displayName": "MyName",
            "photoUrl": "https://github.com/sidepelican.png"
        },
        {
            "providerId": "phone",
            "phoneNumber": "+819012345678",
            "rawId": "+819012345678"
        }
    ],
    "phoneNumber": "+819012345678",
    "displayName": "MyName",
    "photoUrl": "https://github.com/sidepelican.png",
    "customAttributes": "{\\"custom\\": \\"value\\"}",
    "lastRefreshAt": "2021-11-30T04:24:01.187Z"
}
""".data(using: .utf8)!

        let user = try makeDecoder().decode(UserRecord.self, from: json)

        #expect(user.providers.first?.providerID == "password")
        #expect(user.emailVerified)
        #expect(user.createdAt > Date(timeIntervalSince1970: 1638245305))
        #expect(user.customClaims["custom"] == "value")
        #expect(try #require(user.lastRefreshAt) > Date(timeIntervalSince1970: 1638245305))
    }
}
