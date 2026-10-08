//
//  Logging.swift
//  LearningDashboard
//
//  Unified logging (os.Logger): zero-cost when not collected, viewable in Console.app,
//  and supports privacy redaction so PII never reaches device logs in release builds.
//  Filter in Console with: subsystem:com.Venkat.LearningDashboard
//

import Foundation
import OSLog

nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "LearningDashboard"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let repository = Logger(subsystem: subsystem, category: "repository")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
