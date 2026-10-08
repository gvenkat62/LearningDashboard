//
//  LoginView.swift
//  LearningDashboard
//

import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    emailField
                    passwordField
                }

                if let message = viewModel.errorMessage {
                    BannerView(style: .error, message: message)
                        .transition(.opacity)
                }

                loginButton

                #if DEBUG
                demoCredentialsHint
                #endif
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: viewModel.errorMessage)
        .disabled(viewModel.isLoading)
    }

    // MARK: Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Welcome back")
                .font(.largeTitle.bold())
            Text("Sign in to continue learning.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email").font(.subheadline.weight(.medium))
            TextField("you@example.com", text: $viewModel.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .padding(12)
                .background(fieldBackground(hasError: viewModel.emailError != nil))
                .accessibilityIdentifier("login.email")
            FieldErrorText(message: viewModel.emailError)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password").font(.subheadline.weight(.medium))
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit(submit)
                .padding(12)
                .background(fieldBackground(hasError: viewModel.passwordError != nil))
                .accessibilityIdentifier("login.password")
            FieldErrorText(message: viewModel.passwordError)
        }
    }

    private var loginButton: some View {
        Button(action: submit) {
            ZStack {
                Text("Log In").opacity(viewModel.isLoading ? 0 : 1)
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(viewModel.isLoading ? "Logging in" : "Log In")
        .accessibilityIdentifier("login.submit")
    }

    #if DEBUG
    private var demoCredentialsHint: some View {
        Button {
            viewModel.email = MockLearningServer.demoEmail
            viewModel.password = MockLearningServer.demoPassword
        } label: {
            Label("Fill demo account (\(MockLearningServer.demoEmail) / \(MockLearningServer.demoPassword))",
                  systemImage: "wand.and.stars")
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
    }
    #endif

    private func fieldBackground(hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hasError ? Color.red : Color.clear, lineWidth: 1)
            )
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.login() }
    }
}

private struct FieldErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityLabel("Error: \(message)")
        }
    }
}
