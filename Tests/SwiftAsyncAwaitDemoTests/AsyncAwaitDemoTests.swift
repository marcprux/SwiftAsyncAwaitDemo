import XCTest
@testable import SwiftAsyncAwaitDemo

#if swift(>=5.5)




func foo() async -> String {
    return "FOO"
}


func bar() async throws -> String {
    return "BAR"
}







@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class AsyncAwaitDemoTests: XCTestCase {

    // @asyncHandler // “'@asyncHandler' has been removed from the language” (20-04-2021)
    func testAsyncAwait() throws {
        waitForAsync {
            let x = await foo()
            XCTAssertEqual("FOO", x)
        }

        try waitForAsyncThrowing {
            let x = try await bar()
            XCTAssertEqual("BAR", x)
        }
    }

    func testFetcher() throws {
        XCTAssertEqual(200, try waitForAsyncThrowing {
            try await URLSession.shared.fetch(url: "http://www.example.com").response.statusCode
        })

        XCTAssertEqual(404, try waitForAsyncThrowing {
            try await URLSession.shared.fetch(url: "http://www.example.net/MISSING").response.statusCode
        })

        XCTAssertEqual(1256, try waitForAsyncThrowing {
            try await URLSession.shared.fetch(url: "http://www.example.org").data.count
        })
    }

    func testWebService() throws {
        try waitForAsyncThrowing {
            let mi = try await downloadFlag(for: "mi")
            XCTAssertEqual("New Zealand", mi.info["name"] as? String)
            XCTAssertEqual("Māori", (mi.info["languages"] as? [NSDictionary])?.last?["name"] as? String)
        }
    }
}


 // “'runDetached(priority:operation:)' is only available in macOS 9999 or newer”
public extension XCTestCase {
    /// Performs the given `async` closure and wait for completion using an `XCTestExpectation`, then returns the result or re-throws the error
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    @discardableResult func waitForAsyncThrowing<T>(expectationDescription: String? = nil, timeout: TimeInterval = 5.0, closure: @escaping () async throws -> T) throws -> T {
        let expectation = self.expectation(description: expectationDescription ?? "Async operation")

        let result: ReferenceWrapper<Result<T, Error>?> = .init(nil)
        // var resultValue: Result<T, Error>?

        // Task.runDetached raises: “'runDetached(priority:operation:)' is deprecated: `Task.runDetached` was replaced by `detach` and will be removed shortly.”

        let task = _Concurrency.detach {
            do {
                result.value = .success(try await closure())
            } catch {
                result.value = .failure(error)
            }
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: timeout)
        task.cancel() // in case we time out

        return try result.value!.get() // leave the gun, take the cannoli
    }

    /// Non-throwing variant of `waitForAsyncThrowing`
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    @discardableResult func waitForAsync<T>(expectationDescription: String? = nil, timeout: TimeInterval = 5.0, closure: @escaping () async -> T) -> T {
        return try! waitForAsyncThrowing(expectationDescription: expectationDescription, timeout: timeout, closure: closure)
    }
}

/// Reference box to bypass compiler check for mutating values in concurrently-executing code in `XCTestCase.waitForAsyncThrowing`
private final class ReferenceWrapper<T> {
    fileprivate var value: T
    fileprivate init(_ value: T) { self.value = value }
}

#endif
