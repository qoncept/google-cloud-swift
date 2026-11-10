import Foundation
import GoogleCloudBase
import Logging
import NIOHTTP1

/// A Firebase Cloud Messaging HTTP v1 client.
public struct Messaging: Sendable {
    public static let productionBaseURL = URL(string: "https://fcm.googleapis.com/v1")!

    private let authorizedClient: AuthorizedClient
    public let projectID: String

    private static func projectID(from credential: any Credential) -> String? {
        guard let richCredential = credential as? any RichCredential else {
            return nil
        }
        return richCredential.projectID
    }

    public init(
        client: GCPClient,
        projectID paramProjectID: String? = nil,
        baseURL: URL = Self.productionBaseURL
    ) throws {
        guard let projectID = paramProjectID ?? Self.projectID(from: client.credential) else {
            throw MessageError("projectID must be provided if the credential doesn't have it.")
        }
        self.authorizedClient = AuthorizedClient(
            baseURL: baseURL
                .appendingPathComponent("projects")
                .appendingPathComponent(projectID),
            gcpClient: client
        )
        self.projectID = projectID
    }

    /// Sends a message and returns its FCM resource name. Set `validateOnly` for a dry run.
    public func send(_ message: Message, validateOnly: Bool = false, logger: Logger? = nil) async throws -> String {
        struct Request: Encodable {
            var message: Message
            var validate_only: Bool
        }
        struct Response: Decodable {
            var name: String
        }

        do {
            let response = try await authorizedClient.execute(
                method: .POST,
                path: "/messages:send",
                payload: .json(Request(message: message, validate_only: validateOnly)),
                logger: logger,
                responseType: Response.self
            )
            return response.name
        } catch let error as ErrorResponse {
            throw MessagingError(error)
        }
    }
}

public enum MessagingConfigurationError: Error {
    case invalidProjectID
}

/// A non-success response from FCM. Transport and decoding errors are thrown separately.
public struct MessagingError: Error, Sendable {
    public var statusCode: UInt
    public var status: String?
    public var message: String
    public var headers: HTTPHeaders
    /// FCM-specific error code, when present in a `google.firebase.fcm.v1.FcmError` detail.
    public var fcmErrorCode: String?

    /// Only an explicit FCM `UNREGISTERED` response establishes that a token is no longer valid.
    public var isUnregistered: Bool { fcmErrorCode == "UNREGISTERED" }

    init(_ response: ErrorResponse) {
        struct FCMDetail: Decodable {
            var type: String
            var errorCode: String?
            enum CodingKeys: String, CodingKey {
                case type = "@type"
                case errorCode
            }
        }
        self.statusCode = response.httpStatusCode ?? UInt(clamping: response.error.code)
        self.status = response.error.status
        self.message = response.error.message
        self.headers = response.httpHeaders ?? HTTPHeaders()
        self.fcmErrorCode = response.error.details?.lazy
            .compactMap { try? $0.decode(FCMDetail.self) }
            .first {
                $0.type == "type.googleapis.com/google.firebase.fcm.v1.FcmError"
            }?.errorCode
    }
}
