//
//  CourseLocalDataSource.swift
//  LearningDashboard
//
//  Persistence contract. Deliberately "dumb": it stores and returns what it is
//  given. All merge/progress rules live in the Domain + Repository so they are
//  identical regardless of the storage engine (SwiftData, in-memory, SQLite…).
//

import Foundation

protocol CourseLocalDataSource: AnyObject {
    func courses() throws -> [Course]
    /// Upserts the given courses (preserving order) and deletes any not in the list.
    func replaceCourses(_ courses: [Course], syncedAt: Date) throws
    /// Upserts a single course summary.
    func saveCourse(_ course: Course) throws
    func lastSyncedAt() throws -> Date?

    func lessons(courseId: Int) throws -> [Lesson]
    /// Upserts lessons for a course, removing ones no longer present.
    /// Local-only flags (pending sync) are preserved.
    func saveLessons(_ lessons: [Lesson], courseId: Int) throws
    func markLessonCompleted(lessonId: Int, courseId: Int, pendingSync: Bool) throws
    func pendingCompletions() throws -> [PendingLessonCompletion]
    func clearPendingSync(lessonId: Int) throws

    func removeAll() throws
}
