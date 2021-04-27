import XCTest
@testable import AsyncAwaitDemo

final class AsyncAwaitDemoTests: XCTestCase {
    @asyncHandler func testAsyncAwait() {
        let f = await foo()
        XCTAssertEqual("FOO", f)

        let b = await bar()
        XCTAssertEqual("BAR", b)
    }
}

func foo() async -> String {
    return "FOO"
}

func bar() async -> String {
    return "BAR"
}
