//
//  SessionStorage.swift
//  LearningDashboard
//
//  Auth tokens are credentials: they go in the Keychain (hardware-backed encryption,
//  excluded from unencrypted backups with *ThisDeviceOnly*), never UserDefaults,
//  plain files, or the SwiftData store.
//

import Foundation
import OSLog
import Security

protocol SessionStorage: AnyObject {
    func save(_ session: AuthSession) throws
    func load() -> AuthSession?
    func clear()
}

final class KeychainSessionStorage: SessionStorage {
    private let service: String
    private let account = "auth-session"

    init(service: String = Bundle.main.bundleIdentifier ?? "LearningDashboard") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        // Readable after first unlock (so background refresh could use it), never
        // migrates to another device via backups.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            Log.auth.error("Keychain save failed: \(status)")
            throw AppError.persistence
        }
    }

    func load() -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// Used by tests and SwiftUI previews.
final class InMemorySessionStorage: SessionStorage {
    private var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func save(_ session: AuthSession) throws { self.session = session }
    func load() -> AuthSession? { session }
    func clear() { session = nil }
}
