//
//  UserProfileView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct UserProfileView: View {
    let userId: String
    @State private var viewModel: UserProfileViewModel?
    
    var body: some View {
        ScrollView {
            if let viewModel = viewModel {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader(viewModel: viewModel)
                    
                    Divider()
                    
                    // User Posts
                    postsSection(viewModel: viewModel)
                }
                .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = UserProfileViewModel(userId: userId)
                await viewModel?.loadUserData()
            }
        }
    }
    
    // MARK: - Profile Header
    
    private func profileHeader(viewModel: UserProfileViewModel) -> some View {
        VStack(spacing: 16) {
            // Avatar
            if let avatarURL = viewModel.user?.avatarURL {
                WebImage(url: avatarURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(viewModel.user?.name.prefix(1).uppercased() ?? "U")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Name
            Text(viewModel.user?.name ?? "Unknown")
                .font(.title2)
                .fontWeight(.bold)
            
            // Bio
            if let bio = viewModel.user?.bio {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Info Grid
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(viewModel.postsCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let campus = viewModel.user?.campus {
                    VStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.title3)
                        Text(campus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let year = viewModel.user?.year {
                    VStack(spacing: 4) {
                        Text("Year \(year)")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Student")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Posts Section
    
    private func postsSection(viewModel: UserProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Posts")
                .font(.headline)
            
            if viewModel.isLoadingPosts {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.posts.isEmpty {
                Text("No posts yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCard(
                            post: post,
                            isLiked: false,
                            isBookmarked: false,
                            onLike: {},
                            onComment: {},
                            onBookmark: {}
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
class UserProfileViewModel {
    let userId: String
    private let api = ExobookAPIService()
    
    var user: User?
    var posts: [Post] = []
    var isLoadingPosts = false
    var postsCount: Int { posts.count }
    
    init(userId: String) {
        self.userId = userId
    }
    
    func loadUserData() async {
        do {
            // Load user info
            user = try await api.getUser(id: userId)
            
            // Load user posts
            isLoadingPosts = true
            // TODO: Add API method to get user's posts
            // For now, we'll leave it empty
            isLoadingPosts = false
        } catch {
            print("Failed to load user data: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "test-user-id")
    }
}
