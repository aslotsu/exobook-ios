//
//  AuthenticationManager.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    private let supabaseClient: SupabaseClient
    private let exobookAPI = ExobookAPIService()
    
    // Auth state
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var error: String?
    
    // Session
    private var session: Session? {
        didSet {
            Task {
                if let session = session {
                    await loadUserData(userId: session.user.id.uuidString)
                }
            }
        }
    }
    
    private init() {
        self.supabaseClient = supabase
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Session Management
    
    func checkSession() async {
        isLoading = true
        
        do {
            session = try await supabaseClient.auth.session
            
            // Listen for auth state changes
            Task {
                for await (event, session) in await supabaseClient.auth.authStateChanges {
                    await handleAuthStateChange(event: event, session: session)
                }
            }
        } catch {
            print("No active session: \(error)")
            session = nil
            currentUser = nil
        }
        
        isLoading = false
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session authSession: Session?) async {
        switch event {
        case .initialSession, .signedIn:
            session = authSession
        case .signedOut:
            session = nil
            currentUser = nil
        default:
            break
        }
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        do {
            session = try await supabaseClient.auth.signIn(
                email: email,
                password: password
            )
            
            // User data will be loaded via session didSet
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        isLoading = true
        error = nil
        
        do {
            // Sign up with Supabase
            let response = try await supabaseClient.auth.signUp(
                email: email,
                password: password
            )
            
            // Convert UUID to lowercase for backend API compatibility
            let userId = response.user.id.uuidString.lowercased()
            
            // Create user in your backend
            let createUserRequest = CreateUserRequest(
                id: userId,
                email: email,
                name: name
            )
            
            _ = try await exobookAPI.createUser(createUserRequest)
            
            session = response.session
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        try await supabaseClient.auth.signOut()
        session = nil
        currentUser = nil
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil
        
        do {
            // Start OAuth flow with Google
            try await supabaseClient.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "exobook://auth-callback")!
            )
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - User Data
    
    private func loadUserData(userId: String) async {
        do {
            // Convert UUID to lowercase for backend API compatibility
            let lowercaseUserId = userId.lowercased()
            
            // Fetch user profile
            var user = try await exobookAPI.getUser(id: lowercaseUserId)
            
            // Fetch user's enrolled courses separately
            let courseItems: [UserCourseItem]?
            do {
                courseItems = try await exobookAPI.getMyCourses(userId: lowercaseUserId)
                print("✅ Successfully fetched courses from API")
            } catch {
                print("❌ Failed to fetch courses: \(error)")
                courseItems = nil
            }
            
            // Convert UserCourseItem to UserCourse format
            if let courseItems = courseItems, !courseItems.isEmpty {
                print("🔍 Raw course items from API: \(courseItems.count) courses")
                courseItems.forEach { print("  - \($0.courseCode): \($0.courseName)") }
                
                let userCourses = courseItems.map { item in
                    UserCourse(
                        id: UUID().uuidString, // Generate ID since API doesn't provide one
                        name: item.courseName,
                        courseCode: item.courseCode,
                        courseName: item.courseName,
                        year: Int(item.year) ?? user.year ?? 1
                    )
                }
                
                print("🔍 Converted to UserCourse: \(userCourses.count) courses")
                userCourses.forEach { print("  - \($0.courseCode): \($0.courseName)") }
                // Create new user with courses
                user = User(
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    username: user.username,
                    bio: user.bio,
                    picture: user.picture,
                    campus: user.campus,
                    program: user.program,
                    year: user.year,
                    courses: userCourses,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt
                )
            }
            
            currentUser = user
            print("🔍 Final user courses: \(user.courses?.count ?? 0) courses")
            print("🔍 Course codes: \(user.courseCodes)")
        } catch {
            print("Failed to load user data: \(error)")
            // Use basic user info from Supabase session as fallback
            if let session = session {
                currentUser = User(
                    id: session.user.id.uuidString.lowercased(),
                    email: session.user.email ?? "",
                    name: session.user.email ?? "User",
                    username: nil,
                    bio: nil,
                    picture: nil,
                    campus: nil,
                    program: nil,
                    year: nil,
                    courses: nil,
                    createdAt: nil,
                    updatedAt: nil
                )
            }
        }
    }
    
    func refreshUserData() async {
        guard let userId = currentUser?.id else { return }
        await loadUserData(userId: userId)
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case userCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .userCreationFailed:
            return "Failed to create user account"
        }
    }
}
