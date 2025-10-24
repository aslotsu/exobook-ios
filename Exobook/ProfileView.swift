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
    @State private var showingSettings = false
    
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
                    
                    // Academic Info
                    academicInfoSection(user: user)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Quick Actions
                    quickActionsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            } else {
                Text("User not found")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(adaptiveBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Profile Header
    
    @ViewBuilder
    private func profileHeader(user: User) -> some View {
        VStack(spacing: 16) {
            // Avatar
            if let avatarURL = user.avatarURL {
                WebImage(url: avatarURL)
                    .resizable()
                    .indicator(.activity)
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                    )
            }
            
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
            
            // Edit Profile Button
            Button(action: { /* TODO: Navigate to edit profile */ }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 40) {
            StatView(title: "Posts", value: "0")
            StatView(title: "Followers", value: "0")
            StatView(title: "Following", value: "0")
        }
    }
    
    // MARK: - Academic Info
    
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
            
            ActionButton(icon: "bookmark", title: "Saved Posts", action: {})
            ActionButton(icon: "heart", title: "Liked Posts", action: {})
            ActionButton(icon: "person.2", title: "Friends", action: {})
            ActionButton(icon: "arrow.right.circle", title: "Sign Out", color: .red, action: signOut)
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
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

// MARK: - Settings View Placeholder

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text("Edit Profile")
                    Text("Privacy Settings")
                    Text("Notifications")
                }
                
                Section("About") {
                    Text("Terms of Service")
                    Text("Privacy Policy")
                    Text("About Exobook")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
