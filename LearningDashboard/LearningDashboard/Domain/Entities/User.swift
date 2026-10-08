//
//  User.swift
//  LearningDashboard
//

import Foundation

nonisolated struct User: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String
}

/// Everything needed to keep a user signed in. Persisted only in the Keychain.
nonisolated struct AuthSession: Codable, Hashable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: User

    func isValid(at date: Date) -> Bool { expiresAt > date }
}
