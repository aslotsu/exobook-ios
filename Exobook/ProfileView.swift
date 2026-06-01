//
//  ProfileView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI
import SDWebImageSwiftUI

struct ProfileView: View {
    @Environment(\.currentUser) private var currentUser
    private let friendsAPI = FriendsAPIService()
    @State private var showingSettings = false
    @State private var isRefreshing = false
    @State private var showingLikedPosts = false
    @State private var showingSavedPosts = false
    @State private var showingMyPosts = false
    @State private var showingEditProfile = false
    @State private var showingFriends = false
    @State private var showingFriendRequests = false
    @State private var showingMeetings = false
    @State private var pendingRequestsCount = 0
    
    var body: some View {
        ScrollView {
            if let user = currentUser {
                VStack(spacing: 0) {
                    // Header Section
                    profileHeader(user: user)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Stats Section
                    statsSection
                    
                    Divider()
                        .padding(.vertical, 16)

                    // Quick Actions (keep high so social actions are easy to find)
                    quickActionsSection

                    Divider()
                        .padding(.vertical, 16)

                    accountDetailsSection(user: user)

                    Divider()
                        .padding(.vertical, 16)
                    
                    // Academic Info
                    academicInfoSection(user: user)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            } else {
                Text("User not found")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable {
            await refreshProfile()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingLikedPosts) {
            NavigationStack {
                LikedPostsView()
            }
        }
        .sheet(isPresented: $showingSavedPosts) {
            NavigationStack {
                SavedPostsView()
            }
        }
        .sheet(isPresented: $showingMyPosts) {
            NavigationStack {
                MyPostsView()
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            if let user = currentUser {
                EditProfileView(user: user)
            }
        }
        .sheet(isPresented: $showingFriends) {
            NavigationStack {
                FriendsListView()
            }
        }
        .sheet(isPresented: $showingFriendRequests) {
            NavigationStack {
                FriendRequestsInboxView()
            }
        }
        .sheet(isPresented: $showingMeetings) {
            NavigationStack {
                MeetingsView()
            }
        }
        .task(id: currentUser?.id) {
            await refreshPendingRequestsCount()
        }
        .onAppear {
            debugPrintUserInfo()
        }
    }
    
    private func refreshProfile() async {
        isRefreshing = true
        print("🔄 Refreshing profile data...")
        await AuthenticationManager.shared.refreshUserData()
        await refreshPendingRequestsCount()
        debugPrintUserInfo()
        isRefreshing = false
    }

    private func refreshPendingRequestsCount() async {
        guard let userId = currentUser?.id else {
            pendingRequestsCount = 0
            return
        }

        do {
            let response = try await friendsAPI.getPendingRequests(userId: userId, page: 1, limit: 1)
            pendingRequestsCount = response.count
        } catch {
            pendingRequestsCount = 0
        }
    }
    
    private func debugPrintUserInfo() {
        print("=== 🔍 Profile Debug Info ===")
        if let user = currentUser {
            print("User ID: \(user.id)")
            print("Email: \(user.email)")
            print("Name: \(user.name)")
            print("Username: \(user.username ?? "nil")")
            print("Bio: \(user.bio ?? "nil")")
            print("Picture: \(user.picture ?? "nil")")
            print("Campus: \(user.campus ?? "nil")")
            print("Program: \(user.program ?? "nil")")
            print("Year: \(user.year?.description ?? "nil")")
            print("Courses count: \(user.courses?.count ?? 0)")
            if let courses = user.courses {
                print("Course details:")
                courses.forEach { course in
                    print("  - \(course.courseCode): \(course.courseName)")
                }
            }
            print("Avatar URL: \(user.avatarURL?.absoluteString ?? "nil")")
        } else {
            print("❌ currentUser is nil!")
        }
        print("=========================")
    }
    
    // MARK: - Profile Header
    
    @ViewBuilder
    private func profileHeader(user: User) -> some View {
        VStack(spacing: 16) {
            // Avatar
            ProfileImageView(imageURL: user.avatarURL, userName: user.name, size: 100)
            
            // Name and Bio
            VStack(spacing: 8) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action Buttons - Edit Profile and My Posts
            HStack(spacing: 12) {
                Button(action: { showingEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: { showingMyPosts = true }) {
                    Text("My Posts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 40) {
            // TODO: Implement followers/following functionality in the future
            // StatView(title: "Followers", value: "0")
            // StatView(title: "Following", value: "0")
        }
    }
    
    // MARK: - Academic Info

    @ViewBuilder
    private func accountDetailsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.headline)

            InfoRow(icon: "envelope", title: "Email", value: user.email)
            InfoRow(icon: "at", title: "Username", value: user.username.map { "@\($0)" } ?? "Not set")
            InfoRow(icon: "globe", title: "Country", value: user.country ?? "Not set")
            InfoRow(
                icon: user.needsProfileSetup ? "exclamationmark.triangle" : "checkmark.seal",
                title: "Profile Status",
                value: user.needsProfileSetup ? "Needs attention" : "Complete"
            )
        }
    }
    
    @ViewBuilder
    private func academicInfoSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Academic Information")
                .font(.headline)
            
            InfoRow(icon: "building.2", title: "Campus", value: user.campus ?? "Not set")
            InfoRow(icon: "calendar", title: "Academic Year", value: "\(user.year ?? 1)")
            
            if let program = user.programme, !program.isEmpty {
                // Extract just the program name before the pipe
                let programName = program.split(separator: "|").first.map(String.init) ?? program
                InfoRow(icon: "graduationcap", title: "Program", value: programName)
            }
            
            // Enrolled Courses
            if let courses = user.courses, !courses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "books.vertical")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Enrolled Courses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(courses) { course in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.courseCode)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(course.courseName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ActionButton(icon: "person.2", title: "Friends", action: { showingFriends = true })
            ActionButton(
                icon: "person.crop.circle.badge.plus",
                title: "Friend Requests",
                badgeText: pendingRequestsCount > 0 ? "\(pendingRequestsCount)" : nil,
                action: { showingFriendRequests = true }
            )
            ActionButton(icon: "calendar", title: "Meetings", action: { showingMeetings = true })
            ActionButton(icon: "heart", title: "Liked Posts", action: { showingLikedPosts = true })
            ActionButton(icon: "bookmark", title: "Saved Posts", action: { showingSavedPosts = true })
            ActionButton(icon: "arrow.right.circle", title: "Sign Out", color: .red, action: signOut)
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await AuthenticationManager.shared.signOut()
            } catch {
                print("Sign out error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    var color: Color = .primary
    var badgeText: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(color)
                Spacer()
                if let badgeText {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser

    @State private var showingDeleteConfirm = false
    @State private var showingFinalConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    }
                    .disabled(isDeleting)
                }

                if let err = deleteError {
                    Section {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
            // First confirmation
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) { showingFinalConfirm = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your posts, messages, and profile will be permanently removed. This cannot be undone.")
            }
            // Final confirmation
            .alert("Are you absolutely sure?", isPresented: $showingFinalConfirm) {
                Button("Delete My Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tap \"Delete My Account\" to permanently delete your account.")
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            try await AuthenticationManager.shared.deleteAccount()
            dismiss()
        } catch {
            isDeleting = false
            deleteError = error.localizedDescription
        }
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
