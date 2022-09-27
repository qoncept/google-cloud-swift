import Logging

private let _initLogger: Void = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = .debug
        return handler
    }
}()

func initLogger() {
    _ = _initLogger
}
