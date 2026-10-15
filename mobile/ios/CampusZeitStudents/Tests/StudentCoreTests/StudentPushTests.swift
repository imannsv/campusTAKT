import Foundation
import XCTest

@testable import StudentCore

final class StudentPushTests: XCTestCase {
  func testTokenPreservesLeadingZeroesAndVariableLength() {
    XCTAssertEqual(studentPushToken(Data([0, 1, 15, 16, 255])), "00010f10ff")
    XCTAssertEqual(studentPushToken(Data(repeating: 0xab, count: 100)).count, 200)
  }

  func testPushBindingRejectsOtherSessionsAndMalformedPayloads() {
    let binding = UUID().uuidString
    XCTAssertTrue(
      matchesStudentPush(["binding": binding.lowercased(), "notice_id": 12], binding: binding))
    XCTAssertFalse(
      matchesStudentPush(["binding": UUID().uuidString, "notice_id": 12], binding: binding))
    XCTAssertFalse(matchesStudentPush(["binding": binding, "notice_id": -1], binding: binding))
    XCTAssertFalse(matchesStudentPush(["binding": binding, "notice_id": 12], binding: nil))
  }
}
