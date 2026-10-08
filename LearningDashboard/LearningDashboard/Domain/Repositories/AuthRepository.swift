//
//  AuthRepository.swift
//  LearningDashboard
//
//  Repository contracts live in the Domain layer; the Data layer implements them.
//  Presentation depends only on these protocols, never on concrete data sources.
//

import Foundation

protocol AuthRepository: AnyObject {
    /// Authenticates and persists the session securely. Throws `AppError`.
    func login(email: String, password: String) async throws -> User
    /// Returns the signed-in user if a valid, unexpired session exists.
    func restoreSession() -> User?
    /// Bearer token for authenticated requests, if signed in.
    var accessToken: String? { get }
    func logout()
}
