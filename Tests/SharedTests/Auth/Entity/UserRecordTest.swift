@testable import FirebaseAdmin
import XCTest

final class UserRecordTest: XCTestCase {
    func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    func testGetAccountInfoResponse() throws {
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
        let user = try XCTUnwrap(decoded.users.first)
        XCTAssertEqual(user.providers.first?.providerID, "password")
        XCTAssertGreaterThan(user.createdAt, Date(timeIntervalSince1970: 1638245305))
    }


    func testManyAttributes() throws {
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

        XCTAssertEqual(user.providers.first?.providerID, "password")
        XCTAssertTrue(user.emailVerified)
        XCTAssertGreaterThan(user.createdAt, Date(timeIntervalSince1970: 1638245305))
        XCTAssertEqual(user.customClaims["custom"], "value")
        XCTAssertGreaterThan(try XCTUnwrap(user.lastRefreshAt), Date(timeIntervalSince1970: 1638245305))

    }
}
