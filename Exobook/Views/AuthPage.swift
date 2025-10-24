//
//  AuthPage.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI
import Supabase

struct AuthPage: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var info: String?
    @State private var errorMessage: String?

    // Your custom scheme must also be added as a Redirect URL in Supabase Auth settings
    private let redirectURL = URL(string: "exobook://login-callback")!

    var body: some View {
        VStack(spacing: 16) {
            // Branding
            VStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.blue)
                Text("Exobook")
                    .font(.largeTitle.bold())
            }
            .padding(.top, 24)

            // Email sign in
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sign in with email").font(.headline)
                    TextField("you@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await signInWithEmail() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Sending..." : "Send magic link")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || isLoading)
                }
            }

            // Divider
            HStack {
                Rectangle().frame(height: 1).opacity(0.15)
                Text("OR").foregroundStyle(.secondary).font(.caption)
                Rectangle().frame(height: 1).opacity(0.15)
            }

            // Social providers
            VStack(spacing: 10) {
                Button {
                    Task { await signInWithOAuth(provider: .google) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill").font(.title2)
                        Text("Continue with Google").bold()
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await signInWithOAuth(provider: .apple) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo").font(.title2)
                        Text("Continue with Apple").bold()
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            // Messages
            if let info {
                Text(info).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func signInWithEmail() async {
        guard !email.isEmpty else { return }
        isLoading = true
        info = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: redirectURL
            )
            info = "Check your inbox for the magic link."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithOAuth(provider: Provider) async {
        // Providers: .google, .apple, .github, etc.
        // This opens ASWebAuthenticationSession and returns via your app’s onOpenURL.
        isLoading = true
        info = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: redirectURL,
                // On iOS you can ask the SDK to use an in-app web session:
                // scopes & query params can be added here if needed
//                options: .init(
//                    // If you need additional scopes:
//                    // scopes: "email profile",
//                    // Prefer in-app browser session:
//                    prefersEphemeralSession: false
//                )
            )
            // Control returns after deep link completes (handled in App entry .onOpenURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
