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
    private let mainAPI = APIConfig.baseAPI

    // MARK: - Health Check

    func healthCheck() async throws -> LikesHealthResponse {
        try await network.get("\(baseURL)/")
    }

    // MARK: - Like Operations

    /// Like a post. Mirrors web likeManager: writes to DynamoDB and bumps the Redis counter in parallel.
    func likePost(postId: String, userId: String) async throws -> EmptyResponse {
        async let dynamo: EmptyResponse = network.post("\(baseURL)/api/likes/new", body: LikeRequest(
            postId: postId,
            userId: userId
        ))
        async let redis: EmptyResponse = network.post("\(mainAPI)/api/redis/likes/\(postId)/\(userId)", body: EmptyLikeBody())
        let (result, _) = try await (dynamo, redis)
        return result
    }

    /// Unlike a post. Mirrors web likeManager: removes from DynamoDB and decrements the Redis counter in parallel.
    func unlikePost(postId: String, userId: String) async throws -> EmptyResponse {
        async let dynamo: EmptyResponse = network.delete("\(baseURL)/api/likes/\(postId)/\(userId)")
        async let redis: EmptyResponse = network.post("\(mainAPI)/api/redis/likes/d/\(postId)/\(userId)", body: EmptyLikeBody())
        let (result, _) = try await (dynamo, redis)
        return result
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

private struct EmptyLikeBody: Encodable {}

struct LikeRequest: Encodable {
    let postId: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
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

struct UserLikesResponse: Decodable {
    let likes: [LikeItem]
    
    var posts: [String] {
        likes.map { $0.postId }
    }
    
    // Custom decoding to handle potential API response variations
    init(from decoder: Decoder) throws {
        // 1. Try to decode as a keyed container (standard object)
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            // Check for "likes" key
            if let likes = try? container.decode([LikeItem].self, forKey: .likes) {
                self.likes = likes
                return
            }
            // Check for "data" key (common API pattern)
            if let data = try? container.decode([LikeItem].self, forKey: .data) {
                self.likes = data
                return
            }
        }
        
        // 2. Try to decode as a direct array (root level array)
        // Note: decode([LikeItem].self) on singleValueContainer handles root array
        if let singleValue = try? decoder.singleValueContainer(),
           let likesArray = try? singleValue.decode([LikeItem].self) {
            self.likes = likesArray
            return
        }
        
        // 3. Fallback: Return empty list instead of crashing, but log it
        print("⚠️ UserLikesResponse: Failed to find 'likes', 'data' or root array. Defaulting to empty.")
        self.likes = []
    }
    
    // Add data key to CodingKeys to support the keyed decoding above
    enum CodingKeys: String, CodingKey {
        case likes
        case data
    }
}

struct LikeItem: Codable {
    let id: String
    let postId: String
    let userId: String
    let up: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case up
    }
}

struct BatchLikeCountsResponse: Codable {
    let counts: [String: Int] // postId: count
}

struct BatchLikeStatusResponse: Codable {
    let statuses: [String: Bool] // postId: liked
}
