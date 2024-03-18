public actor AutoRotatingValue<T: Sendable> {
    let refresh: @Sendable () async throws -> (T, Duration)
    private var storage: any DurationalCacheProtocol<T>
    private var refreshingTask: Task<T, any Error>?

    public init(
        clock: some Clock<Duration> = .continuous,
        refresh: @escaping @Sendable () async throws -> (T, Duration)
    ) {
        self.refresh = refresh
        self.storage = DurationalCache(clock: clock)
    }

    public func getValue(forceRefresh: Bool = false) async throws -> T {
        if forceRefresh {
            return try await refreshTask()
        }
        guard let token = storage.cachedValue else {
            return try await refreshTask()
        }

        return token
    }

    private func refreshTask() async throws -> T {
        if let task = refreshingTask {
            return try await task.value
        }

        let task = Task<T, any Error> {
            let (newValue, lifetime) = try await refresh()
            storage.store(value: newValue, expiresIn: lifetime)
            return newValue
        }
        refreshingTask = task
        defer { refreshingTask = nil }

        return try await task.value
    }
}
