import AsyncHTTPClient
import Foundation
import GoogleCloudBase
import NIOHTTP1

private let defaultAPIEndpoint = URL(string: "https://cloudtasks.googleapis.com/")!

public struct TasksQueue: Sendable {
    private let credential: any Credential
    private let authorizedClient: AuthorizedClient
    private let parent: String

    public init(
        projectID: String,
        location: String,
        name: String,
        credential: any Credential,
        client: AsyncHTTPClient.HTTPClient
    ) {
        self.init(
            id: "projects/\(projectID)/locations/\(location)/queues/\(name)",
            credential: credential,
            client: client
        )
    }

    public init(
        id: String,
        credential: any Credential,
        client: AsyncHTTPClient.HTTPClient
    ) {
        parent = id.addingSlashSuffix.choppingSlashPrefix
        self.credential = credential
        authorizedClient = .init(
            baseURL: defaultAPIEndpoint,
            credential: credential,
            httpClient: client
        )
    }

    public func create(
        taskID: String? = nil,
        scheduleTime: Date? = nil,
        request: TasksTask.HttpRequest
    ) async throws -> TasksTask {
        /// subset of `TasksTask`
        struct Task: Encodable {
            var name: String?
            @RFC3339ZOptionalDate var scheduleTime: Date?
            var httpRequest: TasksTask.HttpRequest
        }
        struct Request: Encodable {
            var task: Task
            var responseView: TasksResponseView = .viewUnspecified
        }

        var request = request
        if request.oidcToken == nil && request.oauthToken == nil {
            if let serviceAccountEmail = (credential as? (any RichCredential))?.clientEmail {
                request.oidcToken = .init(serviceAccountEmail: serviceAccountEmail, audience: nil)
            }
        }

        let task = Task(
            name: taskID.map { parent + "tasks/\($0.replacingOccurrences(of: "/", with: "_"))" },
            scheduleTime: scheduleTime,
            httpRequest: request
        )
        let payload = Request(task: task)
        let path = "v2/" + parent + "tasks"

        return try await authorizedClient.post(path: path, payload: payload, responseType: TasksTask.self)
    }

    public func get(
        taskID: String
    ) async throws -> TasksTask {
        let path = "v2/" + parent + "tasks/" + taskID
        return try await authorizedClient.get(path: path, responseType: TasksTask.self)
    }
}
