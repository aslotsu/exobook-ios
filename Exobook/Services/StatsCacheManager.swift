//
//  StatsCacheManager.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/12/2025.
//

import Foundation
import SwiftData

/// Manages local caching of post and reply statistics using SwiftData
@MainActor
final class StatsCacheManager {
    static let shared = StatsCacheManager()

    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private init() {
        // Configure SwiftData model container
        let schema = Schema([
            CachedPostStats.self,
            CachedReplyStats.self,
            CachedNotification.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
            print("✅ SwiftData StatsCacheManager initialized")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Post Stats

    /// Get cached post stats
    func getPostStats(postId: String) -> CachedPostStats? {
        let predicate = #Predicate<CachedPostStats> { $0.postId == postId }
        let descriptor = FetchDescriptor<CachedPostStats>(predicate: predicate)

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("❌ Failed to fetch post stats: \(error)")
            return nil
        }
    }

    /// Cache post stats
    func cachePostStats(
        postId: String,
        likeCount: Int,
        commentCount: Int,
        isLiked: Bool
    ) {
        if let existing = getPostStats(postId: postId) {
            // Update existing
            existing.update(likeCount: likeCount, commentCount: commentCount, isLiked: isLiked)
        } else {
            // Create new
            let stats = CachedPostStats(
                postId: postId,
                likeCount: likeCount,
                commentCount: commentCount,
                isLikedByCurrentUser: isLiked
            )
            modelContext.insert(stats)
        }

        saveContext()
    }

    /// Batch cache post stats (efficient for feed loading)
    func batchCachePostStats(
        likeCounts: [String: Int],
        commentCounts: [String: Int],
        likedPostIds: Set<String>
    ) {
        // Combine all post IDs
        let allPostIds = Set(likeCounts.keys).union(commentCounts.keys)

        for postId in allPostIds {
            let likeCount = likeCounts[postId] ?? 0
            let commentCount = commentCounts[postId] ?? 0
            let isLiked = likedPostIds.contains(postId)

            cachePostStats(
                postId: postId,
                likeCount: likeCount,
                commentCount: commentCount,
                isLiked: isLiked
            )
        }

        print("💾 Batch cached stats for \(allPostIds.count) posts")
    }

    /// Update like count for a post (optimistic update)
    func updatePostLikeCount(postId: String, increment: Bool, isLiked: Bool) {
        if let stats = getPostStats(postId: postId) {
            let newCount = increment ? stats.likeCount + 1 : max(0, stats.likeCount - 1)
            stats.update(likeCount: newCount, isLiked: isLiked)
            saveContext()
        } else {
            // Create with initial count
            cachePostStats(
                postId: postId,
                likeCount: increment ? 1 : 0,
                commentCount: 0,
                isLiked: isLiked
            )
        }
    }

    /// Update just the like status for a post
    func updatePostLikeStatus(postId: String, isLiked: Bool) {
        if let stats = getPostStats(postId: postId) {
            stats.update(isLiked: isLiked)
            saveContext()
        }
        // If not in cache, we don't create it just for like status 
        // because we need counts. Or should we?
        // If we create it with 0 counts, it might overwrite real counts later?
        // But if it's not in cache, we don't display it anyway?
        // Safest is to only update if exists.
    }

    /// Update comment count for a post
    func updatePostCommentCount(postId: String, increment: Bool) {
        if let stats = getPostStats(postId: postId) {
            let newCount = increment ? stats.commentCount + 1 : max(0, stats.commentCount - 1)
            stats.update(commentCount: newCount)
            saveContext()
        } else {
            cachePostStats(
                postId: postId,
                likeCount: 0,
                commentCount: increment ? 1 : 0,
                isLiked: false
            )
        }
    }

    /// Get all cached post stats (for feed initialization)
    func getAllPostStats() -> [CachedPostStats] {
        let descriptor = FetchDescriptor<CachedPostStats>()

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch all post stats: \(error)")
            return []
        }
    }

    // MARK: - Reply Stats

    /// Get cached reply stats
    func getReplyStats(replyId: String) -> CachedReplyStats? {
        let predicate = #Predicate<CachedReplyStats> { $0.replyId == replyId }
        let descriptor = FetchDescriptor<CachedReplyStats>(predicate: predicate)

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("❌ Failed to fetch reply stats: \(error)")
            return nil
        }
    }

    /// Cache reply stats
    func cacheReplyStats(
        replyId: String,
        likeCount: Int,
        nestedReplyCount: Int,
        isLiked: Bool
    ) {
        if let existing = getReplyStats(replyId: replyId) {
            existing.update(likeCount: likeCount, nestedReplyCount: nestedReplyCount, isLiked: isLiked)
        } else {
            let stats = CachedReplyStats(
                replyId: replyId,
                likeCount: likeCount,
                nestedReplyCount: nestedReplyCount,
                isLikedByCurrentUser: isLiked
            )
            modelContext.insert(stats)
        }

        saveContext()
    }

    /// Update reply like count (optimistic update)
    func updateReplyLikeCount(replyId: String, increment: Bool, isLiked: Bool) {
        if let stats = getReplyStats(replyId: replyId) {
            let newCount = increment ? stats.likeCount + 1 : max(0, stats.likeCount - 1)
            stats.update(likeCount: newCount, isLiked: isLiked)
            saveContext()
        } else {
            cacheReplyStats(
                replyId: replyId,
                likeCount: increment ? 1 : 0,
                nestedReplyCount: 0,
                isLiked: isLiked
            )
        }
    }

    // MARK: - Cache Management

    /// Clear all cached stats (useful for logout or cache reset)
    func clearAllStats() {
        do {
            try modelContext.delete(model: CachedPostStats.self)
            try modelContext.delete(model: CachedReplyStats.self)
            saveContext()
            print("🗑️ Cleared all cached stats")
        } catch {
            print("❌ Failed to clear stats: \(error)")
        }
    }

    /// Clear old cached stats (older than specified days)
    func clearOldStats(olderThanDays days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let postPredicate = #Predicate<CachedPostStats> { $0.lastUpdated < cutoffDate }
        let postDescriptor = FetchDescriptor<CachedPostStats>(predicate: postPredicate)

        let replyPredicate = #Predicate<CachedReplyStats> { $0.lastUpdated < cutoffDate }
        let replyDescriptor = FetchDescriptor<CachedReplyStats>(predicate: replyPredicate)
        
        let notifPredicate = #Predicate<CachedNotification> { $0.timestamp < cutoffDate }
        let notifDescriptor = FetchDescriptor<CachedNotification>(predicate: notifPredicate)

        do {
            let oldPosts = try modelContext.fetch(postDescriptor)
            let oldReplies = try modelContext.fetch(replyDescriptor)
            let oldNotifs = try modelContext.fetch(notifDescriptor)

            for post in oldPosts {
                modelContext.delete(post)
            }
            for reply in oldReplies {
                modelContext.delete(reply)
            }
            for notif in oldNotifs {
                modelContext.delete(notif)
            }

            saveContext()
            print("🗑️ Cleared \(oldPosts.count) old post stats, \(oldReplies.count) old reply stats, and \(oldNotifs.count) old notifications")
        } catch {
            print("❌ Failed to clear old stats: \(error)")
        }
    }
    
    // MARK: - Notifications

    func cacheNotification(
        type: String,
        title: String,
        message: String,
        resourceId: String,
        userId: String?
    ) {
        let notification = CachedNotification(
            type: type,
            title: title,
            message: message,
            resourceId: resourceId,
            userId: userId
        )
        
        modelContext.insert(notification)
        saveContext()
        print("💾 Cached notification: \(title)")
    }

    /// Merge a server-fetched notification list into the local cache.
    /// - Server is the source of truth for "exists" and the latest content.
    /// - Local is the source of truth for `isRead` / `isOpened` once they are true:
    ///   we only flip them on; we never flip them off based on server state.
    func mergeServerNotifications(_ notifs: [ServerNotification], userId: String) {
        let descriptor = FetchDescriptor<CachedNotification>(
            predicate: #Predicate { $0.userId == userId }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for notif in notifs {
            if let local = existingById[notif.id] {
                local.title = notif.displayTitle
                local.message = notif.excerpt
                local.timestamp = notif.createdAt
                local.resourceId = notif.resourceId
                local.actionUserId = notif.userId
                local.actionUserName = notif.username
                local.actionUserPicture = notif.userPic
                local.actionKey = notif.actionKey
                if notif.readStatus { local.isRead = true }
            } else {
                let cached = CachedNotification(
                    id: notif.id,
                    type: notif.notificationType.rawValue,
                    title: notif.displayTitle,
                    message: notif.excerpt,
                    timestamp: notif.createdAt,
                    resourceId: notif.resourceId,
                    userId: userId,
                    isRead: notif.readStatus,
                    isOpened: false,
                    actionUserId: notif.userId,
                    actionUserName: notif.username,
                    actionUserPicture: notif.userPic,
                    actionKey: notif.actionKey
                )
                modelContext.insert(cached)
            }
        }
        saveContext()
    }

    // MARK: - Notification Status Management

    func markAllNotificationsAsRead(forUserId userId: String? = nil) {
        let descriptor: FetchDescriptor<CachedNotification>
        
        if let userId = userId {
            let predicate = #Predicate<CachedNotification> { $0.userId == userId }
            descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)
        } else {
            descriptor = FetchDescriptor<CachedNotification>()
        }

        do {
            let notifications = try modelContext.fetch(descriptor)
            for notification in notifications {
                if !notification.isRead {
                    notification.isRead = true
                }
            }
            saveContext()
            print("✅ Marked all notifications as read (userId: \(userId ?? "all"))")
        } catch {
            print("❌ Failed to mark all notifications as read: \(error)")
        }
    }

    func markNotificationAsRead(id: String) {
        let predicate = #Predicate<CachedNotification> { $0.id == id }
        let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)
        
        do {
            if let notification = try modelContext.fetch(descriptor).first {
                notification.isRead = true
                saveContext()
                print("✅ Marked notification as read: \(id)")
            }
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }

    func deleteNotification(id: String) {
        let predicate = #Predicate<CachedNotification> { $0.id == id }
        let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

        do {
            if let notification = try modelContext.fetch(descriptor).first {
                modelContext.delete(notification)
                saveContext()
                print("🗑️ Deleted notification: \(id)")
            }
        } catch {
            print("❌ Failed to delete notification: \(error)")
        }
    }

    func markNotificationAsOpened(id: String) {
        let predicate = #Predicate<CachedNotification> { $0.id == id }
        let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)
        
        do {
            if let notification = try modelContext.fetch(descriptor).first {
                notification.isOpened = true
                notification.isRead = true // Opening implies reading
                saveContext()
                print("✅ Marked notification as opened: \(id)")
            }
        } catch {
            print("❌ Failed to mark notification as opened: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save context: \(error)")
        }
    }
}
