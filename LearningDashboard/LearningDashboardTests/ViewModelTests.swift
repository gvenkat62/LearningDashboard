//
//  ViewModelTests.swift
//  LearningDashboardTests
//

import Foundation
import Testing
@testable import LearningDashboard

@MainActor
@Suite("Course dashboard states")
struct CourseDashboardViewModelTests {
    let remote = StubCourseRemote()
    let store = InMemoryCourseStore()

    private func makeSUT() -> CourseDashboardViewModel {
        CourseDashboardViewModel(
            repository: DefaultCourseRepository(remote: remote, local: store),
            userName: "Test"
        )
    }

    @Test func emptyResponseShowsEmptyState() async {
        let sut = makeSUT()
        remote.coursesResult = .success([])
        await sut.load()
        #expect(sut.state == .empty)
    }

    @Test func failureWithoutCacheShowsErrorState() async {
        let sut = makeSUT()
        remote.coursesResult = .failure(.server(statusCode: 500))
        await sut.load()
        #expect(sut.state == .failed(message: AppError.server(statusCode: 500).message))
    }

    @Test func offlineWithCacheShowsCoursesAndOfflineNotice() async {
        let sut = makeSUT()
        remote.coursesResult = .success([Fixtures.pythonDTO])
        await sut.load()
        guard case .loaded(let courses) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }

        remote.coursesResult = .failure(.offline)
        await sut.refresh()

        #expect(sut.state == .loaded(courses))
        guard case .offline? = sut.notice else {
            Issue.record("Expected offline notice, got \(String(describing: sut.notice))")
            return
        }
    }
}

@MainActor
@Suite("Login")
struct LoginViewModelTests {

    @Test func invalidInputShowsFieldErrorsAndSkipsNetwork() async {
        let repository = SpyAuthRepository()
        let sut = LoginViewModel(authRepository: repository, onLoginSuccess: { _ in })
        sut.email = "not-an-email"
        sut.password = "short"

        await sut.login()

        #expect(sut.emailError == ValidationError.invalidEmail.message)
        #expect(sut.passwordError == ValidationError.passwordTooShort(minimum: 8).message)
        #expect(repository.loginCallCount == 0)
    }

    /// Exercises the full stack below the ViewModel: repository → AuthAPI →
    /// HTTP client → mock server (401) → error mapping.
    @Test func wrongPasswordShowsInvalidCredentials() async {
        let sut = makeIntegratedSUT(onSuccess: { _ in Issue.record("Should not sign in") })
        sut.email = MockLearningServer.demoEmail
        sut.password = "WrongPassword"

        await sut.login()

        #expect(sut.errorMessage == AppError.invalidCredentials.message)
        #expect(sut.isLoading == false)
    }

    @Test func validCredentialsSignInAndStoreSession() async {
        let storage = InMemorySessionStorage()
        var signedInUser: User?
        let sut = makeIntegratedSUT(storage: storage, onSuccess: { signedInUser = $0 })
        sut.email = MockLearningServer.demoEmail
        sut.password = MockLearningServer.demoPassword

        await sut.login()

        #expect(signedInUser?.email == MockLearningServer.demoEmail)
        #expect(storage.load()?.accessToken.isEmpty == false)
        #expect(sut.errorMessage == nil)
    }

    private func makeIntegratedSUT(storage: SessionStorage? = nil,
                                   onSuccess: @escaping (User) -> Void) -> LoginViewModel {
        let storage = storage ?? InMemorySessionStorage()
        let client = MockHTTPClient(server: MockLearningServer(), connectivity: StubConnectivity(), latency: .zero)
        let repository = DefaultAuthRepository(remote: AuthAPI(client: client), storage: storage)
        return LoginViewModel(authRepository: repository, onLoginSuccess: onSuccess)
    }
}
