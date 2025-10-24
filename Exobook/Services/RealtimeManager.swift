//
//  RealtimeManager.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import PusherSwift
import Observation

@MainActor
@Observable
final class RealtimeManager {
    static let shared = RealtimeManager()
    
    // State
    private var pusher: Pusher!
    private var currentUserId: String?
    
    // Channels
    private var postsChannel: PusherChannel?
    private var commentsChannel: PusherChannel?
    private var likesChannel: PusherChannel?
    private var repliesChannel: PusherChannel?
    private var chatsChannel: PusherChannel?
    private var userChatChannel: PusherChannel?
    
    // Counts dictionaries (postId: count)
    var likeCount: [String: Int] = [:]
    var commentCount: [String: Int] = [:]
    var replyLikeCount: [String: Int] = [:]
    var replyCount: [String: Int] = [:]
    
    // Like tracking (to determine if current user liked)
    var likedPostIds: Set<String> = []
    var likedCommentIds: Set<String> = []
    
    private init() {}
    
    // MARK: - Setup
    
    func configure(pusherKey: String, cluster: String, userId: String) {
        self.currentUserId = userId
        
        let options = PusherClientOptions(host: .cluster(cluster))
        pusher = Pusher(key: pusherKey, options: options)
        pusher.connection.delegate = self
        
        // Subscribe to channels
        postsChannel = pusher.subscribe("posts")
        commentsChannel = pusher.subscribe("reply")
        likesChannel = pusher.subscribe("LIKES")
        repliesChannel = pusher.subscribe("REPLIES")
        chatsChannel = pusher.subscribe("chats")
        
        // User-specific chat channel
        userChatChannel = pusher.subscribe("user-\(userId)-chats")
        
        setupEventHandlers()
        pusher.connect()
        
        print("🔴 Pusher configured for user: \(userId)")
    }
    
    // MARK: - Event Handlers Setup
    
    private func setupEventHandlers() {
        guard let currentUserId = currentUserId else { return }
        
        // Post Likes
        likesChannel?.bind(eventName: "POST_LIKE") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handlePostLike(data, userId: currentUserId)
            }
        }
        
        likesChannel?.bind(eventName: "POST_UNLIKE") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handlePostUnlike(data, userId: currentUserId)
            }
        }
        
        // Comments
        commentsChannel?.bind(eventName: "NEW-COMMENT1") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleNewComment(data, userId: currentUserId)
            }
        }
        
        commentsChannel?.bind(eventName: "COMMENT-DELETED") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleCommentDeleted(data)
            }
        }
        
        // Comment Likes
        likesChannel?.bind(eventName: "COMMENT_LIKE") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleCommentLike(data, userId: currentUserId)
            }
        }
        
        repliesChannel?.bind(eventName: "COMMENT-UNLIKE") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleCommentUnlike(data, userId: currentUserId)
            }
        }
        
        // Post Deleted
        postsChannel?.bind(eventName: "POST-DELETED") { [weak self] data in
            guard let self = self else { return }
            Task { @MainActor in
                self.handlePostDeleted(data)
            }
        }
        
        print("✅ Pusher event handlers configured")
    }
    
    // MARK: - Event Handlers
    
    private func handlePostLike(_ data: Any?, userId: String) {
        guard let dict = data as? [String: Any],
              let like = dict["like"] as? [String: Any],
              let count = dict["count"] as? Int,
              let postId = like["post_id"] as? String,
              let likeUserId = like["user_id"] as? String else {
            print("⚠️ Invalid POST_LIKE data")
            return
        }
        
        print("❤️ POST_LIKE: \(postId) by \(likeUserId), count: \(count)")
        
        // Update count
        likeCount[postId] = count
        
        // Track if current user liked it
        if likeUserId == userId {
            likedPostIds.insert(postId)
        }
        
        // Notification: Someone liked MY post
        if let owner = like["owner"] as? String,
           owner == userId && likeUserId != userId,
           let username = like["username"] as? String {
            showNotification(
                title: "👍 \(username) liked your post!",
                body: "Your content is getting engagement!"
            )
        }
    }
    
    private func handlePostUnlike(_ data: Any?, userId: String) {
        guard let dict = data as? [String: Any] else { return }
        
        let postId = (dict["like"] as? [String: Any])?["post_id"] as? String ?? dict["PostID"] as? String
        let unlikeUserId = (dict["like"] as? [String: Any])?["user_id"] as? String ?? dict["UserID"] as? String
        
        guard let postId = postId, let unlikeUserId = unlikeUserId else { return }
        
        print("💔 POST_UNLIKE: \(postId) by \(unlikeUserId)")
        
        // Decrement count
        likeCount[postId] = max((likeCount[postId] ?? 1) - 1, 0)
        
        // Remove from liked set if current user
        if unlikeUserId == userId {
            likedPostIds.remove(postId)
        }
    }
    
    private func handleNewComment(_ data: Any?, userId: String) {
        guard let dict = data as? [String: Any],
              let postId = dict["post_id"] as? String,
              let commentUserId = dict["user_id"] as? String else {
            return
        }
        
        print("💬 NEW-COMMENT: \(postId) by \(commentUserId)")
        
        // Increment comment count
        commentCount[postId] = (commentCount[postId] ?? 0) + 1
        
        // Notification: Someone commented on MY post
        if let owner = dict["owner"] as? String,
           owner == userId && commentUserId != userId,
           let username = dict["user_name"] as? String {
            let content = dict["content"] as? String ?? ""
            let excerpt = String(content.prefix(50))
            showNotification(
                title: "💬 \(username) commented on your post",
                body: excerpt.isEmpty ? "Check out their comment" : "\"\(excerpt)...\""
            )
        }
    }
    
    private func handleCommentDeleted(_ data: Any?) {
        guard let dict = data as? [String: Any],
              let postId = dict["post_id"] as? String else {
            return
        }
        
        print("🗑️ COMMENT-DELETED: \(postId)")
        
        // Decrement comment count
        commentCount[postId] = max((commentCount[postId] ?? 1) - 1, 0)
    }
    
    private func handleCommentLike(_ data: Any?, userId: String) {
        guard let dict = data as? [String: Any],
              let commentId = dict["post_id"] as? String, // Note: post_id is actually commentId for comment likes
              let likeUserId = dict["user_id"] as? String else {
            return
        }
        
        print("❤️ COMMENT_LIKE: \(commentId) by \(likeUserId)")
        
        // Ignore own likes (already optimistically updated)
        guard likeUserId != userId else { return }
        
        // Update count
        if let count = dict["count"] as? Int {
            replyLikeCount[commentId] = count
        } else {
            replyLikeCount[commentId] = (replyLikeCount[commentId] ?? 0) + 1
        }
        
        // Notification: Someone liked MY comment
        if let owner = dict["owner"] as? String,
           owner == userId,
           let username = dict["username"] as? String {
            showNotification(
                title: "❤️ \(username) liked your comment!",
                body: "Your comment resonated with someone!"
            )
        }
    }
    
    private func handleCommentUnlike(_ data: Any?, userId: String) {
        guard let dict = data as? [String: Any] else { return }
        
        let commentId = dict["ID"] as? String ?? dict["replyId"] as? String
        let unlikeUserId = dict["User"] as? String ?? dict["user_id"] as? String
        
        guard let commentId = commentId, let unlikeUserId = unlikeUserId else { return }
        
        print("💔 COMMENT-UNLIKE: \(commentId) by \(unlikeUserId)")
        
        // Ignore own unlikes
        guard unlikeUserId != userId else { return }
        
        // Decrement count
        replyLikeCount[commentId] = max((replyLikeCount[commentId] ?? 1) - 1, 0)
    }
    
    private func handlePostDeleted(_ data: Any?) {
        guard let dict = data as? [String: Any],
              let postId = dict["id"] as? String else {
            return
        }
        
        print("🗑️ POST-DELETED: \(postId)")
        
        // Clean up counts for deleted post
        likeCount.removeValue(forKey: postId)
        commentCount.removeValue(forKey: postId)
        likedPostIds.remove(postId)
    }
    
    // MARK: - Public Helpers
    
    func getLikeCount(for postId: String) -> Int {
        likeCount[postId] ?? 0
    }
    
    func getCommentCount(for postId: String) -> Int {
        commentCount[postId] ?? 0
    }
    
    func isLiked(_ postId: String) -> Bool {
        likedPostIds.contains(postId)
    }
    
    func isCommentLiked(_ commentId: String) -> Bool {
        likedCommentIds.contains(commentId)
    }
    
    // Initialize counts from existing data
    func initializeCounts(posts: [Post]) {
        for post in posts {
            likeCount[post.id] = post.likeCount
            commentCount[post.id] = post.commentCount
            
            // Check if current user liked this post
            if let likes = post.likes, let userId = currentUserId, likes.contains(userId) {
                likedPostIds.insert(post.id)
            }
        }
        print("📊 Initialized counts for \(posts.count) posts")
    }
    
    // Batch initialize counts from Redis
    func batchInitializeCounts(likeCounts: [String: Int], commentCounts: [String: Int], posts: [Post]) {
        // Use Redis counts as source of truth
        for (postId, count) in likeCounts {
            likeCount[postId] = count
        }
        
        for (postId, count) in commentCounts {
            commentCount[postId] = count
        }
        
        // Still need to check which posts current user liked
        guard let userId = currentUserId else { return }
        for post in posts {
            if let likes = post.likes, likes.contains(userId) {
                likedPostIds.insert(post.id)
            }
        }
        
        print("📊 Batch initialized counts: \(likeCounts.count) likes, \(commentCounts.count) comments")
    }
    
    // MARK: - Notifications
    
    private func showNotification(title: String, body: String) {
        // You can use UserNotifications framework for local notifications
        // or show in-app toasts
        print("🔔 \(title): \(body)")
        
        // TODO: Implement actual notification display
        // For now, just logging
    }
    
    // MARK: - Cleanup
    
    func disconnect() {
        postsChannel?.unbindAll()
        commentsChannel?.unbindAll()
        likesChannel?.unbindAll()
        repliesChannel?.unbindAll()
        chatsChannel?.unbindAll()
        userChatChannel?.unbindAll()
        
        pusher?.unsubscribe("posts")
        pusher?.unsubscribe("reply")
        pusher?.unsubscribe("LIKES")
        pusher?.unsubscribe("REPLIES")
        pusher?.unsubscribe("chats")
        
        if let userId = currentUserId {
            pusher?.unsubscribe("user-\(userId)-chats")
        }
        
        pusher?.disconnect()
        
        print("🔴 Pusher disconnected")
    }
}

// MARK: - PusherDelegate

extension RealtimeManager: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        print("🔄 Pusher: \(old.stringValue()) → \(new.stringValue())")
    }
    
    func debugLog(message: String) {
        print("🔍 Pusher: \(message)")
    }
    
    func subscribedToChannel(name: String) {
        print("✅ Subscribed to: \(name)")
    }
    
    func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: Error?) {
        print("❌ Failed to subscribe to: \(name), error: \(error?.localizedDescription ?? "unknown")")
    }
}
