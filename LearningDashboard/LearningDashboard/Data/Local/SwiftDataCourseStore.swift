//
//  SwiftDataCourseStore.swift
//  LearningDashboard
//
//  SwiftData (SQLite under the hood) implementation of the offline cache.
//  @Model types never leave this file — the rest of the app sees only domain
//  structs, so the storage engine can be swapped without touching other layers.
//

import Foundation
import OSLog
import SwiftData

@Model
final class CourseEntity {
    @Attribute(.unique) var courseId: Int
    var title: String
    var instructor: String
    var totalLessons: Int
    var completedLessons: Int
    var sortIndex: Int
    var lastSyncedAt: Date?

    init(course: Course, sortIndex: Int, lastSyncedAt: Date?) {
        self.courseId = course.id
        self.title = course.title
        self.instructor = course.instructor
        self.totalLessons = course.totalLessons
        self.completedLessons = course.completedLessons
        self.sortIndex = sortIndex
        self.lastSyncedAt = lastSyncedAt
    }

    func update(from course: Course) {
        title = course.title
        instructor = course.instructor
        totalLessons = course.totalLessons
        completedLessons = course.completedLessons
    }

    var domain: Course {
        Course(id: courseId, title: title, instructor: instructor,
               totalLessons: totalLessons, completedLessons: completedLessons)
    }
}

@Model
final class LessonEntity {
    @Attribute(.unique) var lessonId: Int
    var courseId: Int
    var title: String
    var order: Int
    var isCompleted: Bool
    /// Completed locally but not yet acknowledged by the server.
    var pendingSync: Bool

    init(lesson: Lesson, courseId: Int) {
        self.lessonId = lesson.id
        self.courseId = courseId
        self.title = lesson.title
        self.order = lesson.order
        self.isCompleted = lesson.isCompleted
        self.pendingSync = false
    }

    var domain: Lesson {
        Lesson(id: lessonId, title: title, order: order, isCompleted: isCompleted)
    }
}

final class SwiftDataCourseStore: CourseLocalDataSource {
    static let schema = Schema([CourseEntity.self, LessonEntity.self])

    /// The container must outlive its context, so the store retains it.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: Courses

    func courses() throws -> [Course] {
        try perform {
            let descriptor = FetchDescriptor<CourseEntity>(sortBy: [SortDescriptor(\.sortIndex)])
            return try context.fetch(descriptor).map { $0.domain }
        }
    }

    func replaceCourses(_ courses: [Course], syncedAt: Date) throws {
        try perform {
            let existing = try context.fetch(FetchDescriptor<CourseEntity>())
            var byId = Dictionary(existing.map { ($0.courseId, $0) }, uniquingKeysWith: { first, _ in first })

            for (index, course) in courses.enumerated() {
                if let entity = byId.removeValue(forKey: course.id) {
                    entity.update(from: course)
                    entity.sortIndex = index
                    entity.lastSyncedAt = syncedAt
                } else {
                    context.insert(CourseEntity(course: course, sortIndex: index, lastSyncedAt: syncedAt))
                }
            }

            // Courses the server no longer returns (e.g. unenrolled) are removed with their lessons.
            for (removedId, entity) in byId {
                context.delete(entity)
                try context.delete(model: LessonEntity.self, where: #Predicate<LessonEntity> { $0.courseId == removedId })
            }
            try context.save()
        }
    }

    func saveCourse(_ course: Course) throws {
        try perform {
            if let entity = try courseEntity(id: course.id) {
                entity.update(from: course)
            } else {
                let count = try context.fetchCount(FetchDescriptor<CourseEntity>())
                context.insert(CourseEntity(course: course, sortIndex: count, lastSyncedAt: nil))
            }
            try context.save()
        }
    }

    func lastSyncedAt() throws -> Date? {
        try perform {
            try context.fetch(FetchDescriptor<CourseEntity>()).compactMap { $0.lastSyncedAt }.max()
        }
    }

    // MARK: Lessons

    func lessons(courseId: Int) throws -> [Lesson] {
        try perform { try lessonEntities(courseId: courseId).map { $0.domain } }
    }

    func saveLessons(_ lessons: [Lesson], courseId: Int) throws {
        try perform {
            var byId = Dictionary(try lessonEntities(courseId: courseId).map { ($0.lessonId, $0) },
                                  uniquingKeysWith: { first, _ in first })
            for lesson in lessons {
                if let entity = byId.removeValue(forKey: lesson.id) {
                    entity.title = lesson.title
                    entity.order = lesson.order
                    entity.isCompleted = lesson.isCompleted
                    // pendingSync intentionally untouched.
                } else {
                    context.insert(LessonEntity(lesson: lesson, courseId: courseId))
                }
            }
            for stale in byId.values {
                context.delete(stale)
            }
            try context.save()
        }
    }

    func markLessonCompleted(lessonId: Int, courseId: Int, pendingSync: Bool) throws {
        try perform {
            guard let entity = try lessonEntity(id: lessonId) else { throw AppError.notFound }
            entity.isCompleted = true
            entity.pendingSync = pendingSync
            try context.save()
        }
    }

    func pendingCompletions() throws -> [PendingLessonCompletion] {
        try perform {
            let descriptor = FetchDescriptor<LessonEntity>(predicate: #Predicate<LessonEntity> { $0.pendingSync == true })
            return try context.fetch(descriptor).map {
                PendingLessonCompletion(courseId: $0.courseId, lessonId: $0.lessonId)
            }
        }
    }

    func clearPendingSync(lessonId: Int) throws {
        try perform {
            guard let entity = try lessonEntity(id: lessonId) else { return }
            entity.pendingSync = false
            try context.save()
        }
    }

    func removeAll() throws {
        try perform {
            try context.delete(model: LessonEntity.self)
            try context.delete(model: CourseEntity.self)
            try context.save()
        }
    }

    // MARK: Helpers

    private func courseEntity(id: Int) throws -> CourseEntity? {
        var descriptor = FetchDescriptor<CourseEntity>(predicate: #Predicate<CourseEntity> { $0.courseId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func lessonEntity(id: Int) throws -> LessonEntity? {
        var descriptor = FetchDescriptor<LessonEntity>(predicate: #Predicate<LessonEntity> { $0.lessonId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func lessonEntities(courseId: Int) throws -> [LessonEntity] {
        let descriptor = FetchDescriptor<LessonEntity>(
            predicate: #Predicate<LessonEntity> { $0.courseId == courseId },
            sortBy: [SortDescriptor(\.order)]
        )
        return try context.fetch(descriptor)
    }

    /// Normalises storage errors into `AppError.persistence` and rolls back
    /// unsaved changes so a failed write never leaves the context half-modified.
    private func perform<T>(_ work: () throws -> T) throws -> T {
        do {
            return try work()
        } catch let error as AppError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            let reason = String(describing: error)
            Log.persistence.error("SwiftData operation failed: \(reason, privacy: .public)")
            throw AppError.persistence
        }
    }
}
