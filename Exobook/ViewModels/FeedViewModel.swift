//
//  FeedViewModel.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class FeedViewModel {
    private let exobookAPI = ExobookAPIService()
    private let likesAPI = LikesAPIService()
    private let realtimeManager = RealtimeManager.shared
    
    // State
    var posts: [Post] = []
    var filteredPosts: [Post] = []
    var isLoading = false
    var error: String?
    var selectedCourses: [String] = []
    
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
        
        do {
            // Add general campus feed to courses
            var coursesToFetch = userCourses
            coursesToFetch.append("General - \(userCampus)")
            
            let request = AllPostsRequest(
                courses: coursesToFetch,
                year: userYear,
                id: currentUserId
            )
            
            posts = try await exobookAPI.getAllPosts(request: request)
            applyFilters()
            
            // Batch fetch counts from Redis
            await loadBatchStats()
            
            // Load like states for current user
            await loadLikeStates()
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
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
    
    func createPost(title: String, content: String, images: [String] = []) async throws {
        let request = CreatePostRequest(
            userId: currentUserId,
            title: title,
            content: content,
            tags: nil
        )
        
        let newPost = try await exobookAPI.createPost(request)
        
        // Add to beginning of feed
        posts.insert(newPost, at: 0)
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
        
        // Optimistic update
        if isLiked {
            likedPostIds.remove(post.id)
        } else {
            likedPostIds.insert(post.id)
        }
        
        do {
            if isLiked {
                _ = try await likesAPI.unlikePost(postId: post.id, userId: currentUserId)
            } else {
                _ = try await likesAPI.likePost(postId: post.id, userId: currentUserId)
            }
        } catch {
            // Revert on error
            if isLiked {
                likedPostIds.insert(post.id)
            } else {
                likedPostIds.remove(post.id)
            }
            print("Failed to toggle like: \(error)")
        }
    }
    
    func loadBatchStats() async {
        guard !posts.isEmpty else { return }
        
        let postIds = posts.map { $0.id }
        
        do {
            // Fetch like and comment counts in parallel
            async let likeCounts = exobookAPI.getBatchLikeCounts(userId: currentUserId, postIds: postIds)
            async let commentCounts = exobookAPI.getBatchCommentCounts(userId: currentUserId, postIds: postIds)
            
            let (likes, comments) = try await (likeCounts, commentCounts)
            
            // Initialize RealtimeManager with batch stats
            realtimeManager.batchInitializeCounts(
                likeCounts: likes,
                commentCounts: comments,
                posts: posts
            )
            
            print("📊 Batch loaded stats for \(postIds.count) posts")
        } catch {
            print("⚠️ Failed to load batch stats: \(error)")
            // Fallback to Post model data
            realtimeManager.initializeCounts(posts: posts)
        }
    }
    
    func loadLikeStates() async {
        // Note: Backend doesn't support batch like status checks
        // We'll load like states on-demand or use post.likes array from API
        // For now, just extract from post data
        for post in posts {
            if let likes = post.likes, likes.contains(currentUserId) {
                likedPostIds.insert(post.id)
            }
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
        // TODO: Integrate Pusher
        // pusher.subscribe("posts")
        // channel.bind("new-post") { ... }
        print("Real-time updates not yet implemented")
    }
    
    func unsubscribeFromRealtimeUpdates() {
        // TODO: Cleanup Pusher subscriptions
        print("Unsubscribing from real-time updates")
    }
}
