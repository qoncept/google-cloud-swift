import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import Logging
import NIOFoundationCompat

/// A Firebase Cloud Messaging HTTP v1 client.
public struct Messaging: Sendable {
    public static let productionBaseURL = URL(string: "https://fcm.googleapis.com/v1")!

    private let client: GCPClient
    private let baseURL: URL
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
        self.client = client
        self.projectID = projectID
        self.baseURL = baseURL
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

        let token = try await client.credential.getAccessToken()
        let endpoint = baseURL.appendingPathComponent("projects").appendingPathComponent(projectID)
            .appendingPathComponent("messages:send")
        var request = HTTPClientRequest(url: endpoint.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token.rawValue)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(try JSONEncoder().encode(Request(message: message, validate_only: validateOnly)))
        let response = try await client.httpClient.execute(request, timeout: .seconds(20), logger: logger)
        let body = try await response.body.collect(upTo: 64 * 1024)
        let data = Data(buffer: body)
        guard (200..<300).contains(response.status.code) else {
            throw MessagingError(statusCode: response.status.code, data: data)
        }
        return try JSONDecoder().decode(Response.self, from: data).name
    }
}

public enum MessagingConfigurationError: Error {
    case invalidProjectID
}

/// A non-success response from FCM. Transport and decoding errors are thrown separately.
public struct MessagingError: Error, Sendable {
    public var statusCode: UInt
    public var status: String?
    public var message: String?
    /// FCM-specific error code, when present in a `google.firebase.fcm.v1.FcmError` detail.
    public var fcmErrorCode: String?

    /// Only an explicit FCM `UNREGISTERED` response establishes that a token is no longer valid.
    public var isUnregistered: Bool { fcmErrorCode == "UNREGISTERED" }

    init(statusCode: UInt, data: Data) {
        struct Envelope: Decodable {
            struct Body: Decodable {
                struct Detail: Decodable {
                    var type: String?
                    var errorCode: String?
                    enum CodingKeys: String, CodingKey {
                        case type = "@type"
                        case errorCode
                    }
                }
                var status: String?
                var message: String?
                var details: [Detail]?
            }
            var error: Body
        }
        let error = try? JSONDecoder().decode(Envelope.self, from: data).error
        self.statusCode = statusCode
        self.status = error?.status
        self.message = error?.message
        self.fcmErrorCode = error?.details?.first {
            $0.type == "type.googleapis.com/google.firebase.fcm.v1.FcmError"
        }?.errorCode
    }
}
