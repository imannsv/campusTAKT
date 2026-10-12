#if canImport(UIKit)
  import AVFoundation
  import SwiftUI
  import UserNotifications
  import StudentCore

  @MainActor
  final class StudentPermissions: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var setupOpen = false
    @Published var requesting = false
    @Published var cameraGranted = false
    @Published var notificationsGranted = false
    @Published var openInbox = false
    @Published var error: String?
    private let center = UNUserNotificationCenter.current()
    private var currentScope: String?
    private let setupKey = "campuszeit.permissions.configured"

    func prepare() async {
      center.delegate = self
      await refreshStatus()
      setupOpen = !UserDefaults.standard.bool(forKey: setupKey)
    }

    func refreshStatus() async {
      cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
      let settings = await center.notificationSettings()
      notificationsGranted = [.authorized, .provisional, .ephemeral].contains(
        settings.authorizationStatus)
    }

    func request() async {
      guard !requesting else { return }
      requesting = true
      error = nil
      defer { requesting = false }
      if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
        _ = await AVCaptureDevice.requestAccess(for: .video)
      }
      do {
        if await center.notificationSettings().authorizationStatus == .notDetermined {
          _ = try await center.requestAuthorization(options: [.alert, .sound])
        }
        await refreshStatus()
        finishSetup()
      } catch {
        self.error =
          "Die Benachrichtigungsfreigabe konnte nicht abgefragt werden. Bitte erneut versuchen oder später in den iPhone-Einstellungen aktivieren."
      }
    }

    func finishSetup() {
      UserDefaults.standard.set(true, forKey: setupKey)
      setupOpen = false
    }

    func clearNotifications() {
      currentScope = nil
      openInbox = false
      center.removeAllPendingNotificationRequests()
      center.removeAllDeliveredNotifications()
    }

    func receive(_ notices: [StudentNotice], credential: DeviceCredential) async {
      let scope =
        credential.server.absoluteString + "|" + credential.login.scopeKind + "|"
        + credential.login.scope
      currentScope = scope
      let key = "campuszeit.notices.seen." + scope
      let saved = UserDefaults.standard.array(forKey: key) as? [Int]
      var known = Set(saved ?? [])
      let incoming = newStudentNotices(notices, knownIDs: saved == nil ? nil : known)
      if saved == nil {
        UserDefaults.standard.set(notices.map(\.id), forKey: key)
        return
      }
      await refreshStatus()
      guard currentScope == scope else { return }
      if !notificationsGranted {
        UserDefaults.standard.set(Array(known.union(notices.map(\.id))), forKey: key)
        return
      }
      // shortcut: notifications arrive when the app fetches; closed-app delivery needs APNs.
      for notice in incoming {
        guard currentScope == scope else { return }
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = String(notice.body.prefix(200))
        content.sound = .default
        let identifier = "campuszeit.notice." + scope + ".\(notice.id)"
        do {
          try await center.add(
            UNNotificationRequest(
              identifier: identifier, content: content, trigger: nil))
          guard currentScope == scope else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            return
          }
          known.insert(notice.id)
          UserDefaults.standard.set(Array(known), forKey: key)
        } catch {
          self.error =
            "Eine Mitteilung konnte nicht als Benachrichtigung angezeigt werden. Sie bleibt im Posteingang verfügbar."
        }
      }
    }

    nonisolated func userNotificationCenter(
      _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
      _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
      Task { @MainActor in self.openInbox = true }
      completionHandler()
    }
  }
#endif
