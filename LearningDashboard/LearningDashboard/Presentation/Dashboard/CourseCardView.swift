//
//  CourseCardView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseCardView: View {
    let course: Course
    let onContinue: () -> Void

    private var actionTitle: String {
        course.progress >= 100 ? "Review" : "Continue"
    }

    var body: some View {
        Button(action: onContinue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Label(course.instructor, systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("\(course.progress)%")
                        .font(.title3.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                ProgressBar(progress: course.progress)

                HStack {
                    Label("\(course.totalLessons) lessons", systemImage: "list.bullet.rectangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .animation(.default, value: course.progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(course.title), by \(course.instructor), \(course.progress) percent complete, \(course.totalLessons) lessons")
        .accessibilityHint("\(actionTitle) course")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("course.\(course.id)")
    }
}

#Preview {
    CourseCardView(
        course: Course(id: 1, title: "Python Programming", instructor: "John Smith",
                       totalLessons: 20, completedLessons: 13),
        onContinue: {}
    )
    .padding()
}
