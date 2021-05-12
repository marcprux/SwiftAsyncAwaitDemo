import XCTest
@testable import SwiftAsyncAwaitDemo
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if swift(>=5.5)

func foo() async -> String {
    print(Thread.current)
    return "FOO"
}


func bar() async throws -> String {
    return "BAR"
}











@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
func fooX() async -> String {
    return await DispatchQueue.global().asyncOperation(in: .now() + .seconds(3)) {
        "FOOX"
    }
    // return "FOO"
}





@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class AsyncAwaitDemoTests: XCTestCase {

    func testSyncDOWNLOAD() throws {
        let contents = try Data(contentsOf: URL(string: "https://www.example.org")!)
    }

    // @asyncHandler // “'@asyncHandler' has been removed from the language” (20-04-2021)
    func testAsyncAwait() throws {
        try waitForAsyncThrowing {
            print(Thread.current)
            let x = await foo()
            print(Thread.current)
            let y = await foo()
            print(Thread.current)

            XCTAssertEqual("FOO", x)
            XCTAssertEqual("FOO", y)
        }

        try waitForAsyncThrowing {
            let x = try await bar()
            XCTAssertEqual("BAR", x)
        }
    }




    func testFetcher() throws {
        XCTAssertEqual(200, try waitForAsyncThrowing {
            try await URLSession.shared.fetch("http://www.example.com").response.statusCode
        })

        XCTAssertEqual(404, try waitForAsyncThrowing {
            try await URLSession.shared.fetch("http://www.example.net/MISSING").response.statusCode
        })

        XCTAssertEqual(1256, try waitForAsyncThrowing {
            try await URLSession.shared.fetch("http://www.example.org").data.count
        })
    }

    func testWebService() throws {
        try waitForAsyncThrowing {
            let mi = try await downloadFlag(for: "mi")
            XCTAssertEqual("New Zealand", mi.info["name"] as? String)
            XCTAssertEqual("Māori", (mi.info["languages"] as? [NSDictionary])?.last?["name"] as? String)
        }
    }




    func testNoStructuredConcurrency() throws {
        try waitForAsyncThrowing {
            print(try await downloadTasksWithoutStructuredConcurrency())
        }
    }





    func testStructuredConcurrency() throws {
        try waitForAsyncThrowing {
            print(try await downloadTasksWithStructuredConcurrency())
        }
    }
}










@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
func downloadTasksWithoutStructuredConcurrency() async throws -> String {
    print("\(#function) started")

    let uuid1 = try await URLSession.shared.fetch("https://httpbin.org/uuid")
    let uuid2 = try await URLSession.shared.fetch("https://httpbin.org/uuid")

    return """
    ids fetched non-concurrently:
    uuid1: \(String(data: uuid1.data, encoding: .utf8)!)
    uuid2: \(String(data: uuid2.data, encoding: .utf8)!)
    """
}


@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
func downloadTasksWithStructuredConcurrency() async throws -> String {
    print("\(#function) started")

    async let uuid1 = URLSession.shared.fetch("https://httpbin.org/uuid")
    async let uuid2 = URLSession.shared.fetch("https://httpbin.org/uuid")

    return try await """
    ids fetched concurrently:
    uuid1: \(String(data: uuid1.data, encoding: .utf8)!)
    uuid2: \(String(data: uuid2.data, encoding: .utf8)!)
    """
}








 // “'runDetached(priority:operation:)' is only available in macOS 9999 or newer”
public extension XCTestCase {
    /// Performs the given `async` closure and wait for completion using an `XCTestExpectation`, then returns the result or re-throws the error
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    @discardableResult func waitForAsyncThrowing<T>(expectationDescription: String? = nil, timeout: TimeInterval = 10.0, closure: @escaping () async throws -> T) throws -> T {
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
