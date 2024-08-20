import Foundation

// INFO: https://cloud.google.com/tasks/docs/reference/rest/v2/projects.locations.queues.tasks#View

public enum TasksResponseView: String, Codable, Sendable {
    case viewUnspecified = "VIEW_UNSPECIFIED"
    case basic = "BASIC"
    case full = "FULL"
}
