//
//  LikesAPIService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
class LikesAPIService {
    private let network = NetworkService.shared
    private let baseURL = APIConfig.likesAPI
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> LikesHealthResponse {
        try await network.get("\(baseURL)/")
    }
    
    // MARK: - Like Operations
    
    /// Like a post
    func likePost(postId: String, userId: String) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/likes/new", body: LikeRequest(
            postId: postId,
            userId: userId
        ))
    }
    
    /// Unlike a post
    func unlikePost(postId: String, userId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/likes/\(postId)/\(userId)")
    }
    
    /// Get post like count
    func getPostLikeCount(postId: String) async throws -> LikeCountResponse {
        try await network.get("\(baseURL)/api/likes/count/\(postId)")
    }
    
    /// Get all posts liked by a user
    func getUserLikedPosts(userId: String) async throws -> UserLikesResponse {
        try await network.get("\(baseURL)/api/likes/mine/\(userId)")
    }
    
    // MARK: - Comment/Reply Likes
    
    /// Like a comment
    func likeComment(commentId: String, userId: String) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/likes/new/comment", body: LikeRequest(
            postId: commentId,  // Using postId field for commentId
            userId: userId
        ))
    }
    
    /// Unlike a comment
    func unlikeComment(commentId: String, userId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/likes/c/\(commentId)/\(userId)")
    }
    
}

// MARK: - Request Models

struct LikeRequest: Encodable {
    let postId: String
    let userId: String
}

struct BatchRequest: Encodable {
    let ids: [String]
}

struct BatchStatusRequest: Encodable {
    let ids: [String]
    let userId: String
}

// MARK: - Response Models

struct LikesHealthResponse: Codable {
    let success: String
}

struct LikeCountResponse: Codable {
    let postId: String
    let count: Int
}

struct LikeStatusResponse: Codable {
    let postId: String
    let userId: String
    let liked: Bool
}

struct LikersResponse: Codable {
    let postId: String
    let users: [String]
}

struct UserLikesResponse: Codable {
    let userId: String
    let posts: [String]
}

struct BatchLikeCountsResponse: Codable {
    let counts: [String: Int] // postId: count
}

struct BatchLikeStatusResponse: Codable {
    let statuses: [String: Bool] // postId: liked
}
