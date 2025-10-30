import Foundation
import FirebaseAdmin
import JWTKit
import Testing

private let dummyServiceAccountJSON = Data(#"""
{
"type": "service_account",
"project_id": "my-project",
"private_key_id": "918e6ef6548bc8fbe09be284b5196f3343df8611",
"private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDIlHAulX6Tm7AH\nZPstuTIwVJKrDbhSbJT3Nzvh3fY2maqiTzCWLRzEKijCfcOhLmoQxc/buqoTkcyw\nG/sOLckQOWpOWWdRtAHOD87ITxzgNEBwsWleRcO5vn5QrWZkSv2oFLEJFRUWNW22\nlq5rQwhrqeMPUvzD7lzTrpRGIBC0zOyFKUqqAJQsg3gY7+9aOpJ8zVfPtnvQIwJP\nKt3Y3SWtOH4D4ktfJJTu+rX3y+w2E3NoS05QKD8OBmhKUhE0pA9FnOvFVjRHuXu2\nkvfexGA6G4QprS5Ei+Wq6ypwxwIUAevFp4VZ2/Md6gswGjtNcK/2Wb8YPhH3Lz20\nvYqDJ8JNAgMBAAECggEAA87wXldk+C/W5Me3DoQwqW2W/KZzCdBD988AVREze+U+\nXHySbezcr0t5oKUQp352ccEVFD/0ELu484hkeOgc+YY4OCqcZUG8swk7zN6BAYTH\nIHH4j9tVPwaYkWGUIHKyuZPtqerQ5ANkWjjRhk8shBbNV9zPLc0tzVsdjO347eXZ\nh/5s/BnEl5X81sbEg1VjSkGFt+srdbXL+E2otI9GhKdcpA4IyC7gMBNbNq9ZLHNm\nJA9FdnuqYK7iAlb0rtBdUDyDuarXb44uVZEA5qukvPNK95yPKN/rcQ7MWxsMolhf\nEqX5LCujJ4NYWJ9k9Le9fqWJ8IbhT5w71hrDInIJ4QKBgQD38ORGZMqojdMHfDTG\nHMYDue3XIFngb68R4lbX+t/iNHPigv5lY2CVEjv+nrhYgODFWA4OiuZyWDrLrW7V\nrkpSO81bfrRb+XbL5Alojs0sKLOzpJxDUR28xm/LOP/6jzTvlKrtPJSgDiaX2WO3\nLhPZcbHej6vPyprUgDaCu/9QpQKBgQDPGXTARTFjjswOzPQW6La+bWU78rpX2kMt\ngdIZ2MgIB5I1/dY3aKsqqijzsA3qBQqlZZoh/WVIa78gGUtlrcXb6Wi0hBkmDz98\ngoGlUwIXfHLfWipWqmD/EJi05BkaBagkPJEZ+H3Yafo0UpVGLIYCZZVPIrPB+GrU\nZBDSc1ISiQKBgQCTvguIls7cGYbCUxTvaH3mAojjQ/fKcUKVGZY+JNP76t2TABOv\nPsRyj+cIFnQq6MEHVy0pJUOkp0aBz9rXoX/P+Kqp9ppqpABSBpREpbNEuQw7477p\nrhBWSLidFF4UY/lbOe+QZiT6KvR8T6HHqcFSNRmUUXBD5arVLYFN7dB5sQKBgGxX\nh+FyEUVhFdWEWQmHEtsKRdSXxe5hy5UJ/kzxQKwasd22/pMcGbeHL0dUyeKsYoZm\nYbz4YD0DyQfU08HMp97E+7a8CKAFiBPt/j7r7wM0Yq//7nhKR9YH66tuTMd1QCI8\n4Tfx7HwD7RXkQh1k+3JTjEnLALkv6UtVUguWss/pAoGAFWcIPpDRiWzZBPsiyT3H\n1CZQFW7PBXJj+vXeugt0hNiz0xqPpv/S5pHfGXbKOfygWZ5UB2Q8ZwTK/vhkPF2Z\niBceMHUeKxGccRS5lOEIkEe2zpUtoBrdapdAlsgJhyNLOhad2Vy2eMTGVX2ot0lV\nTUEYWDUwrTVTIdhGdo4KqOk=\n-----END PRIVATE KEY-----\n",
"client_email": "my-app-local@my-project.iam.gserviceaccount.com",
"client_id": "116167750056614796145",
"auth_uri": "https://accounts.google.com/o/oauth2/auth",
"token_uri": "https://oauth2.googleapis.com/token",
"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
"client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/my-app-local%40my-project.iam.gserviceaccount.com"
}
"""#.utf8)

private let publicKey = #"""
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyJRwLpV+k5uwB2T7Lbky
MFSSqw24UmyU9zc74d32Npmqok8wli0cxCoown3DoS5qEMXP27qqE5HMsBv7Di3J
EDlqTllnUbQBzg/OyE8c4DRAcLFpXkXDub5+UK1mZEr9qBSxCRUVFjVttpaua0MI
a6njD1L8w+5c066URiAQtMzshSlKqgCULIN4GO/vWjqSfM1Xz7Z70CMCTyrd2N0l
rTh+A+JLXySU7vq198vsNhNzaEtOUCg/DgZoSlIRNKQPRZzrxVY0R7l7tpL33sRg
OhuEKa0uRIvlqusqcMcCFAHrxaeFWdvzHeoLMBo7TXCv9lm/GD4R9y89tL2KgyfC
TQIDAQAB
-----END PUBLIC KEY-----
"""#

fileprivate struct FirebaseCustomTokenPayload: JWTPayload {
    var iss: String
    var sub: String
    var aud: String
    var iat: Int
    var exp: Int
    var uid: String
    var tenant_id: String?

    func verify(using algorithm: some JWTAlgorithm) async throws {}
}

@Test func authCustomToken() async throws {
    let client = try GCPClient(credentialFactory: .json(data: dummyServiceAccountJSON))
    defer { Task { try await client.shutdown() } }
    
    let auth = try Auth(client: client)
    let token = try await auth.customToken(uid: "testing-uid")
//    print(token)

    let keys = JWTKeyCollection()
    let key = try Insecure.RSA.PublicKey(pem: publicKey)
    await keys.add(rsa: key, digestAlgorithm: .sha256)

    let verified = try await keys.verify(token, as: FirebaseCustomTokenPayload.self)
    #expect(verified.iss == "my-app-local@my-project.iam.gserviceaccount.com")
}
