//
//  LikedPostsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 02/01/2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct LikedPostsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: LikedPostsViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        if viewModel == nil, let user = currentUser {
                            viewModel = LikedPostsViewModel(userId: user.id)
                            Task {
                                await viewModel?.loadLikedPosts()
                            }
                        }
                    }
            }
        }
        .background(adaptiveBackground)
        .navigationTitle("Liked Posts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func contentView(viewModel: LikedPostsViewModel) -> some View {
        if viewModel.isLoading && viewModel.likedPosts.isEmpty {
            ProgressView("Loading liked posts...")
                .padding()
        } else if let error = viewModel.error, viewModel.likedPosts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                Text("Error Loading Liked Posts")
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Retry") {
                    Task {
                        await viewModel.loadLikedPosts()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else if viewModel.likedPosts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No liked posts yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Posts you like will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.likedPosts) { like in
                        LikedPostCard(like: like, currentUserId: viewModel.userId)
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.loadLikedPosts()
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
}

// MARK: - Liked Post Card

struct LikedPostCard: View {
    let like: LikedPost
    let currentUserId: String
    @State private var post: Post?
    @State private var isLoading = false
    @State private var hasAppeared = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let post = post {
                // Header with user info (from the post, not the like)
                PostHeaderFromLike(like: like, post: post)
                
                // Post content
                VStack(alignment: .leading, spacing: 10) {
                    // Title (only show if not empty)
                    if !post.title.isEmpty {
                        Text(post.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    // Content - strip HTML and show plain text
                    Text(post.content.htmlStripped)
                        .font(.body)
                        .lineLimit(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Liked indicator
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                    Text("You liked this")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(like.date.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else if isLoading {
                // Loading skeleton
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 14)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 16)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 14)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .redacted(reason: .placeholder)
            } else if !hasAppeared {
                // Placeholder before loading starts
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Loading post...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            } else {
                // Fallback if post couldn't be loaded
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Post not available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("This post may have been deleted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    Divider()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text("You liked this")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(like.date.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .task(id: like.id) {
            // Lazy load: only fetch when card appears in viewport
            if !hasAppeared && post == nil {
                await MainActor.run {
                    hasAppeared = true
                }
                await loadPost()
            }
        }
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
    
    private func loadPost() async {
        let startTime = Date()
        print("⏳ Started loading post: \(like.postId)")
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let api = ExobookAPIService()
            let loadedPost = try await api.getPost(id: like.postId)
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Loaded post: \(like.postId) in \(String(format: "%.2f", duration))s")
            
            
            await MainActor.run {
                self.post = loadedPost
                self.isLoading = false
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ Failed to load post \(like.postId) after \(String(format: "%.2f", duration))s: \(error)")
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Post Header From Like

struct PostHeaderFromLike: View {
    let like: LikedPost
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            ProfileImageView(imageURL: post.userAvatarURL, userName: post.userName ?? post.username, size: 40)
            
            // User info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(post.userName ?? post.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(post.subject)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - View Model

@MainActor
@Observable
class LikedPostsViewModel {
    let userId: String
    private let api = ExobookAPIService()
    
    var likedPosts: [LikedPost] = []
    var isLoading = false
    var error: String?
    
    init(userId: String) {
        self.userId = userId
    }
    
    func loadLikedPosts() async {
        let startTime = Date()
        isLoading = true
        error = nil
        
        print("🔍 Loading liked posts for user: \(userId)")
        
        do {
            likedPosts = try await api.getMyLikes(userId: userId)
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Loaded \(likedPosts.count) liked posts in \(String(format: "%.2f", duration))s")
            if !likedPosts.isEmpty {
                print("📄 Sample liked post:")
                if let first = likedPosts.first {
                    print("  - Post ID: \(first.postId)")
                    print("  - Username: \(first.username)")
                    print("  - Excerpt: \(first.excerpt ?? "nil")")
                    print("  - Is Reply: \(first.isReply)")
                }
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            self.error = error.localizedDescription
            print("❌ Failed to load liked posts after \(String(format: "%.2f", duration))s: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
        }
        
        isLoading = false
        print("🏁 Liked posts loading completed (isLoading = false)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LikedPostsView()
    }
}

