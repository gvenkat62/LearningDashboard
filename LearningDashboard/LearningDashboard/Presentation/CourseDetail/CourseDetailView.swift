//
//  CourseDetailView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseDetailView: View {
    @State private var viewModel: CourseDetailViewModel

    init(viewModel: CourseDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section { header }

            if let notice = viewModel.notice {
                Section { noticeBanner(notice) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Lessons") { lessonsContent }
        }
        .navigationTitle(viewModel.course.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: viewModel.lessons)
        .animation(.default, value: viewModel.notice)
        .sensoryFeedback(.success, trigger: viewModel.completedCount) { old, new in new > old }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.course.title)
                .font(.title2.bold())
            Label(viewModel.course.instructor, systemImage: "person")
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text("\(viewModel.course.progress)%")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("complete")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.course.completedLessons) of \(viewModel.course.totalLessons) lessons")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressBar(progress: viewModel.course.progress)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail.header")
    }

    @ViewBuilder
    private var lessonsContent: some View {
        switch viewModel.state {
        case .loading:
            HStack {
                Spacer()
                ProgressView("Loading lessons…")
                Spacer()
            }
            .padding(.vertical)

        case .failed(let message):
            ContentUnavailableView {
                Label("Lessons unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.load() } }
            }

        case .loaded:
            ForEach(viewModel.lessons) { lesson in
                LessonRowView(lesson: lesson) {
                    Task { await viewModel.markCompleted(lesson) }
                }
            }
        }
    }

    @ViewBuilder
    private func noticeBanner(_ notice: CourseDetailViewModel.Notice) -> some View {
        switch notice {
        case .offline:
            BannerView(style: .warning, message: "You're offline. Showing saved lessons — progress you make will sync later.")
        case .pendingSync:
            BannerView(style: .info, message: "Saved on this device. It will sync when you're back online.")
        case .error(let message):
            BannerView(style: .error, message: message)
        }
    }
}

struct LessonRowView: View {
    let lesson: Lesson
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: lesson.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(lesson.isCompleted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                Text(lesson.isCompleted ? "Completed" : "Pending")
                    .font(.caption)
                    .foregroundStyle(lesson.isCompleted ? Color.green : Color.secondary)
            }

            Spacer()

            if !lesson.isCompleted {
                Button("Mark Complete", action: onComplete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Mark \(lesson.title) complete")
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("lesson.\(lesson.id)")
    }
}
