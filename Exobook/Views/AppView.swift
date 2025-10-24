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

    var body: some View {
        Group {
            if authManager.isLoading {
                // Loading state while checking session
                ProgressView()
            } else if authManager.isAuthenticated, let user = authManager.currentUser {
                // User is logged in - show main app
                MainTabs()
                    .environment(\.currentUser, user)
            } else {
                // Not logged in - show auth screen
                AuthenticationView()
            }
        }
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
