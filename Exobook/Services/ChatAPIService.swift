//
//  ChatAPIService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
class ChatAPIService {
    private let network = NetworkService.shared
    private var baseURL: String {
        APIConfig.chatAPI
    }
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> HealthResponse {
        try await network.get("\(baseURL)/api/health")
    }
    
    // MARK: - Chat Operations
    
    func createChat(_ request: CreateChatRequest) async throws -> ChatResponse {
        try await network.post("\(baseURL)/api/chats/new", body: request)
    }
    
    func listChats(userId: String) async throws -> [ChatResponse] {
        try await network.get("\(baseURL)/api/chats/all?user_id=\(userId)")
    }
    
    func getChat(chatId: String) async throws -> ChatResponse {
        try await network.get("\(baseURL)/api/chats/\(chatId)")
    }
    
    func getChatWithMembers(chatId: String) async throws -> ChatWithMembersResponse {
        try await network.get("\(baseURL)/api/chats/\(chatId)/with-members")
    }
    
    func updateChat(chatId: String, request: UpdateChatRequest) async throws -> ChatResponse {
        try await network.put("\(baseURL)/api/chats/\(chatId)", body: request)
    }
    
    func deleteChat(chatId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/chats/\(chatId)")
    }
    
    func getUserChats(userId: String) async throws -> [ChatResponse] {
        try await network.get("\(baseURL)/api/users/\(userId)/chats")
    }
    
    func checkDirectChat(user1Id: String, user2Id: String) async throws -> DirectChatCheckResponse {
        try await network.get("\(baseURL)/api/check-chat?user1_id=\(user1Id)&user2_id=\(user2Id)")
    }
    
    func findDirectChatID(user1Id: String, user2Id: String) async throws -> FindChatResponse {
        try await network.get("\(baseURL)/api/find-chat?user1_id=\(user1Id)&user2_id=\(user2Id)")
    }
    
    // MARK: - Message Operations
    
    func createMessage(chatId: String, request: CreateMessageRequest) async throws -> MessageResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/messages/new", body: request)
    }
    
    func getMessages(chatId: String) async throws -> [MessageResponse] {
        try await network.get("\(baseURL)/api/chats/\(chatId)/messages/all")
    }
    
    func getMessagesPaginated(chatId: String, limit: Int, lastKey: String?) async throws -> PaginatedMessagesResponse {
        var url = "\(baseURL)/api/chats/\(chatId)/messages/paginated?limit=\(limit)"
        if let lastKey = lastKey {
            url += "&last_key=\(lastKey)"
        }
        return try await network.get(url)
    }
    
    func getMessage(chatId: String, messageId: String) async throws -> MessageResponse {
        try await network.get("\(baseURL)/api/chats/\(chatId)/messages/\(messageId)")
    }
    
    func updateMessage(chatId: String, messageId: String, request: UpdateMessageRequest) async throws -> MessageResponse {
        try await network.put("\(baseURL)/api/chats/\(chatId)/messages/\(messageId)", body: request)
    }
    
    func deleteMessage(chatId: String, messageId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/chats/\(chatId)/messages/\(messageId)")
    }
    
    func deleteAllMessages(chatId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/chats/\(chatId)/messages")
    }
    
    // MARK: - Member Operations
    
    func getMembers(chatId: String) async throws -> [String] {
        let response: MembersResponse = try await network.get("\(baseURL)/api/chats/\(chatId)/members")
        return response.members
    }
    
    func addMember(chatId: String, request: AddMemberRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/members/add", body: request)
    }
    
    func removeMember(chatId: String, userId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/chats/\(chatId)/members/\(userId)")
    }
    
    func checkMemberStatus(chatId: String, userId: String) async throws -> MemberStatusResponse {
        try await network.get("\(baseURL)/api/chats/\(chatId)/members/\(userId)/status")
    }
    
    // MARK: - Invite & Join Operations
    
    func sendInvite(chatId: String, request: InviteRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/invites", body: request)
    }
    
    func acceptInvite(chatId: String, request: AcceptInviteRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/invites/accept", body: request)
    }
    
    func rejectInvite(chatId: String, request: RejectInviteRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/invites/reject", body: request)
    }
    
    func joinChatDirect(chatId: String, request: JoinChatRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/join", body: request)
    }
    
    func leaveChat(chatId: String, request: LeaveChatRequest) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/chats/\(chatId)/leave", body: request)
    }
    
    // MARK: - Last Message Operations
    
    func getLastMessage(chatId: String) async throws -> LastMessageResponse {
        try await network.post("\(baseURL)/api/chats/last-message", body: ["chat_id": chatId])
    }
    
    func getLastMessages(chatIds: [String]) async throws -> [String: LastMessageResponse] {
        try await network.post("\(baseURL)/api/chats/last-messages", body: ["chat_ids": chatIds])
    }
}

// MARK: - Request Models

struct CreateChatRequest: Encodable {
    let chatId: String
    let name: String
    let chatType: String // "direct" or "group"
    let createdBy: String
    let members: [String]?
}

struct UpdateChatRequest: Encodable {
    let name: String?
    let description: String?
}

struct CreateMessageRequest: Encodable {
    let messageId: String
    let senderId: String
    let content: String
    let messageType: String? // "text", "image", etc.
}

struct UpdateMessageRequest: Encodable {
    let content: String
}

struct AddMemberRequest: Encodable {
    let userId: String
    let addedBy: String
}

struct InviteRequest: Encodable {
    let inviteeId: String
    let invitedBy: String
}

struct AcceptInviteRequest: Encodable {
    let userId: String
}

struct RejectInviteRequest: Encodable {
    let userId: String
}

struct JoinChatRequest: Encodable {
    let userId: String
}

struct LeaveChatRequest: Encodable {
    let userId: String
}

// MARK: - Response Models

struct HealthResponse: Codable {
    let success: String?
    let failure: String?
}

struct ChatResponse: Codable {
    let chatId: String
    let name: String
    let chatType: String
    let createdBy: String
    let createdAt: String
    let description: String?
}

struct ChatWithMembersResponse: Codable {
    let chat: ChatResponse
    let members: [String]
}

struct MessageResponse: Codable {
    let messageId: String
    let chatId: String
    let senderId: String
    let content: String
    let createdAt: String
    let messageType: String?
    let updatedAt: String?
}

struct PaginatedMessagesResponse: Codable {
    let messages: [MessageResponse]
    let lastKey: String?
}

struct MembersResponse: Codable {
    let members: [String]
}

struct MemberStatusResponse: Codable {
    let isMember: Bool
}

struct DirectChatCheckResponse: Codable {
    let exists: Bool
    let chatId: String?
}

struct FindChatResponse: Codable {
    let chatId: String?
}

struct LastMessageResponse: Codable {
    let chatId: String
    let message: MessageResponse?
}
