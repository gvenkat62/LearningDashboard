//
//  InMemoryCourseStore.swift
//  LearningDashboard
//
//  Same contract as SwiftDataCourseStore, backed by dictionaries.
//  Used by unit tests, SwiftUI previews, and as a fallback if the on-disk
//  store cannot be opened.
//

import Foundation

final class InMemoryCourseStore: CourseLocalDataSource {
    private var orderedCourses: [Course] = []
    private var syncedAt: Date?
    private var lessonsByCourse: [Int: [Lesson]] = [:]
    private var pending: [Int: PendingLessonCompletion] = [:]

    init(courses: [Course] = [], lessons: [Int: [Lesson]] = [:]) {
        self.orderedCourses = courses
        self.lessonsByCourse = lessons
    }

    func courses() throws -> [Course] { orderedCourses }

    func replaceCourses(_ courses: [Course], syncedAt: Date) throws {
        let keptIds = Set(courses.map(\.id))
        for removed in orderedCourses where !keptIds.contains(removed.id) {
            lessonsByCourse[removed.id] = nil
            pending = pending.filter { $0.value.courseId != removed.id }
        }
        orderedCourses = courses
        self.syncedAt = syncedAt
    }

    func saveCourse(_ course: Course) throws {
        if let index = orderedCourses.firstIndex(where: { $0.id == course.id }) {
            orderedCourses[index] = course
        } else {
            orderedCourses.append(course)
        }
    }

    func lastSyncedAt() throws -> Date? { syncedAt }

    func lessons(courseId: Int) throws -> [Lesson] {
        (lessonsByCourse[courseId] ?? []).sorted { $0.order < $1.order }
    }

    func saveLessons(_ lessons: [Lesson], courseId: Int) throws {
        lessonsByCourse[courseId] = lessons
    }

    func markLessonCompleted(lessonId: Int, courseId: Int, pendingSync: Bool) throws {
        guard var lessons = lessonsByCourse[courseId],
              let index = lessons.firstIndex(where: { $0.id == lessonId }) else {
            throw AppError.notFound
        }
        lessons[index].isCompleted = true
        lessonsByCourse[courseId] = lessons
        pending[lessonId] = pendingSync ? PendingLessonCompletion(courseId: courseId, lessonId: lessonId) : nil
    }

    func pendingCompletions() throws -> [PendingLessonCompletion] {
        pending.values.sorted { $0.lessonId < $1.lessonId }
    }

    func clearPendingSync(lessonId: Int) throws {
        pending[lessonId] = nil
    }

    func removeAll() throws {
        orderedCourses = []
        lessonsByCourse = [:]
        pending = [:]
        syncedAt = nil
    }
}
