//
//  DefaultCourseRepository.swift
//  LearningDashboard
//
//  Coordinates the remote API and the local cache.
//
//  Reads:  network-first, cache fallback. Fresh data is merged with local state
//          and written through to the cache; on any network failure (except an
//          auth failure) the cached copy is returned and labelled as such.
//  Writes: local-first. A lesson completion is persisted before the network
//          call, flagged `pendingSync`, and pushed later if the call fails.
//
//  Concurrency note: the repository runs on the main actor (project default).
//  Every read-merge-write sequence below happens *after* the last `await`, so it
//  executes atomically with respect to other main-actor work and can't interleave
//  with a concurrent completion or prefetch.
//

import Foundation
import OSLog

final class DefaultCourseRepository: CourseRepository {
    private let remote: CourseRemoteDataSource
    private let local: CourseLocalDataSource
    private let now: () -> Date
    private var isSyncing = false

    init(remote: CourseRemoteDataSource, local: CourseLocalDataSource, now: @escaping () -> Date = Date.init) {
        self.remote = remote
        self.local = local
        self.now = now
    }

    // MARK: Courses

    func fetchCourses() async throws -> CoursesResult {
        await syncPendingCompletions()

        let remoteCourses: [Course]
        do {
            remoteCourses = try await remote.fetchCourses().map { CourseMapper.toDomain($0) }
        } catch {
            return try cachedCoursesFallback(for: AppError(error))
        }

        let localById = Dictionary(cachedCourses().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let merged = remoteCourses.map { CourseMerger.merge(remote: $0, local: localById[$0.id]) }
        do {
            try local.replaceCourses(merged, syncedAt: now())
        } catch {
            // A cache write failure shouldn't hide fresh data from the user.
            Log.repository.error("Failed to cache courses; continuing with network data")
        }
        return CoursesResult(courses: merged, origin: .remote)
    }

    func cachedCourses() -> [Course] {
        do {
            return try local.courses()
        } catch {
            Log.repository.error("Failed to read cached courses")
            return []
        }
    }

    private func cachedCoursesFallback(for error: AppError) throws -> CoursesResult {
        // Auth failures must surface (to force re-login) and cancellations are not
        // failures at all — neither should be masked by stale data.
        guard !error.shouldBypassCache else { throw error }
        let cached = cachedCourses()
        guard !cached.isEmpty else { throw error }
        let reason = String(describing: error)
        Log.repository.notice("Serving \(cached.count) cached courses (\(reason, privacy: .public))")
        return CoursesResult(courses: cached, origin: .cache(lastUpdated: lastSyncDate(), reason: error))
    }

    // MARK: Course detail

    func fetchCourseDetail(for course: Course) async throws -> CourseDetailResult {
        let remoteLessons: [Lesson]
        do {
            remoteLessons = try await remote.fetchLessons(courseId: course.id).map { CourseMapper.toDomain($0) }
        } catch {
            let appError = AppError(error)
            guard !appError.shouldBypassCache else { throw appError }
            let cached = (try? local.lessons(courseId: course.id)) ?? []
            guard !cached.isEmpty else { throw appError }
            let detail = CourseDetail(course: latest(course), lessons: cached)
            return CourseDetailResult(detail: detail, origin: .cache(lastUpdated: lastSyncDate(), reason: appError))
        }

        let localLessons = (try? local.lessons(courseId: course.id)) ?? []
        let merged = CourseMerger.mergeLessons(remote: remoteLessons, local: localLessons)
        let detail = CourseDetail(course: latest(course), lessons: merged)
        do {
            try local.saveLessons(detail.lessons, courseId: course.id)
            try local.saveCourse(detail.course)
        } catch {
            Log.repository.error("Failed to cache lessons for course \(course.id)")
        }
        return CourseDetailResult(detail: detail, origin: .remote)
    }

    func prefetchLessons(for courses: [Course]) async {
        for course in courses {
            guard !Task.isCancelled else { return }
            _ = try? await fetchCourseDetail(for: course)
        }
    }

    // MARK: Lesson completion

    func completeLesson(lessonId: Int, courseId: Int) async throws -> LessonCompletionOutcome {
        // 1. Persist locally first, so progress survives no network / app kill.
        try local.markLessonCompleted(lessonId: lessonId, courseId: courseId, pendingSync: true)
        try updateCourseSummary(courseId: courseId)

        // 2. Tell the server. Failure is not an error for the user — it's queued.
        do {
            try await remote.markLessonCompleted(courseId: courseId, lessonId: lessonId)
            try? local.clearPendingSync(lessonId: lessonId)
            return .synced
        } catch {
            let reason = String(describing: AppError(error))
            Log.repository.notice("Lesson \(lessonId) queued for sync (\(reason, privacy: .public))")
            return .pendingSync
        }
    }

    func syncPendingCompletions() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let pending = try? local.pendingCompletions(), !pending.isEmpty else { return }
        Log.repository.info("Syncing \(pending.count) pending lesson completion(s)")

        for item in pending {
            do {
                // Endpoint is idempotent, so a retry after a lost response is safe.
                try await remote.markLessonCompleted(courseId: item.courseId, lessonId: item.lessonId)
                try? local.clearPendingSync(lessonId: item.lessonId)
            } catch {
                let appError = AppError(error)
                // No point hammering the network if we're offline; try again next time.
                if appError == .offline || appError == .timeout { break }
            }
        }
    }

    func clearCache() {
        do {
            try local.removeAll()
        } catch {
            Log.repository.error("Failed to clear cache")
        }
    }

    // MARK: Helpers

    /// Prefer the cached summary (it may include offline progress) over the value
    /// captured when the user navigated.
    private func latest(_ course: Course) -> Course {
        cachedCourses().first { $0.id == course.id } ?? course
    }

    private func updateCourseSummary(courseId: Int) throws {
        let lessons = try local.lessons(courseId: courseId)
        guard let course = cachedCourses().first(where: { $0.id == courseId }) else { return }
        try local.saveCourse(course.withProgress(from: lessons))
    }

    private func lastSyncDate() -> Date? {
        try? local.lastSyncedAt()
    }
}
