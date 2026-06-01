// AppView.swift
import SwiftUI
import Supabase

struct AppView: View {
    @State private var authManager = AuthenticationManager.shared

    var body: some View {
        Group {
            switch authManager.authState {
            case .bootstrapping:
                LoadingView()
                    .transition(.opacity)

            case .signedOut:
                AuthenticationView()
                    .transition(.opacity)

            case .authenticated(let user):
                if user.needsProfileSetup {
                    ProfileSetupView(user: user, isRequired: true)
                        .environment(\.currentUser, user)
                        .transition(.opacity)
                } else {
                    MainTabs()
                        .environment(\.currentUser, user)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.isAuthenticated)
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
