//
//  HTTPClient.swift
//  LearningDashboard
//
//  Transport abstraction. Remote data sources describe *what* to call (Endpoint);
//  the HTTPClient decides *how*. Swapping the mock backend for a real one is a
//  one-line change in AppContainer — no data source or repository changes.
//

import Foundation
import OSLog

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

nonisolated struct Endpoint: Sendable {
    let method: HTTPMethod
    let path: String
    var body: Data? = nil
    var requiresAuth: Bool = true
}

protocol HTTPClient: AnyObject {
    /// Performs the request and returns the body of a 2xx response. Throws `AppError`.
    func send(_ endpoint: Endpoint) async throws -> Data
}

extension HTTPClient {
    func send<Response: Decodable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response {
        let data = try await send(endpoint)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let typeName = String(describing: Response.self)
            let path = endpoint.path
            let reason = String(describing: error)
            Log.network.error("Decoding \(typeName, privacy: .public) failed for \(path, privacy: .public): \(reason, privacy: .public)")
            throw AppError.decoding
        }
    }
}

/// Shared status-code → AppError mapping so the real and mock clients behave identically.
nonisolated enum HTTPResponseValidator {
    static func validate(statusCode: Int, data: Data) throws -> Data {
        switch statusCode {
        case 200..<300: return data
        case 401, 403: throw AppError.unauthorized
        case 404: throw AppError.notFound
        case 408: throw AppError.timeout
        default: throw AppError.server(statusCode: statusCode)
        }
    }
}
