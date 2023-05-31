struct GetUsersRequest: Encodable {
    var localId: [String] = []
    var email: [String] = []

    mutating func append(query: UserIdentityQuery) {
        switch query {
        case .uid(let x): localId.append(x)
        case .email(let x): email.append(x)
        }
    }
}

struct GetUsersResponse: Decodable {
    var users: [UserRecord]?
}

