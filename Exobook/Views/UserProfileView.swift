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
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: UserProfileViewModel?
    @State private var selectedPost: Post?
    @State private var relationshipState: RelationshipState = .none
    @State private var isRelationshipLoading = false
    @State private var isFriendActionLoading = false
    @State private var friendActionError: String?
    
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
            await loadRelationship()
        }
        .task(id: currentUser?.id) {
            await loadRelationship()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
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

            friendActionSection()

            if let friendActionError {
                Text(friendActionError)
                    .font(.caption)
                    .foregroundColor(.red)
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

    @ViewBuilder
    private func friendActionSection() -> some View {
        if let currentUser, currentUser.id != userId {
            if isRelationshipLoading {
                ProgressView()
                    .padding(.top, 4)
            } else {
                switch relationshipState {
                case .none:
                    Button("Add Friend") {
                        Task { await sendFriendRequest(from: currentUser.id, to: userId) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFriendActionLoading)
                case .requestSent:
                    Button("Requested") {
                        Task { await cancelFriendRequest(from: currentUser.id, to: userId) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isFriendActionLoading)
                case .requestReceived:
                    HStack(spacing: 8) {
                        Button("Accept") {
                            Task { await respondToFriendRequest(from: userId, to: currentUser.id, decision: .accepted) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFriendActionLoading)

                        Button("Decline") {
                            Task { await respondToFriendRequest(from: userId, to: currentUser.id, decision: .declined) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isFriendActionLoading)
                    }
                case .friends:
                    Label("Friends", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
        }
    }

    private func loadRelationship() async {
        guard let currentUser, currentUser.id != userId else { return }
        isRelationshipLoading = true
        defer { isRelationshipLoading = false }

        do {
            let service = FriendsAPIService()
            relationshipState = try await service.getRelationship(myId: currentUser.id, theirId: userId)
        } catch {
            relationshipState = .none
            friendActionError = "Unable to load friend status."
        }
    }

    private func sendFriendRequest(from fromId: String, to toId: String) async {
        isFriendActionLoading = true
        friendActionError = nil
        defer { isFriendActionLoading = false }

        do {
            let service = FriendsAPIService()
            _ = try await service.sendFriendRequest(fromId: fromId, toId: toId)
            relationshipState = .requestSent
        } catch {
            friendActionError = "Failed to send request."
        }
    }

    private func respondToFriendRequest(from fromId: String, to toId: String, decision: FriendRequestDecision) async {
        isFriendActionLoading = true
        friendActionError = nil
        defer { isFriendActionLoading = false }

        do {
            let service = FriendsAPIService()
            _ = try await service.respondToRequest(fromId: fromId, toId: toId, status: decision)
            relationshipState = (decision == .accepted) ? .friends : .none
        } catch {
            friendActionError = "Failed to update request."
        }
    }

    private func cancelFriendRequest(from fromId: String, to toId: String) async {
        isFriendActionLoading = true
        friendActionError = nil
        defer { isFriendActionLoading = false }

        do {
            let service = FriendsAPIService()
            _ = try await service.cancelFriendRequest(fromId: fromId, toId: toId)
            relationshipState = .none
        } catch {
            friendActionError = "Failed to cancel request."
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
                    PostCard(
                        post: post,
                        currentUserId: currentUser?.id ?? "",
                        isBookmarked: false,
                        onLike: {},
                        onComment: {},
                        onBookmark: {},
                        onDelete: {},
                        onReport: {}
                    )
                    .onTapGesture {
                        selectedPost = post
                    }
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
            do {
                posts = try await api.getUserPosts(userId: userId)
                print("✅ Loaded \(posts.count) posts for user \(userId)")
            } catch {
                print("❌ Failed to load posts for user \(userId): \(error)")
                posts = []
            }
            isLoadingPosts = false
        } catch {
            print("Failed to load user data: \(error)")
            isLoadingPosts = false
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "test-user-id")
    }
}
