//
//  NotificationsAPIService.swift
//  Exobook
//

import Foundation

@MainActor
final class NotificationsAPIService {
    private let network = NetworkService.shared
    private let baseURL = APIConfig.notificationsAPI

    // MARK: - Reads

    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [ServerNotification] {
        let envelope: APIEnvelope<MyNotifsResponse> = try await network.get(
            "\(baseURL)/api/notifs/mine/\(userId)?limit=\(limit)"
        )
        return envelope.data.notifications
    }

    func fetchUnreadCount(userId: String) async throws -> Int {
        let envelope: APIEnvelope<UnreadCountResponse> = try await network.get(
            "\(baseURL)/api/notifs/unread-count/\(userId)"
        )
        return envelope.data.unreadCount
    }

    // MARK: - Writes

    func markAsRead(notificationId: String, userId: String) async throws {
        let request = MarkReadByIdRequest(notificationIds: [notificationId])
        let _: StatusEnvelope = try await network.patch(
            "\(baseURL)/api/notifs/read-by-id/\(userId)",
            body: request
        )
    }

    func batchMarkAsRead(userId: String, notificationIds: [String]) async throws {
        guard !notificationIds.isEmpty else { return }
        let request = MarkReadByIdRequest(notificationIds: notificationIds)
        let _: StatusEnvelope = try await network.patch(
            "\(baseURL)/api/notifs/read-by-id/\(userId)",
            body: request
        )
    }

    func deleteNotification(owner: String, actionKey: String) async throws {
        let encodedKey = actionKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? actionKey
        let _: StatusEnvelope = try await network.delete(
            "\(baseURL)/api/notifs/\(owner)/\(encodedKey)"
        )
    }
}

// MARK: - Models

struct ServerNotification: Decodable {
    let id: String
    let owner: String
    let username: String
    let excerpt: String
    let userId: String
    let userBio: String
    let userPic: String
    /// 1=like post, 2=like comment, 3=reply post, 4=reply comment
    let action: Int
    let resourceType: String
    let resourceId: String
    let createdAt: Date
    let readStatus: Bool
    let actionKey: String

    enum CodingKeys: String, CodingKey {
        case id
        case owner
        case username
        case excerpt
        case userId = "userid"
        case userBio = "userbio"
        case userPic = "userpic"
        case action
        case resourceType = "resource_type"
        case resourceId = "resource_id"
        case createdAt = "created_at"
        case readStatus = "read_status"
        case actionKey = "action_key"
    }

    var notificationType: NotificationType {
        switch action {
        case 1: return .postLike
        case 2: return .commentLike
        case 3: return .postComment
        case 4: return .commentReply
        default: return .announcement
        }
    }

    var displayTitle: String {
        switch action {
        case 1: return "\(username) liked your post"
        case 2: return "\(username) liked your comment"
        case 3: return "\(username) commented on your post"
        case 4: return "\(username) replied to your comment"
        default: return username.isEmpty ? "Notification" : username
        }
    }
}

private struct MyNotifsResponse: Decodable {
    let notifications: [ServerNotification]
    let hasMore: Bool?
    let nextKey: String?

    enum CodingKeys: String, CodingKey {
        case notifications
        case hasMore = "has_more"
        case nextKey = "next_key"
    }
}

private struct UnreadCountResponse: Decodable {
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

private struct MarkReadByIdRequest: Encodable {
    let notificationIds: [String]

    enum CodingKeys: String, CodingKey {
        case notificationIds = "notification_ids"
    }
}
