//
//  ProgressTests.swift
//  LearningDashboardTests
//

import Testing
@testable import LearningDashboard

struct ProgressCase: Sendable, CustomTestStringConvertible {
    let completed: Int
    let total: Int
    let expected: Int

    var testDescription: String { "\(completed)/\(total) → \(expected)%" }
}

@Suite("Progress calculation")
struct ProgressTests {

    @Test(arguments: [
        ProgressCase(completed: 13, total: 20, expected: 65),
        ProgressCase(completed: 6, total: 16, expected: 38),   // 37.5 rounds half up
        ProgressCase(completed: 1, total: 3, expected: 33),
        ProgressCase(completed: 2, total: 3, expected: 67),
        ProgressCase(completed: 20, total: 20, expected: 100),
        ProgressCase(completed: 0, total: 0, expected: 0),     // no division by zero
        ProgressCase(completed: 25, total: 20, expected: 100), // bad data is clamped
        ProgressCase(completed: -1, total: 10, expected: 0),
    ])
    func percentage(_ testCase: ProgressCase) {
        #expect(ProgressCalculator.percentage(completed: testCase.completed, total: testCase.total) == testCase.expected)
    }

    @Test("Completing a lesson updates status and course progress, and is idempotent")
    func completingLessonRecalculatesProgress() {
        let course = Course(id: 1, title: "Python", instructor: "John Smith", totalLessons: 4, completedLessons: 1)
        let lessons = (1...4).map { Lesson(id: $0, title: "L\($0)", order: $0, isCompleted: $0 == 1) }
        let detail = CourseDetail(course: course, lessons: lessons)

        let updated = detail.settingLesson(2, completed: true)

        #expect(updated.lessons.first { $0.id == 2 }?.isCompleted == true)
        #expect(updated.course.completedLessons == 2)
        #expect(updated.course.progress == 50)
        #expect(updated.settingLesson(2, completed: true) == updated)
    }
}
