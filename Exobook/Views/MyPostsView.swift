//
//  MyPostsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/01/2026.
//

import SwiftUI

struct MyPostsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: MyPostsViewModel?
    @State private var selectedPost: Post?
    
    var body: some View {
        ScrollView {
            if let viewModel = viewModel {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No posts yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create your first post to see it here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.posts) { post in
                            PostCard(
                                post: post,
                                currentUserId: currentUser?.id ?? "",
                                isBookmarked: false,
                                onLike: {},
                                onComment: {},
                                onBookmark: {},
                                onDelete: {
                                    Task {
                                        await viewModel.deletePost(post)
                                    }
                                },
                                onReport: {}
                            )
                            .onTapGesture {
                                selectedPost = post
                            }
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .navigationTitle("My Posts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil, let userId = currentUser?.id {
                viewModel = MyPostsViewModel(userId: userId)
                await viewModel?.loadPosts()
            }
        }
        .refreshable {
            await viewModel?.loadPosts()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
class MyPostsViewModel {
    let userId: String
    private let api = ExobookAPIService()
    
    var posts: [Post] = []
    var isLoading = false
    
    init(userId: String) {
        self.userId = userId
    }
    
    func loadPosts() async {
        isLoading = true
        do {
            posts = try await api.getUserPosts(userId: userId)
            print("✅ Loaded \(posts.count) posts for current user")
        } catch {
            print("❌ Failed to load user posts: \(error)")
            posts = []
        }
        isLoading = false
    }
    
    func deletePost(_ post: Post) async {
        do {
            _ = try await api.deletePost(id: post.id)
            // Remove from local list
            posts.removeAll { $0.id == post.id }
            print("✅ Deleted post \(post.id)")
        } catch {
            print("❌ Failed to delete post: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        MyPostsView()
    }
}
