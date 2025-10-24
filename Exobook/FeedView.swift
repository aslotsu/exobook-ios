//
//  FeedView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel(
        userId: "test-user",
        year: 2,
        courses: ["CS101", "MATH201"],
        campus: "Main Campus"
    )
    @State private var showingComposer = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Post composer button
                    PostComposerButton {
                        showingComposer = true
                    }
                    .padding(.horizontal)
                    
                    // Loading state
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding()
                    }
                    
                    // Posts
                    ForEach(viewModel.filteredPosts) { post in
                        PostCard(
                            post: post,
                            isLiked: viewModel.isLiked(post.id),
                            isBookmarked: viewModel.isBookmarked(post.id),
                            onLike: {
                                Task {
                                    await viewModel.toggleLike(for: post)
                                }
                            },
                            onComment: {
                                // TODO: Navigate to comments
                                print("Show comments for post \(post.id)")
                            },
                            onBookmark: {
                                viewModel.toggleBookmark(for: post.id)
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Empty state
                    if !viewModel.isLoading && viewModel.filteredPosts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No posts yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Be the first to share something!")
                                .foregroundColor(.secondary)
                            Button("Create Post") {
                                showingComposer = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingComposer = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                PostComposerView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadFeed()
            }
        }
    }
}

// MARK: - Post Composer Button

struct PostComposerButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                Text("Share your thoughts...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FeedView()
}
