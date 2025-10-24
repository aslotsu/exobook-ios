//
//  DynamoDBChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
final class DynamoDBChatService: ChatService {
    private let api = ChatAPIService()
    private let currentUserId: String // You'll need to get this from your auth system
    
    init(currentUserId: String = "test-user-id") {
        self.currentUserId = currentUserId
    }
    
    func fetchChats() async throws -> [ChatSummary] {
        let chatResponses = try await api.getUserChats(userId: currentUserId)
        
        // Fetch last messages for all chats
        let chatIds = chatResponses.map { $0.chatId }
        let lastMessages = try? await api.getLastMessages(chatIds: chatIds)
        
        return chatResponses.map { chatResponse in
            let lastMsg = lastMessages?[chatResponse.chatId]?.message
            
            return ChatSummary(
                id: UUID(uuidString: chatResponse.chatId) ?? UUID(),
                title: chatResponse.name,
                avatarURL: nil, // Add avatar support later
                lastMessage: lastMsg?.content ?? "No messages yet",
                lastTimestamp: parseDate(lastMsg?.createdAt) ?? Date(),
                unreadCount: 0 // Add unread count support later
            )
        }
    }
    
    func fetchMessages(chatId: UUID) async throws -> [Message] {
        let messageResponses = try await api.getMessages(chatId: chatId.uuidString)
        
        return messageResponses.map { msgResponse in
            Message(
                id: UUID(uuidString: msgResponse.messageId) ?? UUID(),
                chatId: chatId,
                senderId: UUID(uuidString: msgResponse.senderId) ?? UUID(),
                text: msgResponse.content,
                createdAt: parseDate(msgResponse.createdAt) ?? Date(),
                isMine: msgResponse.senderId == currentUserId
            )
        }
    }
    
    func sendMessage(chatId: UUID, text: String) async throws {
        let request = CreateMessageRequest(
            messageId: UUID().uuidString,
            senderId: currentUserId,
            content: text,
            messageType: "text"
        )
        
        _ = try await api.createMessage(chatId: chatId.uuidString, request: request)
    }
    
    func subscribeToMessages(chatId: UUID, onEvent: @escaping (Message) -> Void) async throws {
        // Real-time subscriptions would be handled via Pusher on the backend
        // For now, you could implement polling or integrate Pusher client
        print("Real-time subscriptions not yet implemented for DynamoDB backend")
        
        // TODO: Integrate Pusher client for real-time updates
        // The backend already sends events via Pusher when messages are created
    }
    
    func unsubscribe(chatId: UUID) {
        // Clean up Pusher subscriptions when implemented
        print("Unsubscribe called for chat: \(chatId)")
    }
    
    // MARK: - Helper Methods
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}

// MARK: - Extended Chat Features

extension DynamoDBChatService {
    /// Create a new direct chat with another user
    func createDirectChat(withUserId: String, name: String) async throws -> UUID {
        // Check if chat already exists
        let existingChat = try await api.checkDirectChat(user1Id: currentUserId, user2Id: withUserId)
        
        if existingChat.exists, let chatId = existingChat.chatId {
            return UUID(uuidString: chatId) ?? UUID()
        }
        
        // Create new chat
        let request = CreateChatRequest(
            chatId: UUID().uuidString,
            name: name,
            chatType: "direct",
            createdBy: currentUserId,
            members: [currentUserId, withUserId]
        )
        
        let response = try await api.createChat(request)
        return UUID(uuidString: response.chatId) ?? UUID()
    }
    
    /// Create a new group chat
    func createGroupChat(name: String, memberIds: [String]) async throws -> UUID {
        let request = CreateChatRequest(
            chatId: UUID().uuidString,
            name: name,
            chatType: "group",
            createdBy: currentUserId,
            members: [currentUserId] + memberIds
        )
        
        let response = try await api.createChat(request)
        return UUID(uuidString: response.chatId) ?? UUID()
    }
    
    /// Add a member to a chat
    func addMember(chatId: UUID, userId: String) async throws {
        let request = AddMemberRequest(userId: userId, addedBy: currentUserId)
        _ = try await api.addMember(chatId: chatId.uuidString, request: request)
    }
    
    /// Remove a member from a chat
    func removeMember(chatId: UUID, userId: String) async throws {
        _ = try await api.removeMember(chatId: chatId.uuidString, userId: userId)
    }
    
    /// Leave a chat
    func leaveChat(chatId: UUID) async throws {
        let request = LeaveChatRequest(userId: currentUserId)
        _ = try await api.leaveChat(chatId: chatId.uuidString, request: request)
    }
}
