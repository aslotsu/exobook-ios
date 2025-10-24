//
//  FeedView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct FeedView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: FeedViewModel?
    @State private var showingComposer = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    feedContent(viewModel: viewModel)
                } else if let user = currentUser {
                    // Initialize view model once user is available
                    Color.clear.onAppear {
                        initializeViewModel(for: user)
                    }
                } else {
                    // Shouldn't happen as AppView guards authentication
                    Text("User not found")
                }
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
                if let viewModel = viewModel {
                    PostComposerView(viewModel: viewModel)
                }
            }
        }
    }
    
    @ViewBuilder
    private func feedContent(viewModel: FeedViewModel) -> some View {
        VStack(spacing: 0) {
            // Course filter section (fixed at top)
            CourseFilterBar(viewModel: viewModel)
                .background(adaptiveBackground)
            
            Divider()
            
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Post composer button
                    if let user = currentUser {
                        PostComposerButton(firstName: user.name.components(separatedBy: " ").first ?? "there") {
                            showingComposer = true
                        }
                        .padding(.horizontal)
                    }
                
                // Loading state
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .padding()
                }
                    
                    // Posts
                    ForEach(viewModel.filteredPosts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
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
                                    // Navigation handled by NavigationLink
                                },
                                onBookmark: {
                                    viewModel.toggleBookmark(for: post.id)
                                }
                            )
                        }
                        .buttonStyle(.plain)
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
            .task {
                await viewModel.loadFeed()
            }
            .background(adaptiveBackground)
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
    
    private func initializeViewModel(for user: User) {
        // Get user's enrolled course codes
        var feedCourses = user.courseCodes
        
        // Only add general campus feed if it's not already in the list
        let generalFeed = "General - \(user.campus ?? "Main Campus")"
        if !feedCourses.contains(generalFeed) {
            feedCourses.append(generalFeed)
        }
        
        // Debug: Print courses
        print("📚 User courses loaded: \(feedCourses)")
        
        viewModel = FeedViewModel(
            userId: user.id,
            year: user.year ?? 1,
            courses: feedCourses,
            campus: user.campus ?? "Main Campus"
        )
    }
}

// MARK: - Course Filter Bar

struct CourseFilterBar: View {
    @Bindable var viewModel: FeedViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter by Course")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.selectedCourses.count != viewModel.userCourses.count {
                    Button(action: { viewModel.clearFilters() }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.userCourses, id: \.self) { course in
                        CourseFilterChip(
                            title: course,
                            isSelected: viewModel.selectedCourses.contains(course),
                            action: {
                                viewModel.toggleCourseFilter(course)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }
}

struct CourseFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.blue
                    : Color(uiColor: .secondarySystemBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Post Composer Button

struct PostComposerButton: View {
    let firstName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // User avatar placeholder
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(firstName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Prompt text
                Text("What's on your mind, \(firstName)?")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Image icon
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FeedView()
}
