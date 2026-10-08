//
//  AppContainer.swift
//  LearningDashboard
//
//  Composition root: the only place that knows concrete types. Everything else
//  receives protocols through initializers (constructor injection), which keeps
//  layers decoupled and makes every class testable with fakes. A DI framework
//  isn't needed at this size.
//

import Foundation
import OSLog
import SwiftData

final class AppContainer {
    let sessionStore: SessionStore
    let networkMonitor: NetworkMonitor
    let mockServer: MockLearningServer

    private let authRepository: AuthRepository
    private let courseRepository: CourseRepository

    init(configuration: AppConfiguration = .fromLaunchArguments()) {
        let networkMonitor = NetworkMonitor()
        let mockServer = MockLearningServer(scenario: configuration.mockScenario)
        let sessionStorage = KeychainSessionStorage()

        if configuration.resetState || Self.isFirstLaunch() {
            // Keychain items survive app deletion; don't resurrect a stale session.
            sessionStorage.clear()
        }

        // Swap `MockHTTPClient` for `URLSessionHTTPClient(baseURL:tokenProvider:)`
        // to talk to a real backend — nothing else changes.
        let httpClient: HTTPClient = MockHTTPClient(server: mockServer, connectivity: networkMonitor)

        let authRepository = DefaultAuthRepository(remote: AuthAPI(client: httpClient), storage: sessionStorage)
        let courseRepository = DefaultCourseRepository(
            remote: CourseAPI(client: httpClient),
            local: Self.makeCourseStore(inMemory: configuration.resetState)
        )

        self.networkMonitor = networkMonitor
        self.mockServer = mockServer
        self.authRepository = authRepository
        self.courseRepository = courseRepository
        self.sessionStore = SessionStore(authRepository: authRepository) { [courseRepository] in
            courseRepository.clearCache()
        }

        // Push offline progress as soon as connectivity returns.
        networkMonitor.onConnectivityChange = { [courseRepository] isConnected in
            guard isConnected else { return }
            Task { await courseRepository.syncPendingCompletions() }
        }
    }

    // MARK: Factories

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(authRepository: authRepository) { [sessionStore] user in
            sessionStore.didSignIn(user)
        }
    }

    func makeDashboardViewModel(user: User) -> CourseDashboardViewModel {
        CourseDashboardViewModel(repository: courseRepository, userName: user.name)
    }

    func makeCourseDetailViewModel(course: Course) -> CourseDetailViewModel {
        CourseDetailViewModel(course: course, repository: courseRepository)
    }

    var debugTools: DebugTools? {
        #if DEBUG
        return DebugTools(networkMonitor: networkMonitor, mockServer: mockServer)
        #else
        return nil
        #endif
    }

    // MARK: Helpers

    private static func makeCourseStore(inMemory: Bool) -> CourseLocalDataSource {
        do {
            let configuration = ModelConfiguration(schema: SwiftDataCourseStore.schema, isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: SwiftDataCourseStore.schema, configurations: [configuration])
            return SwiftDataCourseStore(container: container)
        } catch {
            // Degrade gracefully instead of crashing: the app still works, just without
            // persistence across launches. In production this would also be reported.
            let reason = String(describing: error)
            Log.persistence.fault("Could not open SwiftData store, using in-memory cache: \(reason, privacy: .public)")
            return InMemoryCourseStore()
        }
    }

    private static func isFirstLaunch() -> Bool {
        let key = "hasLaunchedBefore"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}
