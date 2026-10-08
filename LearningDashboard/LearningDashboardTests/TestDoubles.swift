//
//  TestDoubles.swift
//  LearningDashboardTests
//
//  Hand-written fakes at the I/O boundaries only. Repositories and ViewModels
//  under test are the real production classes.
//

import Foundation
@testable import LearningDashboard

@MainActor
final class StubCourseRemote: CourseRemoteDataSource {
    var coursesResult: Result<[CourseDTO], AppError> = .success([])
    var lessonsResult: [Int: Result<[LessonDTO], AppError>] = [:]
    /// When set, `markLessonCompleted` fails with this error.
    var completeLessonError: AppError?
    private(set) var completeLessonCalls: [PendingLessonCompletion] = []

    func fetchCourses() async throws -> [CourseDTO] {
        try coursesResult.get()
    }

    func fetchLessons(courseId: Int) async throws -> [LessonDTO] {
        try (lessonsResult[courseId] ?? .failure(.notFound)).get()
    }

    func markLessonCompleted(courseId: Int, lessonId: Int) async throws {
        completeLessonCalls.append(PendingLessonCompletion(courseId: courseId, lessonId: lessonId))
        if let completeLessonError { throw completeLessonError }
    }
}

@MainActor
final class StubConnectivity: ConnectivityMonitoring {
    var isConnected = true
}

@MainActor
final class SpyAuthRepository: AuthRepository {
    private(set) var loginCallCount = 0
    var accessToken: String? { nil }

    func login(email: String, password: String) async throws -> User {
        loginCallCount += 1
        return User(id: "1", name: "Test", email: email)
    }

    func restoreSession() -> User? { nil }
    func logout() {}
}

nonisolated enum Fixtures {
    /// A 4-lesson course at 25% (1 of 4 lessons done).
    static let pythonDTO = CourseDTO(id: 1, title: "Python Programming", instructor: "John Smith", progress: 25, lessons: 4)
    static let genAIDTO = CourseDTO(id: 2, title: "Generative AI", instructor: "Sarah Williams", progress: 40, lessons: 16)

    static func lessons(courseId: Int, total: Int, completed: Int) -> [LessonDTO] {
        (1...total).map { index in
            LessonDTO(id: courseId * 100 + index, title: "Lesson \(index)", order: index, isCompleted: index <= completed)
        }
    }
}
