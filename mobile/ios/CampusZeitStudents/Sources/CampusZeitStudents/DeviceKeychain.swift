#if canImport(UIKit)
  import Foundation
  import Security
  import StudentCore

  enum DeviceKeychain {
    private static let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "de.campuszeit.students",
      kSecAttrAccount as String: "group-session",
    ]
    static func read() throws -> DeviceCredential? {
      var request = query
      request[kSecReturnData as String] = true
      request[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(request as CFDictionary, &result)
      if status == errSecItemNotFound { return nil }
      guard status == errSecSuccess, let data = result as? Data else { throw failure(status) }
      return try JSONDecoder().decode(DeviceCredential.self, from: data)
    }
    static func save(_ credential: DeviceCredential) throws {
      let data = try JSONEncoder().encode(credential)
      var status = SecItemUpdate(
        query as CFDictionary,
        [
          kSecValueData as String: data,
          kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary)
      if status == errSecItemNotFound {
        var record = query
        record[kSecValueData as String] = data
        record[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        status = SecItemAdd(record as CFDictionary, nil)
      }
      guard status == errSecSuccess else { throw failure(status) }
    }
    static func clear() throws {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
    }
    private static func failure(_ status: OSStatus) -> StudentError {
      .service(
        "Der geschützte Gerätespeicher ist nicht verfügbar (\(status)). Bitte das iPhone entsperren und erneut versuchen."
      )
    }
  }
#endif
