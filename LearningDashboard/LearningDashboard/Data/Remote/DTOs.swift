//
//  DTOs.swift
//  LearningDashboard
//
//  Wire formats. Kept separate from domain entities so API changes (renamed
//  fields, new versions) are absorbed by the mappers instead of rippling into
//  ViewModels and Views.
//

import Foundation

nonisolated struct CourseDTO: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let instructor: String
    let progress: Int
    let lessons: Int
}

nonisolated struct LessonDTO: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let order: Int
    let isCompleted: Bool
}

nonisolated struct LoginRequestDTO: Codable, Equatable, Sendable {
    let email: String
    let password: String
}

nonisolated struct LoginResponseDTO: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    /// Seconds until the access token expires.
    let expiresIn: Int
    let user: UserDTO
}

nonisolated struct UserDTO: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let email: String
}
