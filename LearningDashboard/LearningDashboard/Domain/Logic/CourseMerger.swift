//
//  CourseMerger.swift
//  LearningDashboard
//
//  Conflict resolution between server data and the local cache.
//
//  Lesson completion is *monotonic* (a lesson is never "un-completed"), so the
//  merge is simply a union: a lesson is complete if either side says so. This
//  means a stale server response can never wipe out progress the user made
//  offline, without needing a real synchronization engine.
//

import Foundation

nonisolated enum CourseMerger {

    /// Server owns course metadata; completion count is the max of both sides.
    static func merge(remote: Course, local: Course?) -> Course {
        guard let local, local.id == remote.id else { return remote }
        let localCompleted = min(local.completedLessons, remote.totalLessons)
        return Course(
            id: remote.id,
            title: remote.title,
            instructor: remote.instructor,
            totalLessons: remote.totalLessons,
            completedLessons: max(remote.completedLessons, localCompleted)
        )
    }

    /// Server owns the lesson list (titles, order, membership); completion is a union.
    static func mergeLessons(remote: [Lesson], local: [Lesson]) -> [Lesson] {
        let locallyCompleted = Set(local.filter(\.isCompleted).map(\.id))
        return remote
            .map { lesson in
                var merged = lesson
                merged.isCompleted = lesson.isCompleted || locallyCompleted.contains(lesson.id)
                return merged
            }
            .sorted { $0.order < $1.order }
    }
}
