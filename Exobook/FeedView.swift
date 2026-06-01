//
//  FeedView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI
import Combine

struct FeedView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: FeedViewModel?
    @State private var showingComposer = false
    @State private var showingSearch = false
    @State private var showingNotifications = false
    @State private var unreadNotifCount = 0
    @State private var notifSubscription: AnyCancellable?
    private let notifAPI = NotificationsAPIService()
    
    var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Search
                    Button { showingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    // Notifications bell with badge
                    Button { showingNotifications = true } label: {
                        Image(systemName: unreadNotifCount > 0 ? "bell.badge.fill" : "bell")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(unreadNotifCount > 0 ? Color.blue : Color.primary)
                    }
                    .overlay(alignment: .topTrailing) {
                        if unreadNotifCount > 0 {
                            Text(unreadNotifCount > 99 ? "99+" : "\(unreadNotifCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingComposer) {
            if let viewModel = viewModel {
                PostComposerView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView(user: currentUser)
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
                .onDisappear { Task { await refreshNotifCount() } }
        }
        .task(id: currentUser?.id) {
            await refreshNotifCount()
            subscribeToNotifEvents()
        }
        .onChange(of: feedCourseSignature(for: currentUser), initial: false) { _, _ in
            guard let user = currentUser else {
                viewModel = nil
                return
            }
            syncViewModel(for: user)
        }
    }
    
    @ViewBuilder
    private func feedContent(viewModel: FeedViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Linkio")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color.appBackground)

            CourseFilterBar(viewModel: viewModel)
                .background(Color.appBackground)
            
            Divider()
            
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 16) {
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
                                currentUserId: currentUser?.id ?? "",
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
                                },
                                onDelete: {
                                    Task {
                                        do {
                                            try await viewModel.deletePost(post.id)
                                        } catch {
                                            print("Failed to delete post: \(error)")
                                        }
                                    }
                                },
                                onReport: {
                                    print("Reported post: \(post.id)")
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .onAppear {
                            // Trigger load more when last post appears
                            if post.id == viewModel.filteredPosts.last?.id {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                    }

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            ProgressView()
                            Text("Loading more posts...")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    
                    // All caught up footer
                    if !viewModel.hasMore && !viewModel.filteredPosts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("All caught up!")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("You've reached the end of your feed")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
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
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 59)
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
            .task {
                await viewModel.loadFeed()
                viewModel.subscribeToRealtimeUpdates()
            }
            .background(Color.appBackground)
            .overlay(alignment: .bottomTrailing) {
                composeFAB
            }
        }
    }

    private var composeFAB: some View {
        Button {
            showingComposer = true
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: Color.blue.opacity(0.35), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    private func refreshNotifCount() async {
        guard let userId = currentUser?.id else { return }
        if let count = try? await notifAPI.fetchUnreadCount(userId: userId) {
            unreadNotifCount = count
        }
    }

    private func subscribeToNotifEvents() {
        guard notifSubscription == nil else { return }
        notifSubscription = RealtimeManager.shared.newNotificationSubject
            .receive(on: DispatchQueue.main)
            .sink { _ in Task { @MainActor in await refreshNotifCount() } }
    }

    private func initializeViewModel(for user: User) {
        let feedCourses = resolvedFeedCourses(for: user)
        
        // Debug: Print courses
        print("📚 User courses loaded: \(feedCourses)")
        
        viewModel = FeedViewModel(
            userId: user.id,
            userName: user.name,
            userPicture: user.picture ?? "",
            userBio: user.bio ?? "",
            year: user.year ?? 1,
            courses: feedCourses,
            campus: user.campus ?? "Main Campus"
        )
    }

    private func syncViewModel(for user: User) {
        guard let viewModel else {
            initializeViewModel(for: user)
            return
        }

        let feedCourses = resolvedFeedCourses(for: user)
        guard viewModel.currentUserId == user.id else {
            initializeViewModel(for: user)
            return
        }

        guard viewModel.userCourses != feedCourses || viewModel.userYear != (user.year ?? 1) else {
            return
        }

        viewModel.userName = user.name
        viewModel.userPicture = user.picture ?? ""
        viewModel.userBio = user.bio ?? ""
        viewModel.userYear = user.year ?? 1
        viewModel.userCampus = user.campus ?? "Main Campus"
        viewModel.userCourses = feedCourses
        viewModel.selectedCourses = feedCourses
        viewModel.applyFilters()

        print("📚 User courses refreshed: \(feedCourses)")

        Task {
            await viewModel.refreshFeed()
        }
    }

    private func resolvedFeedCourses(for user: User) -> [String] {
        let generalFeed = "General - \(user.campus ?? "Main Campus")"
        return (user.courseCodes + [generalFeed]).reduce(into: [String]()) { courses, course in
            let normalizedCourse = course.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedCourse.isEmpty, !courses.contains(normalizedCourse) else { return }
            courses.append(normalizedCourse)
        }
    }

    private func feedCourseSignature(for user: User?) -> String {
        guard let user else { return "signed-out" }
        return resolvedFeedCourses(for: user).joined(separator: "|") + "|year:\(user.year ?? 1)"
    }
}

// MARK: - Course Filter Bar

struct CourseFilterBar: View {
    @Bindable var viewModel: FeedViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .padding(.vertical, 10)
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
                    .lineLimit(1)
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
