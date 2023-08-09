import Foundation
import XCTest

func XCTUnwrap<T>(_ expression: @Sendable () async throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let v = await Result { try await expression() }
    return try XCTUnwrap(v.get(), message(), file: file, line: line)
}

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

func XCTAssertThrowsError<T>(_ expression: @Sendable () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: any Error) -> Void = { _ in }) async {
    let v = await Result { try await expression() }
    XCTAssertThrowsError(try v.get(), message(), file: file, line: line, errorHandler)
}

func XCTAssertNoThrow(_ expression: @Sendable () async throws -> Void, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
    let v = await Result { try await expression() }
    XCTAssertNoThrow(try v.get(), message(), file: file, line: line)
}

func XCTAssertNoThrow<T>(_ expression: @Sendable () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let v = await Result { try await expression() }
    XCTAssertNoThrow(try v.get(), message(), file: file, line: line)
    return try v.get()
}

