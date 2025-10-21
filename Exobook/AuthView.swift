//
//  AuthView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Sign in") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { await sendMagicLink() }
                } label: {
                    if isLoading { ProgressView() } else { Text("Send magic link") }
                }
                .disabled(email.isEmpty || isLoading)
            }

            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Welcome")
    }

    private func sendMagicLink() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "exobook://login-callback")
            )
            message = "Check your inbox for the sign-in link."
        } catch {
            message = error.localizedDescription
        }
    }
}
