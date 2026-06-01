
//
//  SavedPostsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct SavedPostsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: SavedPostsViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView("Loading saved posts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        guard viewModel == nil, let userId = currentUser?.id else { return }
                        let newViewModel = SavedPostsViewModel(userId: userId)
                        self.viewModel = newViewModel
                        await newViewModel.load()
                    }
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(viewModel: SavedPostsViewModel) -> some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView("Loading saved posts...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error, viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Couldn’t load saved posts")
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Retry") {
                    Task {
                        await viewModel.load()
                    }
                }
            }
            .padding()
        } else if viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "bookmark")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("No saved posts yet")
                    .font(.headline)
                Text("Bookmark posts from the feed and they’ll show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            PostCard(
                                post: post,
                                currentUserId: currentUser?.id ?? "",
                                isBookmarked: true,
                                onLike: {},
                                onComment: {},
                                onBookmark: {
                                    Task {
                                        await viewModel.removeBookmark(postId: post.id)
                                    }
                                },
                                onDelete: {},
                                onReport: {}
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
}

@MainActor
@Observable
class SavedPostsViewModel {
    let userId: String

    var posts: [Post] = []
    var isLoading = false
    var error: String?

    init(userId: String) {
        self.userId = userId
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let api = LinkioAPIService()
            // Fetch bookmarked posts from backend (includes full post objects).
            let loadedPosts = try await api.getUserBookmarks(userId: userId)
            posts = loadedPosts

            // Seed RealtimeManager so PostCard stat counts are accurate.
            if !posts.isEmpty {
                let rm = RealtimeManager.shared
                rm.initializeCounts(posts: posts)
                let ids = posts.map(\.id)
                async let likes = api.getBatchLikeCounts(userId: userId, postIds: ids)
                async let comments = api.getBatchCommentCounts(userId: userId, postIds: ids)
                if let (l, c) = try? await (likes, comments) {
                    rm.batchInitializeCounts(likeCounts: l, commentCounts: c, posts: posts)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func removeBookmark(postId: String) async {
        do {
            try await LinkioAPIService().deleteBookmark(postId: postId, userId: userId)
        } catch {
            print("[SavedPosts] ❌ Failed to remove bookmark: \(error.localizedDescription)")
        }
        posts.removeAll { $0.id == postId }
    }
}

#Preview {
    NavigationStack {
        SavedPostsView()
    }
}
