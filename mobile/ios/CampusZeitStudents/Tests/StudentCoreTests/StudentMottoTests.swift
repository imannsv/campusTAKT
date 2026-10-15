import XCTest

@testable import StudentCore

final class StudentMottoTests: XCTestCase {
  func testMottoDoesNotRepeatWhenAppBecomesActive() {
    var previous = studentMotto()
    for _ in 0..<100 {
      let next = studentMotto(after: previous)
      XCTAssertFalse(next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      XCTAssertNotEqual(next, previous)
      previous = next
    }
    XCTAssertFalse(studentMotto(after: "Unbekannter alter Spruch").isEmpty)
  }
}
