//
//  CourseDetailViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@Observable
final class CourseDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case failed(message: String)
    }

    enum Notice: Equatable {
        case offline(lastUpdated: Date?)
        case pendingSync
        case error(message: String)
    }

    private(set) var state: State = .loading
    /// Available immediately (from navigation) so the header renders while lessons load.
    private(set) var course: Course
    private(set) var lessons: [Lesson] = []
    private(set) var notice: Notice?

    @ObservationIgnored private let repository: CourseRepository
    @ObservationIgnored private var inFlightLessonIds: Set<Int> = []

    init(course: Course, repository: CourseRepository) {
        self.course = course
        self.repository = repository
    }

    var completedCount: Int { course.completedLessons }

    func load() async {
        if lessons.isEmpty { state = .loading }
        do {
            let result = try await repository.fetchCourseDetail(for: course)
            apply(result.detail)
            state = .loaded
            if case .cache(let lastUpdated, _) = result.origin {
                notice = .offline(lastUpdated: lastUpdated)
            } else if notice != .pendingSync {
                notice = nil
            }
        } catch {
            let appError = AppError(error)
            guard appError != .cancelled else { return }
            if lessons.isEmpty {
                state = .failed(message: appError == .offline
                    ? "Lessons for this course haven't been downloaded yet. Connect to the internet and try again."
                    : appError.message)
            } else {
                notice = .error(message: appError.message)
            }
        }
    }

    /// Optimistic update: the UI changes instantly; the repository persists locally
    /// first, so the only failure that needs rolling back is a local write failure.
    func markCompleted(_ lesson: Lesson) async {
        guard state == .loaded, !lesson.isCompleted, !inFlightLessonIds.contains(lesson.id) else { return }
        inFlightLessonIds.insert(lesson.id)
        defer { inFlightLessonIds.remove(lesson.id) }

        apply(currentDetail.settingLesson(lesson.id, completed: true))

        do {
            let outcome = try await repository.completeLesson(lessonId: lesson.id, courseId: course.id)
            notice = outcome == .pendingSync ? .pendingSync : nil
        } catch {
            apply(currentDetail.settingLesson(lesson.id, completed: false))
            notice = .error(message: AppError(error).message)
        }
    }

    private var currentDetail: CourseDetail {
        CourseDetail(course: course, lessons: lessons)
    }

    private func apply(_ detail: CourseDetail) {
        course = detail.course
        lessons = detail.lessons
    }
}
