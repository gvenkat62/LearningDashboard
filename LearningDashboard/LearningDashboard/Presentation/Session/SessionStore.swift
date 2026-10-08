//
//  SessionStore.swift
//  LearningDashboard
//
//  App-wide authentication state. The root view switches on `state`, so login
//  and logout are just state changes — no imperative navigation to unwind.
//

import Foundation
import Observation

@Observable
final class SessionStore {
    enum State: Equatable {
        case signedOut
        case signedIn(User)
    }

    private(set) var state: State

    @ObservationIgnored private let authRepository: AuthRepository
    @ObservationIgnored private let onSignOut: () -> Void

    init(authRepository: AuthRepository, onSignOut: @escaping () -> Void = {}) {
        self.authRepository = authRepository
        self.onSignOut = onSignOut
        self.state = authRepository.restoreSession().map(State.signedIn) ?? .signedOut
    }

    func didSignIn(_ user: User) {
        state = .signedIn(user)
    }

    func signOut() {
        authRepository.logout()
        // Clear user data so the next person on a shared device can't see it.
        onSignOut()
        state = .signedOut
    }
}
