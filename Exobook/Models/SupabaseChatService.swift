//
//  SupabaseChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import Foundation
import Supabase

@MainActor
final class SupabaseChatService: ChatService {
    private let client: SupabaseClient
    private var realtimeSubscriptions: [UUID: RealtimeChannelV2] = [:]
    
    init() {
        self.client = supabase
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func fetchChats() async throws -> [ChatSummary] {
        // Fetch chat summaries from your Supabase database
        // This assumes you have a 'chats' table with columns: id, title, avatar_url, last_message, last_timestamp, unread_count
        let response: [ChatSummaryDTO] = try await client
            .from("chats")
            .select()
            .order("last_timestamp", ascending: false)
            .execute()
            .value
        
        return response.map { dto in
            ChatSummary(
                id: dto.id,
                title: dto.title,
                avatarURL: dto.avatarURL,
                lastMessage: dto.lastMessage,
                lastTimestamp: dto.lastTimestamp,
                unreadCount: dto.unreadCount
            )
        }
    }
    
    func fetchMessages(chatId: UUID) async throws -> [Message] {
        // Fetch messages for a specific chat
        // This assumes you have a 'messages' table with columns: id, chat_id, sender_id, text, created_at
        let response: [MessageDTO] = try await client
            .from("messages")
            .select()
            .eq("chat_id", value: chatId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        // Get current user ID (you'll need to implement getCurrentUserId())
        let currentUserId = try await getCurrentUserId()
        
        return response.map { dto in
            Message(
                id: dto.id,
                chatId: dto.chatId,
                senderId: dto.senderId,
                text: dto.text,
                createdAt: dto.createdAt,
                isMine: dto.senderId == currentUserId
            )
        }
    }
    
    func sendMessage(chatId: UUID, text: String) async throws {
        let currentUserId = try await getCurrentUserId()
        
        let messageData: [String: AnyJSON] = [
            "id": .string(UUID().uuidString),
            "chat_id": .string(chatId.uuidString),
            "sender_id": .string(currentUserId.uuidString),
            "text": .string(text),
            "created_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client
            .from("messages")
            .insert(messageData)
            .execute()
        
        // Update the chat's last_message and last_timestamp
        let chatUpdateData: [String: AnyJSON] = [
            "last_message": .string(text),
            "last_timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client
            .from("chats")
            .update(chatUpdateData)
            .eq("id", value: chatId)
            .execute()
    }
    
    func subscribeToMessages(chatId: UUID, onEvent: @escaping (Message) -> Void) async throws {
        let channel = client.realtimeV2.channel("messages:\(chatId)")
        
        await channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chatId)"
        ) { action in
            Task { @MainActor in
                do {
                    let messageDTO = try JSONDecoder().decode(MessageDTO.self, from: JSONSerialization.data(withJSONObject: action.record))
                    let currentUserId = try? await self.getCurrentUserId()
                    let message = Message(
                        id: messageDTO.id,
                        chatId: messageDTO.chatId,
                        senderId: messageDTO.senderId,
                        text: messageDTO.text,
                        createdAt: messageDTO.createdAt,
                        isMine: messageDTO.senderId == currentUserId
                    )
                    onEvent(message)
                } catch {
                    print("Failed to decode message: \(error)")
                }
            }
        }
        
        await channel.subscribe()
        realtimeSubscriptions[chatId] = channel
    }
    
    func unsubscribe(chatId: UUID) {
        if let channel = realtimeSubscriptions[chatId] {
            Task {
                await channel.unsubscribe()
            }
            realtimeSubscriptions.removeValue(forKey: chatId)
        }
    }
    
    private func getCurrentUserId() async throws -> UUID {
        guard let session = client.auth.currentSession else {
            throw ChatServiceError.notAuthenticated
        }
        return UUID(uuidString: session.user.id.uuidString) ?? UUID()
    }
}

// MARK: - DTOs
private struct ChatSummaryDTO: Codable {
    let id: UUID
    let title: String
    let avatarURL: URL?
    let lastMessage: String
    let lastTimestamp: Date
    let unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case avatarURL = "avatar_url"
        case lastMessage = "last_message"
        case lastTimestamp = "last_timestamp"
        case unreadCount = "unread_count"
    }
}

private struct MessageDTO: Codable {
    let id: UUID
    let chatId: UUID
    let senderId: UUID
    let text: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case text
        case createdAt = "created_at"
    }
}

enum ChatServiceError: Error {
    case notAuthenticated
    case invalidData
}