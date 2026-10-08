//
//  AppConfiguration.swift
//  LearningDashboard
//
//  Runtime switches, read from launch arguments (Scheme ▸ Run ▸ Arguments), e.g.
//    -mockScenario empty        (normal | empty | serverError)
//    -resetState YES            (fresh keychain + in-memory DB, for UI tests)
//

import Foundation

nonisolated struct AppConfiguration: Sendable {
    var mockScenario: MockScenario = .normal
    var resetState: Bool = false

    static func fromLaunchArguments(_ defaults: UserDefaults = .standard) -> AppConfiguration {
        AppConfiguration(
            mockScenario: defaults.string(forKey: "mockScenario").flatMap(MockScenario.init(rawValue:)) ?? .normal,
            resetState: defaults.bool(forKey: "resetState")
        )
    }
}
