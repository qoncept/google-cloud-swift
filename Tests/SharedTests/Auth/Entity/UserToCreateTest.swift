@testable import FirebaseAdmin
import Testing

@Suite struct UserToCreateTest {
    @Test func passwordValidation() throws {
        let c1 = UserToCreate(password: "012345")
        #expect(c1.validatedRequest().failure == nil)

        let c2 = UserToCreate(password: "short")
        let error = try #require(c2.validatedRequest().failure)
        #expect(error.code == .weakPassword)
        #expect(error.message == "password must be a string at least 6 characters long")
    }

    @Test func phoneNumberValidation() throws {
        let c1 = UserToCreate(phoneNumber: "+15555550100")
        #expect(c1.validatedRequest().failure == nil)

        let c2 = UserToCreate(phoneNumber: "15555550100")
        var error = try #require(c2.validatedRequest().failure)
        #expect(error.code == .invalidPhoneNumber)
        #expect(error.message == "phone number must be a valid, E.164 compliant identifier")

        let c3 = UserToCreate(phoneNumber: "+_!@#$")
        error = try #require(c3.validatedRequest().failure)
        #expect(error.code == .invalidPhoneNumber)
        #expect(error.message == "phone number must be a valid, E.164 compliant identifier")

        let c4 = UserToCreate(phoneNumber: "")
        error = try #require(c4.validatedRequest().failure)
        #expect(error.code == .invalidPhoneNumber)
        #expect(error.message == "phone number must be a non-empty string")
    }

    @Test func emailValidation() throws {
        let c1 = UserToCreate(email: "a@a.com")
        #expect(c1.validatedRequest().failure == nil)

        let c2 = UserToCreate(email: "")
        var error = try #require(c2.validatedRequest().failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "email must be a non-empty string")

        let c3 = UserToCreate(email: "a")
        error = try #require(c3.validatedRequest().failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "malformed email string: a")

        let c4 = UserToCreate(email: "a@")
        error = try #require(c4.validatedRequest().failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "malformed email string: a@")

        let c5 = UserToCreate(email: "@a.")
        error = try #require(c5.validatedRequest().failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "malformed email string: @a.")

        let c6 = UserToCreate(email: "a@a@a")
        error = try #require(c6.validatedRequest().failure)
        #expect(error.code == .invalidEmail)
        #expect(error.message == "malformed email string: a@a@a")
    }
}
