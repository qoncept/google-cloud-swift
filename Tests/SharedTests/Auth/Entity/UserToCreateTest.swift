@testable import FirebaseAdmin
import XCTest

final class UserToCreateTest: XCTestCase {
    func testPasswordValidation() {
        let c1 = UserToCreate(password: "012345")
        XCTAssertNoThrow(try c1.validatedRequest())

        let c2 = UserToCreate(password: "short")
        XCTAssertThrowsError(try c2.validatedRequest())
    }

    func testPhoneNumberValidation() {
        let c1 = UserToCreate(phoneNumber: "+15555550100")
        XCTAssertNoThrow(try c1.validatedRequest())

        let c2 = UserToCreate(phoneNumber: "15555550100")
        XCTAssertThrowsError(try c2.validatedRequest())

        let c3 = UserToCreate(phoneNumber: "+_!@#$")
        XCTAssertThrowsError(try c3.validatedRequest())

        let c4 = UserToCreate(phoneNumber: "")
        XCTAssertThrowsError(try c4.validatedRequest())
    }

    func testEmailValidation() {
        let c1 = UserToCreate(email: "a@a.com")
        XCTAssertNoThrow(try c1.validatedRequest())

        let c2 = UserToCreate(email: "")
        XCTAssertThrowsError(try c2.validatedRequest())

        let c3 = UserToCreate(email: "a")
        XCTAssertThrowsError(try c3.validatedRequest())

        let c4 = UserToCreate(email: "a@")
        XCTAssertThrowsError(try c4.validatedRequest())

        let c5 = UserToCreate(email: "@a.")
        XCTAssertThrowsError(try c5.validatedRequest())

        let c6 = UserToCreate(email: "a@a@a")
        XCTAssertThrowsError(try c6.validatedRequest())
    }
}
