import NIOPosix

extension NIOThreadPool {
    public func runIfActive<T>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.submit { shouldRun in
                switch shouldRun {
                case .active:
                    continuation.resume(with: Result(catching: body))
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }
}
