struct GetUserRequest: Encodable {
    var localId: [String]?
    var email: [String]?
}

struct GetUserResponse: Decodable {
    var users: [UserRecord]?
}
