//
//  ChatInviteAPIService.swift
//

import Foundation

// MARK: - Service

@MainActor
final class ChatInviteAPIService {
    private let network = NetworkService.shared
    private let base = APIConfig.chatAPI

    // MARK: Invites

    func sendInvite(
        chatId: String,
        senderId: String,
        recipientId: String,
        inviterName: String,
        chatName: String?
    ) async throws {
        struct Body: Encodable {
            let senderId: String
            let recipientId: String
            let inviterName: String
            let chatName: String?
            let expiresHours: Int

            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id"
                case recipientId = "recipient_id"
                case inviterName = "inviter_name"
                case chatName = "chat_name"
                case expiresHours = "expires_hours"
            }
        }
        struct Resp: Decodable { let success: Bool }
        let _: Resp = try await network.post(
            "\(base)/chats/\(chatId)/invites",
            body: Body(senderId: senderId, recipientId: recipientId,
                       inviterName: inviterName, chatName: chatName, expiresHours: 168)
        )
    }

    func acceptInvite(chatId: String, user: ChatMember) async throws {
        let _: StatusResp = try await network.post(
            "\(base)/chats/\(chatId)/invites/accept",
            body: MemberActionBody(member: user)
        )
    }

    func rejectInvite(chatId: String, user: ChatMember) async throws {
        let _: StatusResp = try await network.post(
            "\(base)/chats/\(chatId)/invites/reject",
            body: MemberActionBody(member: user)
        )
    }

    // MARK: Join requests

    func sendJoinRequest(chatId: String, user: ChatMember) async throws {
        let _: StatusResp = try await network.post(
            "\(base)/chats/\(chatId)/requests",
            body: MemberActionBody(member: user)
        )
    }

    /// Returns the user IDs of people who have requested to join.
    func getJoinRequests(chatId: String) async throws -> [String] {
        struct Resp: Decodable {
            let data: Payload
            struct Payload: Decodable {
                let requests: [String]
                let count: Int
            }
        }
        let resp: Resp = try await network.get("\(base)/chats/\(chatId)/requests")
        return resp.data.requests
    }

    /// Approves a join request. Pass the *requester's* ChatMember info.
    func approveRequest(chatId: String, requester: ChatMember) async throws {
        let _: StatusResp = try await network.post(
            "\(base)/chats/\(chatId)/requests/approve",
            body: MemberActionBody(member: requester)
        )
    }

    // MARK: Leave

    func leaveChat(chatId: String, user: ChatMember) async throws {
        let _: StatusResp = try await network.post(
            "\(base)/chats/\(chatId)/leave",
            body: MemberActionBody(member: user)
        )
    }
}

// MARK: - Shared request body

/// The invite/request/approve/leave endpoints all take the same member shape
/// with camelCase keys (userid, userbio, userpic — no underscores).
private struct MemberActionBody: Encodable {
    let userid: String
    let username: String
    let userpic: String
    let userbio: String

    init(member: ChatMember) {
        userid = member.userId
        username = member.username
        userpic = member.userPic ?? ""
        userbio = member.userBio ?? ""
    }
}

private struct StatusResp: Decodable {
    let success: Bool
}
