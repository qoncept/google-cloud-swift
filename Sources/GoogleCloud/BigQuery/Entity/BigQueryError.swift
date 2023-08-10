import Foundation

struct BigQueryError: Error, Decodable {
    var reason: String?
    var location: String?
    var message: String?
}

struct BigQueryErrors: Error {
    var errors: [BigQueryError]
}
