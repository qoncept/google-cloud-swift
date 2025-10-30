extension Result where Failure == any Error {
    init(catching body: () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}

extension Result where Failure == Never {
    init(catching body: () async -> Success) async {
        self = .success(await body())
    }
}

extension Result {
    var success: Success? {
        switch self {
        case .success(let x): return x
        default: return nil
        }
    }

    var failure: Failure? {
        switch self {
        case .failure(let x): return x
        default: return nil
        }
    }
}
