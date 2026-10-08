//
//  CourseRepository.swift
//  LearningDashboard
//

import Foundation

/// Where the returned data came from, so the UI can be honest about freshness.
nonisolated enum DataOrigin: Equatable, Sendable {
    case remote
    /// Served from the local cache because the network request failed.
    case cache(lastUpdated: Date?, reason: AppError)
}

nonisolated struct CoursesResult: Equatable, Sendable {
    let courses: [Course]
    let origin: DataOrigin
}

nonisolated struct CourseDetailResult: Equatable, Sendable {
    let detail: CourseDetail
    let origin: DataOrigin
}

nonisolated enum LessonCompletionOutcome: Equatable, Sendable {
    /// Saved locally and acknowledged by the server.
    case synced
    /// Saved locally; will be pushed to the server on the next successful sync.
    case pendingSync
}

protocol CourseRepository: AnyObject {
    /// Network-first with cache fallback. Throws only when both fail / cache is empty.
    func fetchCourses() async throws -> CoursesResult
    /// Cached courses only — cheap, synchronous read used to refresh the UI.
    func cachedCourses() -> [Course]
    func fetchCourseDetail(for course: Course) async throws -> CourseDetailResult
    /// Local-first: persists immediately, then tries to notify the server.
    func completeLesson(lessonId: Int, courseId: Int) async throws -> LessonCompletionOutcome
    /// Best effort: downloads lessons so course details are also available offline.
    func prefetchLessons(for courses: [Course]) async
    /// Pushes completions recorded while offline.
    func syncPendingCompletions() async
    func clearCache()
}
