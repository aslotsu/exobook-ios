//
//  AuthenticationView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var resetMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        Image(systemName: "book.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        Text("Linkio")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Social learning platform")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        if authManager.isPasswordRecoveryFlow {
                            recoveryFields
                        } else {
                            authFields
                        }

                        if let error = authManager.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        if let notice = authManager.authNotice {
                            Text(notice)
                                .foregroundColor(.green)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }

                        if let resetMessage {
                            Text(resetMessage)
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        if authManager.isPasswordRecoveryFlow {
                            recoveryActions
                        } else {
                            authActions
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private var authFields: some View {
        if isSignUp {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocorrectionDisabled()
        }

        TextField("Email", text: $email)
            .textFieldStyle(.roundedBorder)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()

        SecureField("Password", text: $password)
            .textFieldStyle(.roundedBorder)
            .textContentType(isSignUp ? .newPassword : .password)
    }

    private var recoveryFields: some View {
        VStack(spacing: 16) {
            Text("Set a new password")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField("New Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
        }
    }

    private var authActions: some View {
        VStack(spacing: 16) {
            Button(action: handleAuth) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || isLoading)

            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.caption)
            }

            if !isSignUp {
                Button(action: handlePasswordReset) {
                    Text("Forgot password?")
                        .font(.caption)
                }
                .disabled(email.isEmpty || isLoading)
            }

            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            Button(action: handleGoogleSignIn) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isLoading)
        }
    }

    private var recoveryActions: some View {
        VStack(spacing: 12) {
            Button(action: handlePasswordUpdate) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Update Password")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isRecoveryFormValid || isLoading)

            Button("Back to Sign In") {
                confirmPassword = ""
                password = ""
                authManager.cancelPasswordRecovery()
            }
            .font(.caption)
            .disabled(isLoading)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty &&
        password.count >= 6 &&
        (!isSignUp || !name.isEmpty)
    }

    private var isRecoveryFormValid: Bool {
        password.count >= 6 && password == confirmPassword
    }
    
    private func handleAuth() {
        resetMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password, name: name)
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
            } catch {
                print("Auth error: \(error)")
            }
        }
    }
    
    private func handleGoogleSignIn() {
        resetMessage = nil
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                print("Google Sign-In error: \(error)")
            }
        }
    }

    private func handlePasswordReset() {
        resetMessage = nil
        Task {
            do {
                try await authManager.requestPasswordReset(email: email)
                await MainActor.run {
                    resetMessage = "Password reset email sent."
                }
            } catch {
                print("Password reset error: \(error)")
            }
        }
    }

    private func handlePasswordUpdate() {
        resetMessage = nil
        Task {
            do {
                try await authManager.completePasswordRecovery(newPassword: password)
                await MainActor.run {
                    confirmPassword = ""
                    password = ""
                }
            } catch {
                print("Password update error: \(error)")
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
