//
//  DefaultAuthRepository.swift
//  LearningDashboard
//

import Foundation
import OSLog

final class DefaultAuthRepository: AuthRepository {
    private let remote: AuthRemoteDataSource
    private let storage: SessionStorage
    private let now: () -> Date

    init(remote: AuthRemoteDataSource, storage: SessionStorage, now: @escaping () -> Date = Date.init) {
        self.remote = remote
        self.storage = storage
        self.now = now
    }

    func login(email: String, password: String) async throws -> User {
        let request = LoginRequestDTO(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        let response: LoginResponseDTO
        do {
            response = try await remote.login(request)
        } catch AppError.unauthorized {
            // On the login endpoint a 401 means bad credentials, not an expired session.
            throw AppError.invalidCredentials
        } catch {
            throw AppError(error)
        }

        let session = AuthMapper.toDomain(response, now: now())
        try storage.save(session)
        Log.auth.info("Signed in")
        return session.user
    }

    func restoreSession() -> User? {
        guard let session = storage.load() else { return nil }
        guard session.isValid(at: now()) else {
            // Production: attempt a refresh with `session.refreshToken` before giving up.
            storage.clear()
            return nil
        }
        return session.user
    }

    var accessToken: String? {
        storage.load()?.accessToken
    }

    func logout() {
        storage.clear()
        Log.auth.info("Signed out")
    }
}
