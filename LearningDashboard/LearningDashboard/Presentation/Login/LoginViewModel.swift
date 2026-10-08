//
//  LoginViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@Observable
final class LoginViewModel {
    var email = "" {
        didSet { fieldsDidChange() }
    }
    var password = "" {
        didSet { fieldsDidChange() }
    }

    private(set) var emailError: String?
    private(set) var passwordError: String?
    /// Request-level error (bad credentials, offline…), shown as a banner.
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    /// Field errors appear only after the first submit, then update live.
    @ObservationIgnored private var hasAttemptedSubmit = false
    @ObservationIgnored private let authRepository: AuthRepository
    @ObservationIgnored private let onLoginSuccess: (User) -> Void

    init(authRepository: AuthRepository, onLoginSuccess: @escaping (User) -> Void) {
        self.authRepository = authRepository
        self.onLoginSuccess = onLoginSuccess
    }

    func login() async {
        guard !isLoading else { return }   // guards against double taps
        hasAttemptedSubmit = true
        guard validate() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await authRepository.login(email: email, password: password)
            onLoginSuccess(user)
        } catch {
            let appError = AppError(error)
            guard appError != .cancelled else { return }
            errorMessage = appError.message
        }
    }

    @discardableResult
    private func validate() -> Bool {
        emailError = CredentialsValidator.validateEmail(email)?.message
        passwordError = CredentialsValidator.validatePassword(password)?.message
        return emailError == nil && passwordError == nil
    }

    private func fieldsDidChange() {
        errorMessage = nil
        if hasAttemptedSubmit { validate() }
    }
}
