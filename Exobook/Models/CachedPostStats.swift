//
//  CachedPostStats.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/12/2025.
//

import Foundation
import SwiftData

/// SwiftData model for caching post statistics (likes, comments) locally
@Model
final class CachedPostStats {
    @Attribute(.unique) var postId: String
    var likeCount: Int
    var commentCount: Int
    var isLikedByCurrentUser: Bool
    var lastUpdated: Date

    init(postId: String, likeCount: Int, commentCount: Int, isLikedByCurrentUser: Bool) {
        self.postId = postId
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.lastUpdated = Date()
    }

    /// Update stats and refresh timestamp
    func update(likeCount: Int? = nil, commentCount: Int? = nil, isLiked: Bool? = nil) {
        if let likeCount = likeCount {
            self.likeCount = likeCount
        }
        if let commentCount = commentCount {
            self.commentCount = commentCount
        }
        if let isLiked = isLiked {
            self.isLikedByCurrentUser = isLiked
        }
        self.lastUpdated = Date()
    }
}

/// SwiftData model for caching reply/comment statistics
@Model
final class CachedReplyStats {
    @Attribute(.unique) var replyId: String
    var likeCount: Int
    var nestedReplyCount: Int
    var isLikedByCurrentUser: Bool
    var lastUpdated: Date

    init(replyId: String, likeCount: Int, nestedReplyCount: Int, isLikedByCurrentUser: Bool) {
        self.replyId = replyId
        self.likeCount = likeCount
        self.nestedReplyCount = nestedReplyCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.lastUpdated = Date()
    }

    /// Update stats and refresh timestamp
    func update(likeCount: Int? = nil, nestedReplyCount: Int? = nil, isLiked: Bool? = nil) {
        if let likeCount = likeCount {
            self.likeCount = likeCount
        }
        if let nestedReplyCount = nestedReplyCount {
            self.nestedReplyCount = nestedReplyCount
        }
        if let isLiked = isLiked {
            self.isLikedByCurrentUser = isLiked
        }
        self.lastUpdated = Date()
    }
}
