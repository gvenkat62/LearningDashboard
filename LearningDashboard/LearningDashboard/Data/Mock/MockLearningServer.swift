//
//  MockLearningServer.swift
//  LearningDashboard
//
//  A tiny in-process "backend" serving bundled JSON. It speaks the same
//  Endpoint/status-code contract as the real API, so everything above the
//  HTTPClient (data sources, repositories, ViewModels) runs real production code.
//

import Foundation
import OSLog
import Observation

nonisolated enum MockScenario: String, CaseIterable, Identifiable, Sendable {
    case normal
    case empty
    case serverError

    var id: Self { self }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .empty: "Empty course list"
        case .serverError: "Server error (500)"
        }
    }
}

nonisolated struct MockResponse: Sendable {
    let statusCode: Int
    let body: Data

    static func status(_ code: Int) -> MockResponse { MockResponse(statusCode: code, body: Data()) }
}

private nonisolated struct CourseLessonsDTO: Codable, Sendable {
    let courseId: Int
    let lessons: [LessonDTO]
}

@Observable
final class MockLearningServer {
    static let demoEmail = "learner@example.com"
    static let demoPassword = "Password123"

    var scenario: MockScenario

    @ObservationIgnored private var courses: [CourseDTO]
    @ObservationIgnored private var lessonsByCourse: [Int: [LessonDTO]]

    init(scenario: MockScenario = .normal, bundle: Bundle = .main) {
        self.scenario = scenario
        self.courses = Self.loadJSON([CourseDTO].self, named: "courses", bundle: bundle) ?? []
        let groups = Self.loadJSON([CourseLessonsDTO].self, named: "lessons", bundle: bundle) ?? []
        self.lessonsByCourse = Dictionary(groups.map { ($0.courseId, $0.lessons) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Routing

    func handle(_ endpoint: Endpoint) -> MockResponse {
        let parts = endpoint.path.split(separator: "/").map(String.init)

        if endpoint.method == .post, parts == ["auth", "login"] {
            return login(body: endpoint.body)
        }

        guard parts.first == "courses" else { return .status(404) }
        if scenario == .serverError { return .status(500) }

        if endpoint.method == .get, parts == ["courses"] {
            return json(scenario == .empty ? [] : courses)
        }
        if endpoint.method == .get, parts.count == 3, parts[2] == "lessons", let courseId = Int(parts[1]) {
            guard scenario != .empty, let lessons = lessonsByCourse[courseId] else { return .status(404) }
            return json(lessons)
        }
        if endpoint.method == .post, parts.count == 5, parts[2] == "lessons", parts[4] == "complete",
           let courseId = Int(parts[1]), let lessonId = Int(parts[3]) {
            return completeLesson(courseId: courseId, lessonId: lessonId)
        }
        return .status(404)
    }

    // MARK: Handlers

    private func login(body: Data?) -> MockResponse {
        guard let body, let request = try? JSONDecoder().decode(LoginRequestDTO.self, from: body) else {
            return .status(400)
        }
        guard request.email.lowercased() == Self.demoEmail, request.password == Self.demoPassword else {
            return .status(401)
        }
        let response = LoginResponseDTO(
            accessToken: "mock-access-\(UUID().uuidString)",
            refreshToken: "mock-refresh-\(UUID().uuidString)",
            expiresIn: 60 * 60 * 24,
            user: UserDTO(id: "u-1", name: "Alex Learner", email: Self.demoEmail)
        )
        return json(response)
    }

    private func completeLesson(courseId: Int, lessonId: Int) -> MockResponse {
        guard var lessons = lessonsByCourse[courseId],
              let index = lessons.firstIndex(where: { $0.id == lessonId }) else {
            return .status(404)
        }
        let lesson = lessons[index]
        lessons[index] = LessonDTO(id: lesson.id, title: lesson.title, order: lesson.order, isCompleted: true)
        lessonsByCourse[courseId] = lessons

        if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
            let course = courses[courseIndex]
            let completed = lessons.filter(\.isCompleted).count
            courses[courseIndex] = CourseDTO(
                id: course.id, title: course.title, instructor: course.instructor,
                progress: ProgressCalculator.percentage(completed: completed, total: lessons.count),
                lessons: lessons.count
            )
        }
        return .status(204)
    }

    // MARK: Helpers

    private func json<T: Encodable>(_ value: T) -> MockResponse {
        guard let data = try? JSONEncoder().encode(value) else { return .status(500) }
        return MockResponse(statusCode: 200, body: data)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, named name: String, bundle: Bundle) -> T? {
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "MockAPI")
        guard let url, let data = try? Data(contentsOf: url) else {
            Log.network.fault("Mock resource \(name, privacy: .public).json missing from bundle")
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Log.network.fault("Mock resource \(name, privacy: .public).json is malformed")
            return nil
        }
    }
}
