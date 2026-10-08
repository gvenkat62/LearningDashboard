//
//  RemoteDataSources.swift
//  LearningDashboard
//

import Foundation

protocol AuthRemoteDataSource: AnyObject {
    func login(_ request: LoginRequestDTO) async throws -> LoginResponseDTO
}

protocol CourseRemoteDataSource: AnyObject {
    func fetchCourses() async throws -> [CourseDTO]
    func fetchLessons(courseId: Int) async throws -> [LessonDTO]
    func markLessonCompleted(courseId: Int, lessonId: Int) async throws
}

final class AuthAPI: AuthRemoteDataSource {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func login(_ request: LoginRequestDTO) async throws -> LoginResponseDTO {
        try await client.send(APIEndpoints.login(request), as: LoginResponseDTO.self)
    }
}

final class CourseAPI: CourseRemoteDataSource {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func fetchCourses() async throws -> [CourseDTO] {
        try await client.send(APIEndpoints.courses(), as: [CourseDTO].self)
    }

    func fetchLessons(courseId: Int) async throws -> [LessonDTO] {
        try await client.send(APIEndpoints.lessons(courseId: courseId), as: [LessonDTO].self)
    }

    func markLessonCompleted(courseId: Int, lessonId: Int) async throws {
        _ = try await client.send(APIEndpoints.completeLesson(courseId: courseId, lessonId: lessonId))
    }
}
