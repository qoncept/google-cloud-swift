@testable import FirebaseAdmin
import XCTest

final class FirebaseAuthTokenTest: XCTestCase {
    func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    func testCustomClaim() throws {
        let json = """
{
  "name": "Kenta Okamura",
  "picture": "https://lh3.googleusercontent.com/a-/AOh14GiIqBrsdTGM9H3jCj9p9ohDb7tjOBUzI_QCissa=s96-c",
  "iss": "https://securetoken.google.com/genoise-dev",
  "aud": "genoise-dev",
  "auth_time": 1636623155,
  "user_id": "ysH2TLjCH2N14Uy7CWjTBFX1qTr2",
  "sub": "ysH2TLjCH2N14Uy7CWjTBFX1qTr2",
  "iat": 1636698591,
  "exp": 1636702191,
  "email": "okamura@qoncept.co.jp",
  "email_verified": true,
  "firebase": {
    "identities": {
      "email": [
        "okamura@qoncept.co.jp"
      ]
    },
    "sign_in_provider": "password"
  },
  "mykey": "custom claim"
}
""".data(using: .utf8)!

        let decoded = try makeDecoder().decode(FirebaseAuthToken.self, from: json)

        XCTAssertEqual(decoded.name, "Kenta Okamura")
        XCTAssertEqual(decoded.claims["mykey"], "custom claim")
        XCTAssertTrue(decoded.isEmailVerified)
    }
}
