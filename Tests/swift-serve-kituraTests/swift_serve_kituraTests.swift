import XCTest
@testable import swift_serve_kitura

class swift_serve_kituraTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(swift_serve_kitura().text, "Hello, World!")
    }


    static var allTests : [(String, (swift_serve_kituraTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
