//
//  MockHTTPClient.swift
//  LearningDashboard
//
//  Drop-in HTTPClient that routes requests to MockLearningServer instead of the
//  network, while behaving like a real network: latency, and a genuine offline
//  failure when the device has no connectivity (so turning off Wi-Fi exercises
//  the real offline code path).
//

import Foundation
import OSLog

final class MockHTTPClient: HTTPClient {
    private let server: MockLearningServer
    private let connectivity: ConnectivityMonitoring
    private let latency: Duration

    init(server: MockLearningServer, connectivity: ConnectivityMonitoring, latency: Duration = .milliseconds(700)) {
        self.server = server
        self.connectivity = connectivity
        self.latency = latency
    }

    func send(_ endpoint: Endpoint) async throws -> Data {
        let method = endpoint.method.rawValue
        let path = endpoint.path
        Log.network.debug("→ [mock] \(method, privacy: .public) \(path, privacy: .public)")

        try await Task.sleep(for: latency)
        guard connectivity.isConnected else {
            Log.network.debug("✗ [mock] \(path, privacy: .public) offline")
            throw AppError.offline
        }

        let response = server.handle(endpoint)
        let statusCode = response.statusCode
        Log.network.debug("← [mock] \(statusCode) \(path, privacy: .public)")
        return try HTTPResponseValidator.validate(statusCode: response.statusCode, data: response.body)
    }
}
