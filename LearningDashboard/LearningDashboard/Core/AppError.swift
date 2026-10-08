//
//  AppError.swift
//  LearningDashboard
//
//  One error vocabulary for the whole app. Lower layers translate framework errors
//  (URLError, DecodingError, Keychain OSStatus…) into this type so the UI never has
//  to know about transport details.
//

import Foundation

nonisolated enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case invalidCredentials
    case unauthorized
    case notFound
    case server(statusCode: Int)
    case decoding
    case persistence
    case cancelled
    case unknown

    init(_ error: Error) {
        switch error {
        case let appError as AppError:
            self = appError
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost:
                self = .offline
            case .timedOut:
                self = .timeout
            case .cancelled:
                self = .cancelled
            default:
                self = .unknown
            }
        case is DecodingError:
            self = .decoding
        default:
            self = .unknown
        }
    }

    /// User-facing copy. Never leaks technical details.
    var message: String {
        switch self {
        case .offline: "You're offline. Check your connection and try again."
        case .timeout: "The request timed out. Please try again."
        case .invalidCredentials: "Incorrect email or password."
        case .unauthorized: "Your session has expired. Please sign in again."
        case .notFound: "We couldn't find what you were looking for."
        case .server: "Something went wrong on our side. Please try again."
        case .decoding: "We received unexpected data. Please try again later."
        case .persistence: "We couldn't save your data on this device."
        case .cancelled: "The request was cancelled."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

extension AppError {
    /// Errors that must propagate instead of being papered over with cached data.
    nonisolated var shouldBypassCache: Bool {
        self == .unauthorized || self == .cancelled
    }
}

extension AppError: LocalizedError {
    nonisolated var errorDescription: String? { message }
}
