//
//  RealtimeManager.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import PusherSwift
import Observation
import Combine
import os

@MainActor
@Observable
final class RealtimeManager {
    static let shared = RealtimeManager()

    // Subjects
    let newPostSubject = PassthroughSubject<Post, Never>()

    /// Fires once per `new-notification` Pusher event from `user-{userId}-notifications`.
    /// Consumers (e.g. MainTabs bell badge) re-fetch unread count when this fires.
    let newNotificationSubject = PassthroughSubject<Void, Never>()

    // Helpers
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // Matches NetworkService
        return decoder
    }()


    // State
    private var pusher: Pusher!
    private var currentUserId: String?
    private let cacheManager = StatsCacheManager.shared

    // Channels
    private var postsChannel: PusherChannel?
    private var commentsChannel: PusherChannel?
    private var likesChannel: PusherChannel?
    private var repliesChannel: PusherChannel?
    private var userNotifChannel: PusherChannel?
    private var userChatsChannel: PusherChannel?   // user-{userId}-chats: invites + member-joined

    // Per-chat channels and message publishers, keyed by chatId.
    // Chat subscriptions are demand-loaded from LinkioChatService rather than
    // eagerly subscribed at configure() time.
    private var chatChannels: [String: PusherChannel] = [:]
    private var chatMessageSubjects: [String: PassthroughSubject<Message, Never>] = [:]
    private var chatTypingSubjects: [String: PassthroughSubject<(userId: String, isTyping: Bool), Never>] = [:]

    // Counts dictionaries (postId: count) - in-memory for fast access
    var likeCount: [String: Int] = [:]
    var commentCount: [String: Int] = [:]
    var replyLikeCount: [String: Int] = [:]
    var replyCount: [String: Int] = [:]

    // Like tracking (to determine if current user liked)
    var likedPostIds: Set<String> = []
    var likedCommentIds: Set<String> = []

    private init() {
        // Load cached stats into memory on init
        loadCachedStats()
    }
    
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
        userNotifChannel = pusher.subscribe("user-\(userId)-notifications")
        userChatsChannel = pusher.subscribe("user-\(userId)-chats")

        setupEventHandlers()
        setupUserNotifHandler(userId: userId)
        setupUserChatsHandler(userId: userId)
        pusher.connect()

        print("🔴 Pusher configured for user: \(userId)")
    }

    // MARK: - Chat Subscriptions

    /// Subscribe to live messages on a chat thread. Returns a publisher the
    /// caller can sink on. Idempotent: repeated calls return the same publisher.
    func chatMessagePublisher(chatId: String) -> AnyPublisher<Message, Never> {
        if let subject = chatMessageSubjects[chatId] {
            return subject.eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<Message, Never>()
        chatMessageSubjects[chatId] = subject

        guard let pusher = pusher else {
            print("⚠️ Pusher not configured before subscribing to chat: \(chatId)")
            return subject.eraseToAnyPublisher()
        }

        let channelName = "chat-\(chatId)"
        let channel = pusher.subscribe(channelName)
        chatChannels[chatId] = channel

        channel.bind(eventName: "new-message") { [weak self] event in
            guard let self = self,
                  let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse new-message event for chat: \(chatId)")
                return
            }

            Task { @MainActor in
                guard let message = self.decodeChatMessage(json, chatId: chatId) else { return }
                self.chatMessageSubjects[chatId]?.send(message)
            }
        }

        print("✅ Subscribed to chat channel: \(channelName)")
        return subject.eraseToAnyPublisher()
    }

    /// Unsubscribe from a chat thread. Tears down the channel and publisher.
    func unsubscribeFromChat(chatId: String) {
        if let channel = chatChannels.removeValue(forKey: chatId) {
            channel.unbindAll()
        }
        pusher?.unsubscribe("chat-\(chatId)")
        chatMessageSubjects.removeValue(forKey: chatId)
        chatTypingSubjects.removeValue(forKey: chatId)
        Log.chat.info("Unsubscribed from chat: \(chatId)")
    }

    /// Publisher that emits (userId, isTyping) pairs for the given chat.
    /// Binds to the existing chat-{chatId} channel (subscribing if needed).
    func typingPublisher(chatId: String) -> AnyPublisher<(userId: String, isTyping: Bool), Never> {
        if let subject = chatTypingSubjects[chatId] {
            return subject.eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<(userId: String, isTyping: Bool), Never>()
        chatTypingSubjects[chatId] = subject

        // Ensure the channel is subscribed (chatMessagePublisher may have already done this).
        let channelName = "chat-\(chatId)"
        let channel: PusherChannel
        if let existing = chatChannels[chatId] {
            channel = existing
        } else {
            guard let pusher = pusher else { return subject.eraseToAnyPublisher() }
            channel = pusher.subscribe(channelName)
            chatChannels[chatId] = channel
        }

        channel.bind(eventName: "user_typing") { [weak self] event in
            guard let self,
                  let data = event.data,
                  let json = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
                  let userId = json["user_id"] as? String,
                  userId != self.currentUserId else { return }
            Task { @MainActor in self.chatTypingSubjects[chatId]?.send((userId, true)) }
        }

        channel.bind(eventName: "user_stop_typing") { [weak self] event in
            guard let self,
                  let data = event.data,
                  let json = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
                  let userId = json["user_id"] as? String else { return }
            Task { @MainActor in self.chatTypingSubjects[chatId]?.send((userId, false)) }
        }

        return subject.eraseToAnyPublisher()
    }

    /// Decode a Pusher `new-message` payload into a `Message`.
    /// Returns nil for messages from the current user (already shown optimistically).
    private func decodeChatMessage(_ data: [String: Any], chatId: String) -> Message? {
        guard let messageId = data["message_id"] as? String,
              let userId = data["user_id"] as? String,
              let timestamp = data["timestamp"] as? Int64 else {
            print("❌ Invalid new-message structure for chat \(chatId): \(data)")
            return nil
        }

        // Skip echoes of the current user's own optimistic messages.
        if userId == currentUserId { return nil }

        return Message(
            id: messageId,
            chatId: chatId,
            senderId: userId,
            text: data["words"] as? String ?? "",
            createdAt: Date(timeIntervalSince1970: Double(timestamp) / 1000.0),
            isMine: false,
            images: data["images"] as? [String],
            files: data["files"] as? [String]
        )
    }
    
    // MARK: - Event Handlers Setup
    
    private func setupEventHandlers() {
        guard let currentUserId = currentUserId else { return }
        
        print("🔧 Setting up Pusher event handlers for user: \(currentUserId)")
        
        // New Post (Global/Feed)
        postsChannel?.bind(eventName: "new-post") { [weak self] event in
            print("📥 [PUSHER EVENT] new-post received")
            guard let self = self else { return }
            
            // 1. Extract data string
            guard let eventData = event.data else {
                print("❌ new-post event has no data")
                return
            }
            
            // 2. Decode directly to Post object
            // The data string is a JSON object string.
            guard let jsonData = eventData.data(using: .utf8) else {
                print("❌ Failed to convert new-post data to Data")
                return
            }
            
            do {
                // The log shows the data is a JSON string of the post object
                let post = try self.decoder.decode(Post.self, from: jsonData)
                print("📝 New Post Parsed: \(post.title) by \(post.username)")
                
                Task { @MainActor in
                    self.newPostSubject.send(post)
                }
            } catch {
                print("❌ Failed to decode new-post: \(error)")
                print("📦 Data: \(eventData)")
            }
        }

        // Post Likes
        likesChannel?.bind(eventName: "POST_LIKE") { [weak self] event in
            print("📥 [PUSHER EVENT] POST_LIKE received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse POST_LIKE event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handlePostLike(json, userId: currentUserId)
            }
        }
        
        likesChannel?.bind(eventName: "POST_UNLIKE") { [weak self] event in
            print("📥 [PUSHER EVENT] POST_UNLIKE received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse POST_UNLIKE event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handlePostUnlike(json, userId: currentUserId)
            }
        }
        
        // Comments
        commentsChannel?.bind(eventName: "NEW-COMMENT1") { [weak self] event in
            print("📥 [PUSHER EVENT] NEW-COMMENT1 received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse NEW-COMMENT1 event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handleNewComment(json, userId: currentUserId)
            }
        }
        
        commentsChannel?.bind(eventName: "COMMENT-DELETED") { [weak self] event in
            print("📥 [PUSHER EVENT] COMMENT-DELETED received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse COMMENT-DELETED event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handleCommentDeleted(json)
            }
        }
        
        // Comment Likes
        likesChannel?.bind(eventName: "COMMENT_LIKE") { [weak self] event in
            print("📥 [PUSHER EVENT] COMMENT_LIKE received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse COMMENT_LIKE event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handleCommentLike(json, userId: currentUserId)
            }
        }
        
        repliesChannel?.bind(eventName: "COMMENT-UNLIKE") { [weak self] event in
            print("📥 [PUSHER EVENT] COMMENT-UNLIKE received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse COMMENT-UNLIKE event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handleCommentUnlike(json, userId: currentUserId)
            }
        }
        
        // Post Deleted
        postsChannel?.bind(eventName: "POST-DELETED") { [weak self] event in
            print("📥 [PUSHER EVENT] POST-DELETED received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse POST-DELETED event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed JSON: \(json)")
            Task { @MainActor in
                self.handlePostDeleted(json)
            }
        }
        
        print("✅ Pusher event handlers configured successfully")
        print("🎯 Listening on channels: LIKES, posts, reply, REPLIES")
    }

    private func setupUserChatsHandler(userId: String) {
        userChatsChannel?.bind(eventName: "chat-invite") { [weak self] event in
            guard self != nil,
                  let data = event.data,
                  let jsonData = data.data(using: .utf8),
                  let invite = try? JSONDecoder().decode(ChatInviteEvent.self, from: jsonData) else {
                return
            }
            Task { @MainActor in
                InviteStore.shared.add(invite)
            }
        }
        Log.chat.info("Listening on channel: user-\(userId)-chats")
    }

    private func setupUserNotifHandler(userId: String) {
        userNotifChannel?.bind(eventName: "new-notification") { [weak self] event in
            guard let self = self,
                  let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse new-notification event")
                return
            }

            Task { @MainActor in
                self.handleNewNotificationEvent(json, userId: userId)
            }
        }
        print("🎯 Listening on channel: user-\(userId)-notifications")
    }

    private func handleNewNotificationEvent(_ data: [String: Any], userId: String) {
        let username = data["username"] as? String ?? "Someone"
        let actionRaw = data["action"] as? Int ?? 0
        let excerpt = data["excerpt"] as? String ?? ""
        let resourceId = data["resource_id"] as? String ?? ""

        let (title, type): (String, NotificationType) = {
            switch actionRaw {
            case 1: return ("👍 \(username) liked your post", .postLike)
            case 2: return ("❤️ \(username) liked your comment", .commentLike)
            case 3: return ("💬 \(username) commented on your post", .postComment)
            case 4: return ("↩️ \(username) replied to your comment", .commentReply)
            default: return ("🔔 \(username) interacted with your content", .announcement)
            }
        }()

        let body = excerpt.isEmpty ? "Open Exobook to see more" : "\"\(String(excerpt.prefix(60)))\""

        showNotification(title: title, body: body, type: type, resourceId: resourceId)
        newNotificationSubject.send(())
    }
    
    // MARK: - Event Handlers
    
    private func handlePostLike(_ data: Any?, userId: String) {
        print("🔍 Processing POST_LIKE event...")
        
        guard let dict = data as? [String: Any],
              let like = dict["like"] as? [String: Any],
              let count = dict["count"] as? Int,
              let postId = like["post_id"] as? String,
              let likeUserId = like["user_id"] as? String else {
            print("❌ Invalid POST_LIKE data structure!")
            print("📦 Expected: {like: {post_id, user_id, ...}, count: Int}")
            print("📦 Received: \(String(describing: data))")
            return
        }
        
        let username = like["username"] as? String ?? "Unknown"
        print("❤️ POST_LIKE PARSED SUCCESSFULLY:")
        print("   📌 Post ID: \(postId)")
        print("   👤 Liked by: \(username) (\(likeUserId))")
        print("   📊 New count: \(count)")
        print("   🔄 Is current user: \(likeUserId == userId ? "YES" : "NO")")

        // Update in-memory count
        likeCount[postId] = count

        // Track if current user liked it
        if likeUserId == userId {
            likedPostIds.insert(postId)
        }

        // Persist to cache
        cacheManager.cachePostStats(
            postId: postId,
            likeCount: count,
            commentCount: commentCount[postId] ?? 0,
            isLiked: likeUserId == userId ? true : (likedPostIds.contains(postId))
        )
        
        // Notification: Someone liked MY post
        if let owner = like["owner"] as? String,
           owner == userId && likeUserId != userId,
           let username = like["username"] as? String {
            showNotification(
                title: "👍 \(username) liked your post!",
                body: "Your content is getting engagement!",
                type: .postLike,
                resourceId: postId
            )
        }
    }
    
    private func handlePostUnlike(_ data: Any?, userId: String) {
        print("🔍 Processing POST_UNLIKE event...")
        
        guard let dict = data as? [String: Any] else {
            print("❌ Invalid POST_UNLIKE data - not a dictionary")
            return
        }

        let postId = (dict["like"] as? [String: Any])?["post_id"] as? String ?? dict["PostID"] as? String
        let unlikeUserId = (dict["like"] as? [String: Any])?["user_id"] as? String ?? dict["UserID"] as? String

        guard let postId = postId, let unlikeUserId = unlikeUserId else {
            print("❌ Missing post_id or user_id in POST_UNLIKE")
            print("📦 Received: \(String(describing: data))")
            return
        }

        print("💔 POST_UNLIKE PARSED SUCCESSFULLY:")
        print("   📌 Post ID: \(postId)")
        print("   👤 Unliked by: \(unlikeUserId)")
        print("   🔄 Is current user: \(unlikeUserId == userId ? "YES" : "NO")")

        // Decrement count
        let newCount = max((likeCount[postId] ?? 1) - 1, 0)
        likeCount[postId] = newCount

        // Remove from liked set if current user
        let isLiked = unlikeUserId == userId ? false : likedPostIds.contains(postId)
        if unlikeUserId == userId {
            likedPostIds.remove(postId)
        }

        // Persist to cache
        cacheManager.cachePostStats(
            postId: postId,
            likeCount: newCount,
            commentCount: commentCount[postId] ?? 0,
            isLiked: isLiked
        )
    }
    
    private func handleNewComment(_ data: Any?, userId: String) {
        print("🔍 Processing NEW-COMMENT1 event...")
        
        guard let dict = data as? [String: Any],
              let postId = dict["post_id"] as? String,
              let commentUserId = dict["user_id"] as? String else {
            print("❌ Invalid NEW-COMMENT1 data")
            print("📦 Received: \(String(describing: data))")
            return
        }

        let username = dict["user_name"] as? String ?? "Unknown"
        let content = dict["content"] as? String ?? ""
        print("💬 NEW-COMMENT PARSED SUCCESSFULLY:")
        print("   📌 Post ID: \(postId)")
        print("   👤 Comment by: \(username) (\(commentUserId))")
        print("   📝 Content: \(String(content.prefix(50)))")
        print("   🔄 Is current user: \(commentUserId == userId ? "YES" : "NO")")

        // Increment comment count
        let newCount = (commentCount[postId] ?? 0) + 1
        commentCount[postId] = newCount

        // Persist to cache
        cacheManager.cachePostStats(
            postId: postId,
            likeCount: likeCount[postId] ?? 0,
            commentCount: newCount,
            isLiked: likedPostIds.contains(postId)
        )

        // Notification: Someone commented on MY post
        if let owner = dict["owner"] as? String,
           owner == userId && commentUserId != userId,
           let username = dict["user_name"] as? String {
            let content = dict["content"] as? String ?? ""
            let excerpt = String(content.prefix(50))
            showNotification(
                title: "💬 \(username) commented on your post",
                body: excerpt.isEmpty ? "Check out their comment" : "\"\(excerpt)...\"",
                type: .postComment,
                resourceId: postId
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
        let newCount = max((commentCount[postId] ?? 1) - 1, 0)
        commentCount[postId] = newCount

        // Persist to cache
        cacheManager.cachePostStats(
            postId: postId,
            likeCount: likeCount[postId] ?? 0,
            commentCount: newCount,
            isLiked: likedPostIds.contains(postId)
        )
    }
    
    private func handleCommentLike(_ data: Any?, userId: String) {
        print("🔍 Processing COMMENT_LIKE event...")
        
        guard let dict = data as? [String: Any],
              let commentId = dict["post_id"] as? String, // Note: post_id is actually commentId for comment likes
              let likeUserId = dict["user_id"] as? String else {
            print("❌ Invalid COMMENT_LIKE data")
            print("📦 Received: \(String(describing: data))")
            return
        }
        
        let username = dict["username"] as? String ?? "Unknown"
        print("❤️ COMMENT_LIKE PARSED SUCCESSFULLY:")
        print("   📌 Comment ID: \(commentId)")
        print("   👤 Liked by: \(username) (\(likeUserId))")
        print("   🔄 Is current user: \(likeUserId == userId ? "YES" : "NO")")
        
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
            // Use post_id if available, otherwise use commentId
            let resourceId = dict["post_id"] as? String ?? commentId
            showNotification(
                title: "❤️ \(username) liked your comment!",
                body: "Your comment resonated with someone!",
                type: .commentLike,
                resourceId: resourceId
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
    
    // MARK: - Cache Management

    /// Load cached stats from SwiftData into memory on app start
    private func loadCachedStats() {
        let cachedPosts = cacheManager.getAllPostStats()

        for cached in cachedPosts {
            likeCount[cached.postId] = cached.likeCount
            commentCount[cached.postId] = cached.commentCount

            if cached.isLikedByCurrentUser {
                likedPostIds.insert(cached.postId)
            }
        }

        print("💾 Loaded \(cachedPosts.count) cached post stats from SwiftData")
    }

    // MARK: - Public Helpers

    func getLikeCount(for postId: String) -> Int {
        // Check cache first if not in memory
        if let count = likeCount[postId] {
            return count
        }

        // Fallback to cache
        if let cached = cacheManager.getPostStats(postId: postId) {
            likeCount[postId] = cached.likeCount
            return cached.likeCount
        }

        return 0
    }

    func getCommentCount(for postId: String) -> Int {
        // Check cache first if not in memory
        if let count = commentCount[postId] {
            return count
        }

        // Fallback to cache
        if let cached = cacheManager.getPostStats(postId: postId) {
            commentCount[postId] = cached.commentCount
            return cached.commentCount
        }

        return 0
    }

    func isLiked(_ postId: String) -> Bool {
        // Check memory first
        if likedPostIds.contains(postId) {
            return true
        }

        // Fallback to cache
        if let cached = cacheManager.getPostStats(postId: postId) {
            if cached.isLikedByCurrentUser {
                likedPostIds.insert(postId)
            }
            return cached.isLikedByCurrentUser
        }

        return false
    }

    func isCommentLiked(_ commentId: String) -> Bool {
        likedCommentIds.contains(commentId)
    }
    
    // Initialize counts from existing data
    func initializeCounts(posts: [Post]) {
        for post in posts {
            // Only update if Post has actual count data (not 0 or if we don't have cached data)
            // This prevents overwriting cached counts with zeros from incomplete API responses
            let cachedStats = cacheManager.getPostStats(postId: post.id)

            // Use Post counts if they're non-zero, otherwise keep cached values
            let finalLikeCount = post.likeCount > 0 ? post.likeCount : (cachedStats?.likeCount ?? 0)
            let finalCommentCount = post.commentCount > 0 ? post.commentCount : (cachedStats?.commentCount ?? 0)

            likeCount[post.id] = finalLikeCount
            commentCount[post.id] = finalCommentCount

            // Check if current user liked this post
            var isLiked = cachedStats?.isLikedByCurrentUser ?? false
            if let likes = post.likes, let userId = currentUserId, likes.contains(userId) {
                likedPostIds.insert(post.id)
                isLiked = true
            }

            // Only persist if we have new non-zero data or no cache exists
            if finalLikeCount > 0 || finalCommentCount > 0 || cachedStats == nil {
                cacheManager.cachePostStats(
                    postId: post.id,
                    likeCount: finalLikeCount,
                    commentCount: finalCommentCount,
                    isLiked: isLiked
                )
            }
        }
        print("📊 Initialized counts for \(posts.count) posts (preserving cache when API data is zero)")
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

        // Batch persist to cache - more efficient
        cacheManager.batchCachePostStats(
            likeCounts: likeCounts,
            commentCounts: commentCounts,
            likedPostIds: likedPostIds
        )

        print("📊 Batch initialized and cached counts: \(likeCounts.count) likes, \(commentCounts.count) comments")
    }
    
    // MARK: - Notifications

    private func showNotification(
        title: String,
        body: String,
        type: NotificationType,
        resourceId: String
    ) {
        print("🔔 \(title): \(body)")

        // 1. Persist to local cache (SwiftData)
        // Extract userId if available (assuming resourceId might help or context)
        // Ideally we pass action user info here too, but for now we use what we have
        
        // Note: We need to extract the action user info from the event data to fully populate the cache
        // but `showNotification` is generic.
        // For now, we cache with available info.
        
        Task { @MainActor in
            _ = self.currentUserId
            
            cacheManager.cacheNotification(
                type: type.rawValue,
                title: title,
                message: body,
                resourceId: resourceId,
                userId: self.currentUserId
            )
        }

        // 2. Show system notification
        Task {
            await NotificationManager.shared.showNotification(
                title: title,
                body: body,
                type: type,
                resourceId: resourceId,
                badge: true
            )
        }
    }
    
    // MARK: - Cleanup
    
    func disconnect() {
        postsChannel?.unbindAll()
        commentsChannel?.unbindAll()
        likesChannel?.unbindAll()
        repliesChannel?.unbindAll()
        userNotifChannel?.unbindAll()

        pusher?.unsubscribe("posts")
        pusher?.unsubscribe("reply")
        pusher?.unsubscribe("LIKES")
        pusher?.unsubscribe("REPLIES")
        if let userId = currentUserId {
            pusher?.unsubscribe("user-\(userId)-notifications")
        }

        for (chatId, channel) in chatChannels {
            channel.unbindAll()
            pusher?.unsubscribe("chat-\(chatId)")
        }
        chatChannels.removeAll()
        chatMessageSubjects.removeAll()

        pusher?.disconnect()

        print("🔴 Pusher disconnected")
    }
}

// MARK: - PusherDelegate

extension RealtimeManager: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("⏰ [\(timestamp)] 🔄 Pusher Connection: \(old.stringValue()) → \(new.stringValue())")
        
        if new.stringValue() == "connected" {
            print("🎉 PUSHER CONNECTED! Ready to receive events")
        } else if new.stringValue() == "disconnected" {
            print("⚠️ PUSHER DISCONNECTED - Events will not be received")
        }
    }
    
    func debugLog(message: String) {
        // Only log important debug messages to reduce noise
        if message.contains("websocketDidReceiveMessage") && !message.contains("pusher:ping") {
            let timestamp = Date().formatted(date: .omitted, time: .standard)
            print("⏰ [\(timestamp)] 🔍 Pusher Debug: \(message)")
        }
    }
    
    func subscribedToChannel(name: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("⏰ [\(timestamp)] ✅ Subscribed to channel: \(name)")
    }
    
    func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("⏰ [\(timestamp)] ❌ FAILED to subscribe to: \(name)")
        print("   Error: \(error?.localizedDescription ?? "unknown")")
        if let data = data {
            print("   Response data: \(data)")
        }
    }
}
