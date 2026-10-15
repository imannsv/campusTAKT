import Foundation

public struct StudentPushRegistration: Decodable, Sendable {
  public let binding: UUID
}

public func studentPushToken(_ data: Data) -> String {
  data.map { String(format: "%02x", $0) }.joined()
}

public func matchesStudentPush(_ payload: [AnyHashable: Any], binding: String?) -> Bool {
  guard let binding, let expected = UUID(uuidString: binding),
    let value = payload["binding"] as? String, UUID(uuidString: value) == expected,
    let notice = payload["notice_id"] as? Int, notice > 0
  else { return false }
  return true
}
