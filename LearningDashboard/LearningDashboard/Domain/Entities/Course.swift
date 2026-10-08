//
//  Course.swift
//  LearningDashboard
//
//  Domain entities. Pure value types with no framework dependencies, so they can
//  be used from any layer (and any isolation domain) and are trivial to test.
//

import Foundation

nonisolated struct Course: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let instructor: String
    let totalLessons: Int
    let completedLessons: Int

    /// Progress is *derived* from lesson counts rather than stored, so it can never
    /// drift out of sync with the lessons the user has actually completed.
    var progress: Int {
        ProgressCalculator.percentage(completed: completedLessons, total: totalLessons)
    }

    /// Returns a copy whose counts reflect the given lesson list.
    func withProgress(from lessons: [Lesson]) -> Course {
        Course(
            id: id,
            title: title,
            instructor: instructor,
            totalLessons: lessons.count,
            completedLessons: lessons.filter(\.isCompleted).count
        )
    }
}

nonisolated struct Lesson: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let order: Int
    var isCompleted: Bool
}

nonisolated struct CourseDetail: Hashable, Sendable {
    let course: Course
    let lessons: [Lesson]

    init(course: Course, lessons: [Lesson]) {
        let sorted = lessons.sorted { $0.order < $1.order }
        self.course = course.withProgress(from: sorted)
        self.lessons = sorted
    }

    /// Business rule: completing a lesson is idempotent and recalculates course progress.
    func settingLesson(_ lessonId: Int, completed: Bool) -> CourseDetail {
        let updated = lessons.map { lesson -> Lesson in
            guard lesson.id == lessonId else { return lesson }
            var copy = lesson
            copy.isCompleted = completed
            return copy
        }
        return CourseDetail(course: course, lessons: updated)
    }
}

/// A completion recorded locally that the server has not acknowledged yet.
nonisolated struct PendingLessonCompletion: Hashable, Sendable {
    let courseId: Int
    let lessonId: Int
}
