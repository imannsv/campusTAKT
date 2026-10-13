#if canImport(UIKit)
  import SwiftUI

  @main
  struct CampusZeitStudentsApp: App {
    @UIApplicationDelegateAdaptor(StudentAppDelegate.self) private var appDelegate
    var body: some Scene {
      WindowGroup {
        ContentView(
          store: appDelegate.store, permissions: appDelegate.permissions,
          scheduleBackgroundRefresh: appDelegate.scheduleRefresh)
      }
    }
  }
#endif
