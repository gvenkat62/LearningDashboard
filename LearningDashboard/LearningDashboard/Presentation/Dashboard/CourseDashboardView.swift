//
//  CourseDashboardView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseDashboardView: View {
    @State private var viewModel: CourseDashboardViewModel
    private let debugTools: DebugTools?
    private let onSelectCourse: (Course) -> Void
    private let onSignOut: () -> Void

    init(viewModel: CourseDashboardViewModel,
         debugTools: DebugTools?,
         onSelectCourse: @escaping (Course) -> Void,
         onSignOut: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.debugTools = debugTools
        self.onSelectCourse = onSelectCourse
        self.onSignOut = onSignOut
    }

    var body: some View {
        content
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { accountMenu }
            }
            // Runs on first appearance and again when returning from details
            // (the VM decides between a full load and a cheap cache re-read).
            .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading courses…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("dashboard.loading")

        case .loaded(let courses):
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let notice = viewModel.notice {
                        noticeBanner(notice)
                    }
                    ForEach(courses) { course in
                        CourseCardView(course: course) { onSelectCourse(course) }
                    }
                }
                .padding()
                .animation(.default, value: viewModel.notice)
            }
            .refreshable { await viewModel.refresh() }
            .accessibilityIdentifier("dashboard.list")

        case .empty:
            ContentUnavailableView {
                Label("No courses yet", systemImage: "books.vertical")
            } description: {
                Text("Courses you enrol in will appear here.")
            } actions: {
                Button("Refresh") { Task { await viewModel.retry() } }
            }
            .accessibilityIdentifier("dashboard.empty")

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load courses", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.retry() } }
                    .buttonStyle(.borderedProminent)
            }
            .accessibilityIdentifier("dashboard.error")
        }
    }

    @ViewBuilder
    private func noticeBanner(_ notice: CourseDashboardViewModel.Notice) -> some View {
        switch notice {
        case .offline(let lastUpdated):
            BannerView(style: .warning,
                       message: "You're offline. Showing courses saved \(Self.relative(lastUpdated)).")
        case .refreshFailed(let message, _):
            BannerView(style: .error, message: message, actionTitle: "Retry") {
                Task { await viewModel.refresh() }
            }
        }
    }

    private var accountMenu: some View {
        Menu {
            Section(viewModel.userName) {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, action: onSignOut)
            }
            #if DEBUG
            if let debugTools {
                DebugMenu(tools: debugTools)
            }
            #endif
        } label: {
            Image(systemName: "person.crop.circle")
                .accessibilityLabel("Account")
        }
    }

    private static func relative(_ date: Date?) -> String {
        guard let date else { return "earlier" }
        return date.formatted(.relative(presentation: .named))
    }
}
