//
//  CredentialsValidator.swift
//  LearningDashboard
//

import Foundation

nonisolated enum ValidationError: Error, Equatable, Sendable {
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case passwordTooShort(minimum: Int)

    var message: String {
        switch self {
        case .emptyEmail: "Email is required."
        case .invalidEmail: "Enter a valid email address."
        case .emptyPassword: "Password is required."
        case .passwordTooShort(let minimum): "Password must be at least \(minimum) characters."
        }
    }
}

nonisolated enum CredentialsValidator {
    static let minimumPasswordLength = 8

    static func validateEmail(_ email: String) -> ValidationError? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .emptyEmail }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return .invalidEmail }
        return nil
    }

    static func validatePassword(_ password: String) -> ValidationError? {
        guard !password.isEmpty else { return .emptyPassword }
        guard password.count >= minimumPasswordLength else {
            return .passwordTooShort(minimum: minimumPasswordLength)
        }
        return nil
    }
}
