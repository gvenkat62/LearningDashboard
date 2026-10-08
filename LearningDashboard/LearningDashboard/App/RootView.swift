//
//  RootView.swift
//  LearningDashboard
//
//  Top-level routing driven by session state.
//

import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        Group {
            switch container.sessionStore.state {
            case .signedOut:
                LoginView(viewModel: container.makeLoginViewModel())
                    .transition(.opacity)
            case .signedIn(let user):
                CoursesFlowView(container: container, user: user)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: container.sessionStore.state)
    }
}

/// Owns the navigation stack for the signed-in experience.
struct CoursesFlowView: View {
    let container: AppContainer
    let user: User
    @State private var path: [Course] = []

    var body: some View {
        NavigationStack(path: $path) {
            CourseDashboardView(
                viewModel: container.makeDashboardViewModel(user: user),
                debugTools: container.debugTools,
                onSelectCourse: { path.append($0) },
                onSignOut: { container.sessionStore.signOut() }
            )
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(viewModel: container.makeCourseDetailViewModel(course: course))
            }
        }
    }
}
