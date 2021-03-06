import Foundation
import Models
import XCTest

class EitherTests: XCTestCase {
    private struct SomeError: Error, Equatable, Codable {
        let thisIsError: String
    }

    func test___success_is_left() {
        XCTAssertEqual(
            Either<String, SomeError>.left("hello"),
            Either<String, SomeError>.success("hello")
        )
    }

    func test___comparing_left() {
        XCTAssertNotEqual(
            Either<String, SomeError>.left("left"),
            Either<String, SomeError>.left("oops")
        )
    }

    func test___error_is_right() {
        XCTAssertEqual(
            Either<String, SomeError>.right(SomeError(thisIsError: "error")),
            Either<String, SomeError>.error(SomeError(thisIsError: "error"))
        )
    }

    func test___comparing_right() {
        XCTAssertNotEqual(
            Either<String, SomeError>.right(SomeError(thisIsError: "error1")),
            Either<String, SomeError>.right(SomeError(thisIsError: "error2"))
        )
    }

    func test___encoding_left() throws {
        let expected = Either<String, SomeError>.left("hello")
        let data = try JSONEncoder().encode(expected)
        let decoded = try JSONDecoder().decode(Either<String, SomeError>.self, from: data)
        XCTAssertEqual(decoded, expected)
    }

    func test___encoding_right() throws {
        let expected = Either<String, SomeError>.right(SomeError(thisIsError: "error"))
        let data = try JSONEncoder().encode(expected)
        let decoded = try JSONDecoder().decode(Either<String, SomeError>.self, from: data)
        XCTAssertEqual(decoded, expected)
    }
}
