extension Result {
    func tryMapError<NewError: Error>(_ convert: (Failure) throws -> NewError) throws -> Result<Success, NewError> {
        switch self {
        case .success(let x): return .success(x)
        case .failure(let e): return .failure(try convert(e))
        }
    }
}
