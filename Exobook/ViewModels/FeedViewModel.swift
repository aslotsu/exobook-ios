//
//  FeedViewModel.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
class FeedViewModel {
    private let exobookAPI = ExobookAPIService()
    private let likesAPI = LikesAPIService()
    private let realtimeManager = RealtimeManager.shared
    private let cacheManager = StatsCacheManager.shared
    
    // State
    var posts: [Post] = []
    var filteredPosts: [Post] = []
    var isLoading = false
    var error: String?
    var selectedCourses: [String] = []
    
    private var cancellables = Set<AnyCancellable>()

    // Pagination state
    var currentPage = 1
    var hasMore = true
    var isLoadingMore = false
    let pageSize = 10
    
    // User context
    var currentUserId: String
    var userYear: Int
    var userCourses: [String] // course codes
    var userCampus: String
    
    // Like state tracking
    var likedPostIds: Set<String> = []
    var bookmarkedPostIds: Set<String> = []
    
    init(userId: String, year: Int, courses: [String], campus: String) {
        self.currentUserId = userId
        self.userYear = year
        self.userCourses = courses
        self.userCampus = campus
        self.selectedCourses = courses
    }
    
    // MARK: - Feed Operations
    
    func loadFeed() async {
        isLoading = true
        error = nil
        currentPage = 1
        hasMore = true

        do {
            let request = AllPostsRequest(
                courses: userCourses,
                year: userYear,
                id: currentUserId
            )

            // Fetch first page
            let response = try await exobookAPI.getAllPosts(
                request: request,
                page: currentPage,
                limit: pageSize
            )

            // Ensure unique posts
            var uniquePosts: [Post] = []
            var seenIds: Set<String> = []
            
            for post in response.posts {
                if !seenIds.contains(post.id) {
                    uniquePosts.append(post)
                    seenIds.insert(post.id)
                }
            }
            
            posts = uniquePosts
            hasMore = response.hasMore

            // IMPORTANT: Initialize RealtimeManager with Post model counts FIRST
            // This ensures UI shows counts immediately while Redis data loads
            realtimeManager.initializeCounts(posts: uniquePosts)

            applyFilters()

            // Batch fetch counts from Redis (will override Post counts with Redis data)
            await loadBatchStats()

            // Load like states for current user
            await loadLikeStates()

            print("[Feed] Loaded page \(currentPage) with \(response.posts.count) posts, hasMore: \(hasMore)")

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        // Don't load if already loading or no more pages
        guard !isLoadingMore && hasMore && !isLoading else {
            return
        }

        isLoadingMore = true
        currentPage += 1

        do {
            let request = AllPostsRequest(
                courses: userCourses,
                year: userYear,
                id: currentUserId
            )

            // Fetch next page
            let response = try await exobookAPI.getAllPosts(
                request: request,
                page: currentPage,
                limit: pageSize
            )

            // Filter out duplicates before appending
            let existingIds = Set(posts.map { $0.id })
            let newPosts = response.posts.filter { !existingIds.contains($0.id) }
            
            // Append new unique posts
            posts.append(contentsOf: newPosts)
            hasMore = response.hasMore

            // Initialize RealtimeManager with new posts' counts immediately
            realtimeManager.initializeCounts(posts: newPosts)

            applyFilters()

            // Load stats for new posts only from Redis (will override if different)
            let newPostIds = newPosts.map { $0.id }
            if !newPostIds.isEmpty {
                async let likeCounts = exobookAPI.getBatchLikeCounts(userId: currentUserId, postIds: newPostIds)
                async let commentCounts = exobookAPI.getBatchCommentCounts(userId: currentUserId, postIds: newPostIds)

                let (likes, comments) = try await (likeCounts, commentCounts)
                realtimeManager.batchInitializeCounts(
                    likeCounts: likes,
                    commentCounts: comments,
                    posts: newPosts
                )
            }

            // Load like states for new posts
            for post in newPosts {
                if let likes = post.likes, likes.contains(currentUserId) {
                    likedPostIds.insert(post.id)
                }
            }

            print("[Feed] Loaded page \(currentPage) with \(newPosts.count) new posts, hasMore: \(hasMore)")

        } catch {
            // Revert page on error
            currentPage = max(1, currentPage - 1)
            print("[Feed] ❌ Failed to load more posts: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }
    
    func refreshFeed() async {
        await loadFeed()
    }
    
    func applyFilters() {
        if selectedCourses.isEmpty {
            filteredPosts = posts
        } else {
            filteredPosts = posts.filter { post in
                selectedCourses.contains(post.subject)
            }
        }
    }
    
    func toggleCourseFilter(_ courseCode: String) {
        if selectedCourses.contains(courseCode) {
            selectedCourses.removeAll { $0 == courseCode }
        } else {
            selectedCourses.append(courseCode)
        }
        applyFilters()
    }
    
    func clearFilters() {
        selectedCourses = userCourses
        applyFilters()
    }
    
    // MARK: - Post Operations
    
    func createPost(user: User, title: String, content: String, subject: String?, images: [Data] = []) async throws {
        // Default to General - Campus if no subject selected
        let finalSubject = subject ?? "General - \(userCampus)"
        let bridgedContent = content.bridgedComposerHTML
        
        // 1. Create Post
        let request = CreatePostRequest(
            userId: user.id,
            username: user.name,
            userPicture: user.picture ?? "",
            userBio: user.bio ?? "",
            userProgramme: user.program ?? "",
            userYear: user.year ?? 0,
            userCampus: user.campus ?? "",
            title: title,
            content: bridgedContent,
            subject: finalSubject,
            tags: nil,
            images: []
        )
        
        var newPost = try await exobookAPI.createPost(request)
        
        // 2. Upload Images if any
        if !images.isEmpty {
            let filenames = try await exobookAPI.uploadImages(images)
            
            // 3. Update Post with Image Filenames
            if !filenames.isEmpty {
                newPost = try await exobookAPI.updatePostImages(postId: newPost.id, images: filenames)
            }
        }
        
        // 4. Add to beginning of feed
        posts.insert(newPost, at: 0)
        
        // 5. Ensure the new post is visible in current filters
        // If filters are active and don't include this subject, add it
        if !selectedCourses.isEmpty && !selectedCourses.contains(newPost.subject) {
            selectedCourses.append(newPost.subject)
        }
        
        applyFilters()
    }
    
    func deletePost(_ postId: String) async throws {
        _ = try await exobookAPI.deletePost(id: postId)
        
        // Remove from local state
        posts.removeAll { $0.id == postId }
        applyFilters()
    }
    
    // MARK: - Like Operations
    
    func toggleLike(for post: Post) async {
        let isLiked = likedPostIds.contains(post.id)

        // Optimistic update - update in-memory state
        if isLiked {
            likedPostIds.remove(post.id)
        } else {
            likedPostIds.insert(post.id)
        }

        // Optimistic update - persist to cache immediately for instant feedback
        cacheManager.updatePostLikeCount(
            postId: post.id,
            increment: !isLiked,
            isLiked: !isLiked
        )

        do {
            if isLiked {
                _ = try await likesAPI.unlikePost(postId: post.id, userId: currentUserId)
            } else {
                _ = try await likesAPI.likePost(postId: post.id, userId: currentUserId)
            }
            // Success - RealtimeManager will get Pusher event and update counts
        } catch {
            // Revert on error - both memory and cache
            if isLiked {
                likedPostIds.insert(post.id)
                cacheManager.updatePostLikeCount(postId: post.id, increment: true, isLiked: true)
            } else {
                likedPostIds.remove(post.id)
                cacheManager.updatePostLikeCount(postId: post.id, increment: false, isLiked: false)
            }
            print("[Feed] ❌ Failed to toggle like: \(error.localizedDescription)")
        }
    }
    
    func loadBatchStats() async {
        guard !posts.isEmpty else { return }
        
        let postIds = posts.map { $0.id }
        
        do {
            // Follow frontend pattern: use batch API endpoints to get counts
            async let likeCounts = exobookAPI.getBatchLikeCounts(userId: currentUserId, postIds: postIds)
            async let commentCounts = exobookAPI.getBatchCommentCounts(userId: currentUserId, postIds: postIds)
            
            let (likes, comments) = try await (likeCounts, commentCounts)
            
            // Initialize RealtimeManager with actual counts from API
            realtimeManager.batchInitializeCounts(
                likeCounts: likes,
                commentCounts: comments,
                posts: posts
            )
            
            print("[Feed] 📊 Loaded batch stats for \(postIds.count) posts - likes: \(likes.count), comments: \(comments.count)")
            
        } catch {
            print("[Feed] ⚠️ Failed to load batch stats: \(error.localizedDescription)")
            
            // Fallback: Use Post model data as initial values
            // This ensures we have some data even if API calls fail
            realtimeManager.initializeCounts(posts: posts)
            print("[Feed] 📊 Using fallback counts from Post model data")
        }
    }
    
    func loadLikeStates() async {
        // Try to fetch from Likes API first
        do {
            let response = try await likesAPI.getUserLikedPosts(userId: currentUserId)
            let likedIds = Set(response.posts)
            
            // Update local state
            self.likedPostIds = likedIds
            
            // Update RealtimeManager state
            realtimeManager.likedPostIds = likedIds
            
            // Update Cache for visible posts
            for post in posts {
                let isLiked = likedIds.contains(post.id)
                cacheManager.updatePostLikeStatus(postId: post.id, isLiked: isLiked)
            }
            
            print("[Feed] ❤️ Loaded \(likedIds.count) liked posts from API")
            
        } catch {
            print("[Feed] ⚠️ Failed to load likes from API: \(error.localizedDescription)")
            // Fallback to Post model data
            for post in posts {
                if let likes = post.likes, likes.contains(currentUserId) {
                    likedPostIds.insert(post.id)
                    // Also update cache for fallback
                    cacheManager.updatePostLikeStatus(postId: post.id, isLiked: true)
                }
            }
            // Update RealtimeManager with fallback
            realtimeManager.likedPostIds = likedPostIds
        }
    }
    
    func isLiked(_ postId: String) -> Bool {
        likedPostIds.contains(postId)
    }
    
    // MARK: - Bookmark Operations
    
    func toggleBookmark(for postId: String) {
        if bookmarkedPostIds.contains(postId) {
            bookmarkedPostIds.remove(postId)
        } else {
            bookmarkedPostIds.insert(postId)
        }
        
        // TODO: Persist to backend/UserDefaults
        saveBookmarks()
    }
    
    func isBookmarked(_ postId: String) -> Bool {
        bookmarkedPostIds.contains(postId)
    }
    
    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarkedPostIds), forKey: "bookmarked_posts_\(currentUserId)")
    }
    
    private func loadBookmarks() {
        if let saved = UserDefaults.standard.array(forKey: "bookmarked_posts_\(currentUserId)") as? [String] {
            bookmarkedPostIds = Set(saved)
        }
    }
    
    // MARK: - Real-time Updates (Placeholder)
    
    func subscribeToRealtimeUpdates() {
        print("🔌 Subscribing to real-time feed updates...")
        
        realtimeManager.newPostSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] post in
                self?.handleNewRealtimePost(post)
            }
            .store(in: &cancellables)
    }
    
    private func handleNewRealtimePost(_ post: Post) {
        // 1. Check if already exists (deduplication)
        guard !posts.contains(where: { $0.id == post.id }) else {
            return
        }
        
        print("✨ [Feed] Handling new real-time post: \(post.title)")
        
        // 2. Add to beginning of posts array
        withAnimation {
            posts.insert(post, at: 0)
        }
        
        // 3. Initialize counts for this new post
        realtimeManager.initializeCounts(posts: [post])
        
        // 4. Update filtering if strictly needed, or just allow it to appear if it matches?
        // Behavior decision: Should a new post appearing be subject to current filters?
        // Yes, otherwise it looks broken.
        // If current filter excludes it (e.g. filtered by "CS101" but post is "General"),
        // it should NOT appear in filteredPosts.
        
        if selectedCourses.isEmpty || selectedCourses.contains(post.subject) {
            // Apply filters to update the view
            applyFilters()
        }
    }
    
    func unsubscribeFromRealtimeUpdates() {
        // TODO: Cleanup Pusher subscriptions
        print("Unsubscribing from real-time updates")
    }
}
