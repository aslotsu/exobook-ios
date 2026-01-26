//
//  AppView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 22/10/2025.
//


// AppView.swift
import SwiftUI
import Supabase

struct AppView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var hasShownMinimumLoadingTime = false

    var body: some View {
        Group {
            if shouldShowLoading {
                // Show beautiful loading screen for everyone
                LoadingView()
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .scale(scale: 0.0).combined(with: .opacity)
                        )
                    )
                    .zIndex(1) // Keep loading screen on top during transition
            } else if authManager.isAuthenticated, let user = authManager.currentUser {
                // User is logged in
                if user.needsProfileSetup {
                    // Show profile setup if not completed
                    ProfileSetupView(user: user, isRequired: true)
                        .environment(\.currentUser, user)
                        .transition(.opacity)
                } else {
                    // Show main app with loaded data
                    MainTabs()
                        .environment(\.currentUser, user)
                        .transition(.opacity)
                }
            } else {
                // Not logged in - show auth screen
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: shouldShowLoading)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .task {
            // Ensure loading screen shows for at least 1.5 seconds for smooth UX
            try? await Task.sleep(for: .seconds(1.5))
            hasShownMinimumLoadingTime = true
        }
    }

    private var shouldShowLoading: Bool {
        // Show loading if auth is loading OR if we haven't shown minimum time yet
        authManager.isLoading || !hasShownMinimumLoadingTime
    }
}

// MARK: - Environment Key for Current User

private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: User? = nil
}

extension EnvironmentValues {
    var currentUser: User? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}
