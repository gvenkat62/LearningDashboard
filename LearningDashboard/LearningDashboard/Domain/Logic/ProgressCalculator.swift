//
//  ProgressCalculator.swift
//  LearningDashboard
//
//  Single source of truth for how course progress is computed.
//

import Foundation

nonisolated enum ProgressCalculator {

    /// Completion percentage in 0...100, rounded to the nearest whole number.
    /// Defensive against bad data: zero/negative totals yield 0 and the
    /// completed count is clamped into `0...total`.
    static func percentage(completed: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clamped = min(max(completed, 0), total)
        return Int((Double(clamped) / Double(total) * 100).rounded())
    }

    /// Converts a server-reported percentage back into a lesson count.
    ///
    /// The list endpoint only reports `progress` + `lessons`, but the app models
    /// progress as completed/total so that it stays consistent with the lesson list.
    /// (e.g. 40% of 16 lessons → 6 lessons → displayed as 38%.)
    static func completedLessons(forPercentage percentage: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clampedPercentage = min(max(percentage, 0), 100)
        return Int((Double(clampedPercentage) / 100 * Double(total)).rounded())
    }
}
