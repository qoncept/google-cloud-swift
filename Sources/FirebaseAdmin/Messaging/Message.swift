/// A message sent through Firebase Cloud Messaging HTTP v1.
public struct Message: Encodable, Sendable {
    /// Exactly one recipient is required by FCM.
    public enum Target: Sendable {
        case token(String)
        case topic(String)
        case condition(String)
    }

    public struct Notification: Encodable, Sendable {
        public var title: String?
        public var body: String?
        public var image: String?

        public init(title: String? = nil, body: String? = nil, image: String? = nil) {
            self.title = title
            self.body = body
            self.image = image
        }
    }

    public struct AndroidConfig: Encodable, Sendable {
        public enum Priority: String, Encodable, Sendable {
            case normal = "NORMAL"
            case high = "HIGH"
        }

        public var priority: Priority?
        /// A protobuf duration string, such as `"120s"`; FCM accepts up to four weeks.
        public var ttl: String?

        public init(priority: Priority? = nil, ttl: String? = nil) {
            self.priority = priority
            self.ttl = ttl
        }
    }

    public var target: Target
    public var notification: Notification?
    public var data: [String: String]?
    public var android: AndroidConfig?

    public init(
        target: Target,
        notification: Notification? = nil,
        data: [String: String]? = nil,
        android: AndroidConfig? = nil
    ) {
        self.target = target
        self.notification = notification
        self.data = data
        self.android = android
    }

    private enum CodingKeys: String, CodingKey {
        case token, topic, condition, notification, data, android
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch target {
        case .token(let value): try container.encode(value, forKey: .token)
        case .topic(let value): try container.encode(value, forKey: .topic)
        case .condition(let value): try container.encode(value, forKey: .condition)
        }
        try container.encodeIfPresent(notification, forKey: .notification)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(android, forKey: .android)
    }
}
