public struct ListUserResult: Decodable {
    public init(
        users: [UserRecord],
        nextPageToken: String?
    ) {
        self.users = users
        self.nextPageToken = nextPageToken
    }
    
    public var users: [UserRecord]
    public var nextPageToken: String?
}
