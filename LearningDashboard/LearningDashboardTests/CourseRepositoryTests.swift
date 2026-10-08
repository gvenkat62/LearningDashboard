//
//  CourseRepositoryTests.swift
//  LearningDashboardTests
//
//  The offline behaviour is the riskiest logic in the app, so it gets the most
//  thorough tests: real repository + real in-memory store, fake network only.
//

import Foundation
import Testing
@testable import LearningDashboard

@MainActor
@Suite("CourseRepository offline behaviour")
struct CourseRepositoryTests {
    let remote = StubCourseRemote()
    let store = InMemoryCourseStore()
    let syncDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSUT() -> DefaultCourseRepository {
        DefaultCourseRepository(remote: remote, local: store, now: { [syncDate] in syncDate })
    }

    @Test("Previously loaded courses are served from cache when the network is unavailable")
    func servesCachedCoursesWhenOffline() async throws {
        let sut = makeSUT()
        remote.coursesResult = .success([Fixtures.pythonDTO, Fixtures.genAIDTO])
        let online = try await sut.fetchCourses()
        #expect(online.origin == .remote)

        remote.coursesResult = .failure(.offline)
        let offline = try await sut.fetchCourses()

        #expect(offline.courses == online.courses)
        #expect(offline.origin == .cache(lastUpdated: syncDate, reason: .offline))
    }

    @Test("With no cache, the network error is surfaced so the UI can show an error state")
    func failsWhenOfflineWithEmptyCache() async {
        let sut = makeSUT()
        remote.coursesResult = .failure(.offline)

        await #expect(throws: AppError.offline) {
            try await sut.fetchCourses()
        }
    }

    @Test("An expired session is never masked by cached data")
    func unauthorizedBypassesCache() async throws {
        let sut = makeSUT()
        remote.coursesResult = .success([Fixtures.pythonDTO])
        _ = try await sut.fetchCourses()

        remote.coursesResult = .failure(.unauthorized)
        await #expect(throws: AppError.unauthorized) {
            try await sut.fetchCourses()
        }
    }

    @Test("A lesson completed offline updates progress immediately, survives a stale server response, and syncs later")
    func offlineCompletionIsPersistedAndSynced() async throws {
        let sut = makeSUT()
        let python = Fixtures.pythonDTO // 1 of 4 lessons complete → 25%
        remote.coursesResult = .success([python])
        remote.lessonsResult[python.id] = .success(Fixtures.lessons(courseId: python.id, total: 4, completed: 1))

        let course = try #require(try await sut.fetchCourses().courses.first)
        let detail = try await sut.fetchCourseDetail(for: course).detail
        #expect(detail.course.progress == 25)

        // Go offline and complete lesson 2.
        remote.completeLessonError = .offline
        let outcome = try await sut.completeLesson(lessonId: 102, courseId: python.id)

        #expect(outcome == .pendingSync)
        #expect(sut.cachedCourses().first?.progress == 50)
        #expect(try store.lessons(courseId: python.id).filter(\.isCompleted).map(\.id) == [101, 102])
        #expect(try store.pendingCompletions() == [PendingLessonCompletion(courseId: python.id, lessonId: 102)])

        // Back online. The server still reports the old 25% because it never
        // received the completion.
        remote.completeLessonError = nil
        let refreshed = try await sut.fetchCourses()

        #expect(remote.completeLessonCalls.last == PendingLessonCompletion(courseId: python.id, lessonId: 102))
        #expect(try store.pendingCompletions().isEmpty)
        #expect(refreshed.courses.first?.progress == 50, "Stale server data must not erase local progress")
    }
}
