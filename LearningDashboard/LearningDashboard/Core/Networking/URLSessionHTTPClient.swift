//
//  URLSessionHTTPClient.swift
//  LearningDashboard
//
//  Production HTTP client. Not used while the app runs against the mock backend,
//  but this is what AppContainer wires in once a real API base URL exists.
//

import Foundation
import OSLog

final class URLSessionHTTPClient: HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, tokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func send(_ endpoint: Endpoint) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiresAuth, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let method = endpoint.method.rawValue
        let path = endpoint.path
        Log.network.debug("→ \(method, privacy: .public) \(path, privacy: .public)")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let mapped = AppError(error)
            let reason = String(describing: mapped)
            Log.network.error("✗ \(path, privacy: .public) transport error: \(reason, privacy: .public)")
            throw mapped
        }

        guard let http = response as? HTTPURLResponse else { throw AppError.unknown }
        let statusCode = http.statusCode
        Log.network.debug("← \(statusCode) \(path, privacy: .public)")
        return try HTTPResponseValidator.validate(statusCode: http.statusCode, data: data)
    }
}
