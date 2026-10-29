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

    /// The project ID can be inferred from credentials that contain one.
    public init(client: GCPClient, projectID: String? = nil, baseURL: URL = Self.productionBaseURL) throws {
        guard let projectID = projectID ?? (client.credential as? any RichCredential)?.projectID,
              !projectID.isEmpty,
              projectID.range(of: "^[A-Za-z0-9][A-Za-z0-9._:-]*$", options: .regularExpression) != nil else {
            throw MessagingConfigurationError.invalidProjectID
        }
        self.client = client
        self.projectID = projectID
        self.baseURL = baseURL
    }

    /// Sends a message and returns its FCM resource name. Set `validateOnly` for a dry run.
    public func send(_ message: Message, validateOnly: Bool = false, logger: Logger? = nil) async throws -> String {
        struct Request: Encodable {
            let message: Message
            let validate_only: Bool
        }
        struct Response: Decodable { let name: String }

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
    public let statusCode: UInt
    public let status: String?
    public let message: String?
    /// FCM-specific error code, when present in a `google.firebase.fcm.v1.FcmError` detail.
    public let fcmErrorCode: String?

    /// Only an explicit FCM `UNREGISTERED` response establishes that a token is no longer valid.
    public var isUnregistered: Bool { fcmErrorCode == "UNREGISTERED" }

    init(statusCode: UInt, data: Data) {
        struct Envelope: Decodable {
            struct Body: Decodable {
                struct Detail: Decodable {
                    let type: String?
                    let errorCode: String?
                    enum CodingKeys: String, CodingKey { case type = "@type", errorCode }
                }
                let status: String?
                let message: String?
                let details: [Detail]?
            }
            let error: Body
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
