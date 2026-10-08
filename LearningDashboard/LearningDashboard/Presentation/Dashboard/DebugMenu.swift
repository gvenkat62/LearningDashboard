//
//  DebugMenu.swift
//  LearningDashboard
//
//  DEBUG-only controls to exercise every screen state without editing code:
//  simulate offline, force an empty list, or force a server error.
//

import SwiftUI

struct DebugTools {
    let networkMonitor: NetworkMonitor
    let mockServer: MockLearningServer
}

#if DEBUG
struct DebugMenu: View {
    @Bindable private var networkMonitor: NetworkMonitor
    @Bindable private var mockServer: MockLearningServer

    init(tools: DebugTools) {
        _networkMonitor = Bindable(tools.networkMonitor)
        _mockServer = Bindable(tools.mockServer)
    }

    var body: some View {
        Section("Debug") {
            Toggle("Simulate Offline", systemImage: "wifi.slash", isOn: $networkMonitor.isSimulatingOffline)
            Picker("Mock API", systemImage: "server.rack", selection: $mockServer.scenario) {
                ForEach(MockScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
#endif
