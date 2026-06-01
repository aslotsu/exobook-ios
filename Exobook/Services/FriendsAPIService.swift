//
//  FriendsAPIService.swift
//  Exobook
//
//  Created by GPT-5.3-Codex on 10/05/2026.
//

import Foundation

@MainActor
class FriendsAPIService {
    private let network = NetworkService.shared
    private let baseURL = APIConfig.friendsAPI

    // MARK: - Relationship

    func getRelationship(myId: String, theirId: String) async throws -> RelationshipState {
        let envelope: APIEnvelope<RelationshipResponse> = try await network.get(
            "\(baseURL)/friends/\(myId)/relationship/\(theirId)"
        )
        return envelope.data.relationship
    }

    // MARK: - Friends

    func getFriends(userId: String, cursor: String? = nil, limit: Int = 20) async throws -> FriendsListResponse {
        var endpoint = "\(baseURL)/friends/\(userId)?limit=\(limit)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(cursor)"
        }
        let envelope: APIEnvelope<FriendsListResponse> = try await network.get(endpoint)
        return envelope.data
    }

    func removeFriend(userId: String, friendId: String) async throws {
        let _: StatusEnvelope = try await network.delete("\(baseURL)/friends/\(userId)/\(friendId)")
    }

    // MARK: - Friend Requests

    func sendFriendRequest(fromId: String, toId: String) async throws {
        let _: StatusEnvelope = try await network.post(
            "\(baseURL)/friends/requests/send",
            body: FriendRequestActionBody(fromId: fromId, toId: toId)
        )
    }

    func respondToRequest(fromId: String, toId: String, status: FriendRequestDecision) async throws {
        let _: StatusEnvelope = try await network.post(
            "\(baseURL)/friends/requests/respond",
            body: RespondToRequestBody(fromId: fromId, toId: toId, status: status)
        )
    }

    func cancelFriendRequest(fromId: String, toId: String) async throws {
        let _: StatusEnvelope = try await network.delete(
            "\(baseURL)/friends/requests/cancel",
            body: FriendRequestActionBody(fromId: fromId, toId: toId)
        )
    }

    func getPendingRequests(userId: String, page: Int = 1, limit: Int = 20) async throws -> PendingRequestsResponse {
        let envelope: APIEnvelope<PendingRequestsResponse> = try await network.get(
            "\(baseURL)/friends/requests/pending/\(userId)?page=\(page)&limit=\(limit)"
        )
        return envelope.data
    }

    func getSuggestions(userId: String, limit: Int = 20) async throws -> [FriendSuggestion] {
        let envelope: APIEnvelope<SuggestionsResponse> = try await network.get(
            "\(baseURL)/friends/\(userId)/suggestions?limit=\(limit)"
        )
        return envelope.data.suggestions
    }

    func getMutualFriends(userId: String, otherId: String) async throws -> MutualFriendsResponse {
        let envelope: APIEnvelope<MutualFriendsResponse> = try await network.get(
            "\(baseURL)/friends/\(userId)/mutual/\(otherId)"
        )
        return envelope.data
    }
}

// MARK: - Models

enum RelationshipState: String, Decodable {
    case friends
    case requestSent = "request_sent"
    case requestReceived = "request_received"
    case none
}

enum FriendRequestDecision: String, Encodable {
    case accepted
    case declined
}

struct Friend: Decodable, Identifiable {
    let id: String
    let addedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case addedAt = "added_at"
    }
}

struct FriendRequest: Decodable, Identifiable {
    var id: String { "\(fromId)-\(toId)" }
    let fromId: String
    let toId: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case toId = "to_id"
        case status
        case createdAt = "created_at"
    }
}

struct FriendsListResponse: Decodable {
    let friends: [Friend]
    let count: Int
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case friends
        case count
        case nextCursor = "next_cursor"
    }
}

struct PendingRequestsResponse: Decodable {
    let requests: [FriendRequest]
    let count: Int
    let hasMore: Bool?
    let page: Int?

    enum CodingKeys: String, CodingKey {
        case requests
        case count
        case hasMore = "has_more"
        case page
    }
}

private struct RelationshipResponse: Decodable {
    let relationship: RelationshipState
}

private struct FriendRequestActionBody: Encodable {
    let fromId: String
    let toId: String

    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case toId = "to_id"
    }
}

struct FriendSuggestion: Decodable, Identifiable {
    var id: String { userId }
    let userId: String
    let mutualCount: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case mutualCount = "mutual_count"
        case reason
    }
}

struct MutualFriendsResponse: Decodable {
    let mutualFriends: [Friend]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case mutualFriends = "mutual_friends"
        case count
    }
}

private struct SuggestionsResponse: Decodable {
    let suggestions: [FriendSuggestion]
    let count: Int
}

private struct RespondToRequestBody: Encodable {
    let fromId: String
    let toId: String
    let status: FriendRequestDecision

    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case toId = "to_id"
        case status
    }
}
