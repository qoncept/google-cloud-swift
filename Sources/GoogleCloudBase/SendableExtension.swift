import AsyncHTTPClient
import JWTKit
import Foundation
import Logging

extension AsyncHTTPClient.HTTPClient: @unchecked Sendable {}
extension Date: @unchecked Sendable {}
extension URL: @unchecked Sendable {}
extension IssuerClaim: @unchecked Sendable {}
extension AudienceClaim: @unchecked Sendable {}
extension ExpirationClaim: @unchecked Sendable {}
extension IssuedAtClaim: @unchecked Sendable {}
extension SubjectClaim: @unchecked Sendable {}
extension Logger: @unchecked Sendable {}
