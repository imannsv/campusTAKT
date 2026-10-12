import Foundation

public func newStudentNotices(_ notices: [StudentNotice], knownIDs: Set<Int>?) -> [StudentNotice] {
  guard let knownIDs else { return [] }
  return notices.filter { !knownIDs.contains($0.id) }.sorted {
    $0.created == $1.created ? $0.id < $1.id : $0.created < $1.created
  }
}
