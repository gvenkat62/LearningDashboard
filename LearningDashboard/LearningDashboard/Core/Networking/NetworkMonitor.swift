//
//  NetworkMonitor.swift
//  LearningDashboard
//
//  Reachability via NWPathMonitor. Note: reachability is only a hint — the app never
//  *relies* on it to decide whether to call the network; real request failures
//  drive the offline fallback. It is used to (a) make the mock backend behave like
//  a real one when Wi-Fi is off and (b) trigger a sync when connectivity returns.
//

import Foundation
import OSLog
import Network
import Observation

protocol ConnectivityMonitoring: AnyObject {
    var isConnected: Bool { get }
}

@Observable
final class NetworkMonitor: ConnectivityMonitoring {
    private(set) var isPathSatisfied = true
    /// Debug-only switch so offline behaviour can be tested without touching Wi-Fi.
    var isSimulatingOffline = false {
        didSet { notifyIfChanged() }
    }

    var isConnected: Bool { isPathSatisfied && !isSimulatingOffline }

    /// Called on the main actor whenever `isConnected` flips.
    @ObservationIgnored var onConnectivityChange: ((Bool) -> Void)?

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var lastReported = true

    init() {
        // The handler runs on a background queue; it is explicitly @Sendable (not
        // main-actor isolated) and hops to the main actor before touching state.
        monitor.pathUpdateHandler = { @Sendable [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isPathSatisfied = satisfied
                self?.notifyIfChanged()
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }

    private func notifyIfChanged() {
        guard isConnected != lastReported else { return }
        let connected = isConnected
        lastReported = connected
        let status = connected ? "online" : "offline"
        Log.network.info("Connectivity changed: \(status, privacy: .public)")
        onConnectivityChange?(connected)
    }
}
