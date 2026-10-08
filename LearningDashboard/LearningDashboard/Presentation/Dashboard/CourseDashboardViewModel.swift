//
//  CourseDashboardViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@Observable
final class CourseDashboardViewModel {
    /// Mutually exclusive screen states — the view renders exactly one.
    enum State: Equatable {
        case loading
        case loaded([Course])
        case empty
        case failed(message: String)
    }

    /// Non-blocking notice shown above content (content is still usable).
    enum Notice: Equatable {
        case offline(lastUpdated: Date?)
        case refreshFailed(message: String, lastUpdated: Date?)
    }

    private(set) var state: State = .loading
    private(set) var notice: Notice?
    let userName: String

    @ObservationIgnored private let repository: CourseRepository
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?

    init(repository: CourseRepository, userName: String) {
        self.repository = repository
        self.userName = userName
    }

    /// Initial load; subsequent appearances (e.g. back from details) only
    /// re-read the local cache so updated progress shows instantly.
    func onAppear() async {
        if hasLoaded {
            reloadFromCache()
        } else {
            await load()
        }
    }

    func load() async {
        if case .loaded = state {} else { state = .loading }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    func retry() async {
        state = .loading
        notice = nil
        await fetch()
    }

    func reloadFromCache() {
        guard case .loaded = state else { return }
        let cached = repository.cachedCourses()
        if !cached.isEmpty { state = .loaded(cached) }
    }

    private func fetch() async {
        do {
            let result = try await repository.fetchCourses()
            hasLoaded = true
            state = result.courses.isEmpty ? .empty : .loaded(result.courses)

            switch result.origin {
            case .remote:
                notice = nil
                prefetchDetails(for: result.courses)
            case .cache(let lastUpdated, let reason):
                notice = reason == .offline
                    ? .offline(lastUpdated: lastUpdated)
                    : .refreshFailed(message: reason.message, lastUpdated: lastUpdated)
            }
        } catch {
            let appError = AppError(error)
            guard appError != .cancelled else { return }
            // Keep showing what we have if a pull-to-refresh fails; only replace the
            // whole screen with an error when there's nothing to show.
            if case .loaded = state {
                notice = .refreshFailed(message: appError.message, lastUpdated: nil)
            } else {
                state = .failed(message: appError.message)
            }
        }
    }

    /// Download lessons in the background so details also work offline later.
    private func prefetchDetails(for courses: [Course]) {
        prefetchTask?.cancel()
        prefetchTask = Task { [repository] in
            await repository.prefetchLessons(for: courses)
        }
    }
}
