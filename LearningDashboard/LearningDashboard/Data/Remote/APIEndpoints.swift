//
//  APIEndpoints.swift
//  LearningDashboard
//
//  The API surface in one place.
//

import Foundation

nonisolated enum APIEndpoints {
    static func login(_ request: LoginRequestDTO) throws -> Endpoint {
        Endpoint(method: .post, path: "auth/login", body: try JSONEncoder().encode(request), requiresAuth: false)
    }

    static func courses() -> Endpoint {
        Endpoint(method: .get, path: "courses")
    }

    static func lessons(courseId: Int) -> Endpoint {
        Endpoint(method: .get, path: "courses/\(courseId)/lessons")
    }

    static func completeLesson(courseId: Int, lessonId: Int) -> Endpoint {
        Endpoint(method: .post, path: "courses/\(courseId)/lessons/\(lessonId)/complete")
    }
}
