import Foundation
import GoogleCloudBase
import NIOHTTP1

// INFO: https://cloud.google.com/tasks/docs/reference/rest/v2/projects.locations.queues.tasks#resource:-task

public struct TasksTask: Decodable {
    /// must be the following format: `projects/PROJECT_ID/locations/LOCATION_ID/queues/QUEUE_ID/tasks/TASK_ID`
    public var name: String

    @RFC3339ZOptionalDate public var scheduleTime: Date?
    @RFC3339ZDate public var createTime: Date
    public var dispatchDeadline: String?
    public var dispatchCount: Int?
    public var responseCount: Int?

    public struct Attempt: Decodable {
        @RFC3339ZOptionalDate public var dispatchTime: Date?
    }
    public var firstAttempt: Attempt?
    public var lastAttempt: Attempt?
    public var view: TasksResponseView

//    var appEngineHttpRequest: Never? // unsupported
    public struct HttpRequest: Codable {
        public init(url: String, httpMethod: String, headers: [String : String]? = nil, body: String, oauthToken: TasksTask.HttpRequest.OAuthToken? = nil, oidcToken: TasksTask.HttpRequest.OidcToken? = nil) {
            self.url = url
            self.httpMethod = httpMethod
            self.headers = headers
            self.body = body
            self.oauthToken = oauthToken
            self.oidcToken = oidcToken
        }

        public var url: String
        public var httpMethod: String
        public var headers: [String: String]?
        public var body: String? /// base64 encoded. ommited depends by TaskResponseView
        public struct OAuthToken: Codable {
            public var serviceAccountEmail: String
            public var scope: String?
        }
        public var oauthToken: OAuthToken?
        public struct OidcToken: Codable {
            public var serviceAccountEmail: String
            public var audience: String?
        }
        public var oidcToken: OidcToken?
    }
    public var httpRequest: HttpRequest
}

extension TasksTask {
    public var id: String {
        String(name.split(separator: "/").last!)
    }
}
