//
//  Mappers.swift
//  LearningDashboard
//

import Foundation

nonisolated enum CourseMapper {
    static func toDomain(_ dto: CourseDTO) -> Course {
        let total = max(dto.lessons, 0)
        return Course(
            id: dto.id,
            title: dto.title,
            instructor: dto.instructor,
            totalLessons: total,
            completedLessons: ProgressCalculator.completedLessons(forPercentage: dto.progress, total: total)
        )
    }

    static func toDomain(_ dto: LessonDTO) -> Lesson {
        Lesson(id: dto.id, title: dto.title, order: dto.order, isCompleted: dto.isCompleted)
    }
}

nonisolated enum AuthMapper {
    static func toDomain(_ dto: LoginResponseDTO, now: Date) -> AuthSession {
        AuthSession(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(dto.expiresIn)),
            user: User(id: dto.user.id, name: dto.user.name, email: dto.user.email)
        )
    }
}
