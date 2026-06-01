//
//  AuthenticationManager.swift
//  Exobook
//

import Foundation
import Supabase
import SwiftUI
import FirebaseMessaging

@MainActor
@Observable
final class AuthenticationManager {
    static let shared = AuthenticationManager()

    // MARK: - Auth State (single source of truth)

    enum AuthState { case bootstrapping, signedOut, authenticated(User) }

    private(set) var authState: AuthState = .bootstrapping

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = authState { return user }
        return nil
    }

    // The Supabase session — read by authTokenProvider without any async/throws.
    private(set) var currentSession: Session?

    var sessionAccessToken: String? { currentSession?.accessToken }

    // UI feedback
    var error: String?
    var authNotice: String?
    var isPasswordRecoveryFlow = false

    var hasLoggedInBefore: Bool {
        get { UserDefaults.standard.bool(forKey: "hasLoggedInBefore") }
        set { UserDefaults.standard.set(newValue, forKey: "hasLoggedInBefore") }
    }

    // MARK: - Private

    private let supabaseClient: SupabaseClient = supabase
    private let linkioAPI = LinkioAPIService()
    private var isLoadingUserData = false
    private var listenerTask: Task<Void, Never>?

    private init() {
        Task { await bootstrap() }
    }

    // MARK: - Bootstrap

    /// Implements the mobile session bootstrap pattern:
    /// 1. Read Supabase session from Keychain — no network call.
    /// 2. If session exists and is not expired, show the app immediately.
    /// 3. Load user profile from API (necessary for campus/program/courses).
    /// 4. Kick off a background token refresh — do NOT await it.
    /// 5. Start the auth state listener for future sign-in / sign-out events.
    func bootstrap() async {
        print("[auth] bootstrap start")

        // The Supabase SDK persists the session in Keychain and reads it back on init.
        // Calling `session` here reads from that in-memory/Keychain cache.
        // It may refresh the token if it is close to expiry; that is acceptable on first
        // launch because the alternative is having no token at all.
        if let cached = try? await supabaseClient.auth.session {
            print("[auth] bootstrap cachedSession=true userId=\(cached.user.id)")
            currentSession = cached
            hasLoggedInBefore = true
            await loadUserData(userId: cached.user.id.uuidString)
            // Refresh silently — never block startup on this.
            Task { await refreshInBackground() }
        } else {
            print("[auth] bootstrap no cached session → sign-in")
            authState = .signedOut
        }

        startAuthListener()
    }

    private func refreshInBackground() async {
        print("[auth] refresh start")
        do {
            let refreshed = try await supabaseClient.auth.refreshSession()
            currentSession = refreshed
            print("[auth] refresh success userId=\(refreshed.user.id)")
        } catch {
            print("[auth] refresh failed reason=\(error)")
            let msg = error.localizedDescription.lowercased()
            // Only force sign-out on an explicit invalid refresh token — not network blips.
            if msg.contains("invalid") && (msg.contains("refresh") || msg.contains("grant")) {
                currentSession = nil
                authState = .signedOut
            }
        }
    }

    private func startAuthListener() {
        guard listenerTask == nil else { return }
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in await supabaseClient.auth.authStateChanges {
                print("[auth] event \(event)")
                await self.handleEvent(event, session: session)
            }
        }
    }

    private func handleEvent(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession:
            // Bootstrap already handled this; just keep currentSession in sync.
            if let session { currentSession = session }

        case .signedIn:
            if let session {
                currentSession = session
                hasLoggedInBefore = true
                await loadUserData(userId: session.user.id.uuidString)
            }
            authNotice = nil

        case .passwordRecovery:
            if let session { currentSession = session }
            isPasswordRecoveryFlow = true
            authNotice = "Choose a new password to finish resetting your account."

        case .userUpdated:
            authNotice = "Account details updated."

        case .signedOut:
            currentSession = nil
            authState = .signedOut
            isPasswordRecoveryFlow = false

        default:
            break
        }
    }

    // MARK: - User Data

    private func loadUserData(userId: String) async {
        guard !isLoadingUserData else { return }
        isLoadingUserData = true
        defer { isLoadingUserData = false }

        let uid = userId.lowercased()

        do {
            var user = try await linkioAPI.getUser(id: uid)

            if let items = try? await linkioAPI.getMyCourses(userId: uid), !items.isEmpty {
                let courses = items.map { item in
                    UserCourse(id: UUID().uuidString, name: item.courseName,
                               courseCode: item.courseCode, courseName: item.courseName,
                               year: item.year)
                }
                user = User(id: user.id, email: user.email, name: user.name,
                            username: user.username, bio: user.bio, picture: user.picture,
                            country: user.country, campus: user.campus, program: user.program,
                            year: user.year, infoUpdated: user.infoUpdated,
                            courses: courses, createdAt: user.createdAt, updatedAt: user.updatedAt)
            }

            authState = .authenticated(user)
            NotificationManager.shared.setupFCM(userId: user.id)
            print("[auth] user loaded id=\(user.id)")

        } catch {
            print("[auth] loadUserData failed: \(error)")
            // Show app with minimal user from Supabase session (avoids blank auth screen).
            if let session = currentSession {
                let fallback = User(id: session.user.id.uuidString.lowercased(),
                                    email: session.user.email ?? "",
                                    name: session.user.email ?? "User",
                                    username: nil, bio: nil, picture: nil, country: nil,
                                    campus: nil, program: nil, year: nil, infoUpdated: false,
                                    courses: nil, createdAt: nil, updatedAt: nil)
                authState = .authenticated(fallback)
                NotificationManager.shared.setupFCM(userId: fallback.id)
            } else {
                authState = .signedOut
            }
        }
    }

    func refreshUserData() async {
        guard let uid = currentUser?.id else { return }
        await loadUserData(userId: uid)
    }

    // MARK: - Sign In / Sign Up / Sign Out

    func signIn(email: String, password: String) async throws {
        error = nil
        authNotice = nil
        do {
            let session = try await supabaseClient.auth.signIn(email: email, password: password)
            currentSession = session
            // handleEvent(.signedIn) will fire via authStateChanges listener.
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        error = nil
        authNotice = nil
        do {
            let response = try await supabaseClient.auth.signUp(
                email: email, password: password,
                data: ["name": .string(name)]
            )
            let uid = response.user.id.uuidString.lowercased()
            let req = CreateUserRequest(id: uid, email: email, name: name,
                                        bio: "Eager to try out Exobook!", picture: "",
                                        school: "", country: "", campus: "",
                                        infoUpdated: false, program: "", year: 1)
            _ = try await linkioAPI.createUser(req)
            if let session = response.session {
                currentSession = session
            }
            authNotice = response.session == nil
                ? "Check your email to confirm your account before signing in."
                : "Account created successfully."
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func signOut() async throws {
        if let user = currentUser { await deactivateCurrentFCMToken(userId: user.id) }
        try await supabaseClient.auth.signOut()
        currentSession = nil
        authState = .signedOut
        authNotice = nil
        isPasswordRecoveryFlow = false
    }

    func deleteAccount() async throws {
        guard let user = currentUser else { throw AccountError.notAuthenticated }
        await deactivateCurrentFCMToken(userId: user.id)
        try await linkioAPI.deleteUserAccount(id: user.id)
        try await supabaseClient.auth.signOut()
        currentSession = nil
        authState = .signedOut
        authNotice = nil
        isPasswordRecoveryFlow = false
    }

    // MARK: - Password

    func requestPasswordReset(email: String) async throws {
        error = nil
        authNotice = nil
        do {
            try await supabaseClient.auth.resetPasswordForEmail(
                email, redirectTo: URL(string: "linkio://auth-callback")!)
            authNotice = "Password reset email sent."
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func completePasswordRecovery(newPassword: String) async throws {
        error = nil
        do {
            _ = try await supabaseClient.auth.update(user: UserAttributes(password: newPassword))
            isPasswordRecoveryFlow = false
            authNotice = "Password updated. You can continue into the app."
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func cancelPasswordRecovery() {
        isPasswordRecoveryFlow = false
        authNotice = nil
        error = nil
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        error = nil
        authNotice = nil
        do {
            try await supabaseClient.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "linkio://auth-callback")!)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - FCM

    private func deactivateCurrentFCMToken(userId: String) async {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                guard let token else { continuation.resume(); return }
                Task {
                    try? await self.linkioAPI.deactivateDeviceToken(userId: userId, token: token)
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Errors

    enum AccountError: LocalizedError {
        case notAuthenticated
        var errorDescription: String? { "You must be signed in to perform this action." }
    }
}

enum AuthError: LocalizedError {
    case invalidResponse, userCreationFailed
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .userCreationFailed: return "Failed to create user account"
        }
    }
}
