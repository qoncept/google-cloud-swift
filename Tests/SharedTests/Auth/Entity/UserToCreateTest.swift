@testable import FirebaseAdmin
import XCTest

final class UserToCreateTest: XCTestCase {
    func testPasswordValidation() throws {
        let c1 = UserToCreate(password: "012345")
        XCTAssertNil(c1.validatedRequest().failure)

        let c2 = UserToCreate(password: "short")
        let error = try XCTUnwrap(c2.validatedRequest().failure)
        XCTAssertEqual(error.code, .weakPassword)
        XCTAssertEqual(error.message, "password must be a string at least 6 characters long")
    }

    func testPhoneNumberValidation() throws {
        let c1 = UserToCreate(phoneNumber: "+15555550100")
        XCTAssertNil(c1.validatedRequest().failure)

        let c2 = UserToCreate(phoneNumber: "15555550100")
        var error = try XCTUnwrap(c2.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidPhoneNumber)
        XCTAssertEqual(error.message, "phone number must be a valid, E.164 compliant identifier")

        let c3 = UserToCreate(phoneNumber: "+_!@#$")
        error = try XCTUnwrap(c3.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidPhoneNumber)
        XCTAssertEqual(error.message, "phone number must be a valid, E.164 compliant identifier")

        let c4 = UserToCreate(phoneNumber: "")
        error = try XCTUnwrap(c4.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidPhoneNumber)
        XCTAssertEqual(error.message, "phone number must be a non-empty string")
    }

    func testEmailValidation() throws {
        let c1 = UserToCreate(email: "a@a.com")
        XCTAssertNil(c1.validatedRequest().failure)

        let c2 = UserToCreate(email: "")
        var error = try XCTUnwrap(c2.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidEmail)
        XCTAssertEqual(error.message, "email must be a non-empty string")

        let c3 = UserToCreate(email: "a")
        error = try XCTUnwrap(c3.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidEmail)
        XCTAssertEqual(error.message, "malformed email string: a")

        let c4 = UserToCreate(email: "a@")
        error = try XCTUnwrap(c4.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidEmail)
        XCTAssertEqual(error.message, "malformed email string: a@")

        let c5 = UserToCreate(email: "@a.")
        error = try XCTUnwrap(c5.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidEmail)
        XCTAssertEqual(error.message, "malformed email string: @a.")

        let c6 = UserToCreate(email: "a@a@a")
        error = try XCTUnwrap(c6.validatedRequest().failure)
        XCTAssertEqual(error.code, .invalidEmail)
        XCTAssertEqual(error.message, "malformed email string: a@a@a")
    }
}
