//
//  LearningDashboardApp.swift
//  LearningDashboard
//
//  Created by Venkat on 10/8/26.
//

import SwiftUI

@main
struct LearningDashboardApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
