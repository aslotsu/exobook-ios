//
//  ExobookChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import Combine

@MainActor
final class ExobookChatService: ChatService {
    private let chatAPI = ChatAPIService()
    let currentUserId: String
    private let realtimeManager = RealtimeManager.shared

    // Per-chat Combine subscriptions to RealtimeManager's chat publisher.
    private var subscriptions: [String: AnyCancellable] = [:]

    init(currentUserId: String) {
        self.currentUserId = currentUserId
    }
    
    func fetchChats() async throws -> [ChatSummary] {
        print("🔵 Fetching chats for user: \(currentUserId)")
        
        // Get user's chats
        do {
            let chats = try await chatAPI.getUserChats(userId: currentUserId)
            print("✅ Got \(chats.count) chats from API")
            
            // For each chat, get members to build ChatSummary
            var summaries: [ChatSummary] = []
            
            for chat in chats {
                do {
                    print("📥 Fetching members for chat: \(chat.id)")
                    let members = try await chatAPI.getChatMembers(chatId: chat.id)
                    print("✅ Got \(members.count) members")
                    let summary = ChatSummary(chat: chat, members: members, currentUserId: currentUserId)
                    summaries.append(summary)
                } catch {
                    print("❌ Failed to get members for chat \(chat.id): \(error)")
                    // Skip this chat if we can't get members
                    continue
                }
            }
            
            print("✅ Returning \(summaries.count) chat summaries")
            return summaries
        } catch {
            print("❌ Failed to fetch chats: \(error)")
            throw error
        }
    }
    
    func fetchMessages(chatId: String) async throws -> [Message] {
        print("📥 Fetching messages for chat: \(chatId)")

        do {
            let messages = try await chatAPI.getMessages(chatId: chatId)
            print("✅ Got \(messages.count) messages from API")

            // Convert ChatMessage to Message
            let converted = messages.map { chatMsg in
                Message(
                    id: chatMsg.messageId,
                    chatId: chatId,
                    senderId: chatMsg.userId,
                    text: chatMsg.words,
                    createdAt: chatMsg.date,
                    isMine: chatMsg.userId == currentUserId,
                    images: chatMsg.images,
                    files: chatMsg.files
                )
            }

            print("✅ Converted \(converted.count) messages")
            return converted
        } catch {
            print("❌ Failed to fetch messages: \(error)")
            throw error
        }
    }
    
    func sendMessage(chatId: String, text: String, images: [String]?, files: [String]?) async throws {
        print("📤 Sending message to chat: \(chatId)")
        print("   Text: \(text)")
        print("   Images: \(images?.count ?? 0), Files: \(files?.count ?? 0)")

        do {
            try await chatAPI.sendMessage(
                chatId: chatId,
                userId: currentUserId,
                text: text,
                images: images ?? [],
                files: files ?? []
            )
            print("✅ Message sent successfully")
        } catch {
            print("❌ Failed to send message: \(error)")
            throw error
        }
    }
    
    func subscribeToMessages(chatId: String, onEvent: @escaping (Message) -> Void) async throws {
        // Cancel any existing subscription for this chat before re-subscribing.
        subscriptions[chatId]?.cancel()

        let cancellable = realtimeManager
            .chatMessagePublisher(chatId: chatId)
            .sink(receiveValue: onEvent)

        subscriptions[chatId] = cancellable
    }

    func unsubscribe(chatId: String) {
        subscriptions.removeValue(forKey: chatId)?.cancel()
        realtimeManager.unsubscribeFromChat(chatId: chatId)
    }
}

// MARK: - API Response Types

struct ChatResponse: Codable {
    let data: Chat
}

struct ChatsResponse: Codable {
    let success: Bool
    let data: [Chat]?
    
    var chats: [Chat] {
        data ?? []  // Return empty array if data is null
    }
}

struct MessagesResponse: Codable {
    let success: Bool
    let data: [ChatMessage]
    let page: Int?
    let limit: Int?
    let hasMore: Bool?

    // No CodingKeys needed - NetworkService.convertFromSnakeCase handles has_more -> hasMore automatically
}

struct MessageResponse: Codable {
    let success: Bool
    let data: ChatMessage?
}

// MARK: - Chat API Service

@MainActor
class ChatAPIService {
    private let network = NetworkService.shared
    private let chatBaseURL = APIConfig.chatAPI
    
    func getUserChats(userId: String) async throws -> [Chat] {
        let url = "\(chatBaseURL)/users/\(userId)/chats"
        print("🌐 GET \(url)")
        do {
            let response: ChatsResponse = try await network.get(url)
            print("✅ Response: \(response.chats.count) chats")
            return response.chats
        } catch {
            print("❌ Error fetching chats: \(error)")
            throw error
        }
    }
    
    func getMessages(chatId: String) async throws -> [ChatMessage] {
        let url = "\(chatBaseURL)/chats/\(chatId)/messages/all"
        print("🌐 GET \(url)")
        do {
            let response: MessagesResponse = try await network.get(url)
            print("✅ Response: \(response.data.count) messages (page \(response.page ?? 1), hasMore: \(response.hasMore ?? false))")
            return response.data
        } catch {
            print("❌ Error fetching messages: \(error)")
            throw error
        }
    }
    
    func sendMessage(chatId: String, userId: String, text: String, images: [String], files: [String]) async throws {
        struct SendMessageRequest: Encodable {
            let chatId: String
            let userId: String
            let words: String
            let images: [String]
            let files: [String]
            let timestamp: Int64
            
            enum CodingKeys: String, CodingKey {
                case chatId = "chat_id"
                case userId = "user_id"
                case words
                case images
                case files
                case timestamp
            }
        }
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let request = SendMessageRequest(
            chatId: chatId,
            userId: userId,
            words: text,
            images: images,
            files: files,
            timestamp: timestamp
        )

        let url = "\(chatBaseURL)/chats/\(chatId)/messages/new"
        print("🌐 POST \(url)")
        print("   Request: userId=\(userId), timestamp=\(timestamp)")

        do {
            let _: MessageResponse = try await network.post(url, body: request)
            print("✅ Message created successfully")
        } catch {
            print("❌ Error sending message: \(error)")
            throw error
        }
    }
    
    func getChatMembers(chatId: String) async throws -> [ChatMember] {
        struct MembersResponse: Codable {
            let success: Bool
            let data: MembersList
        }
        let url = "\(chatBaseURL)/chats/\(chatId)/members"
        print("🌐 GET \(url)")
        do {
            let response: MembersResponse = try await network.get(url)
            print("✅ Response: \(response.data.members.count) members")
            return response.data.members
        } catch {
            print("❌ Error fetching members: \(error)")
            throw error
        }
    }
    
    func getChatWithMembers(chatId: String) async throws -> (Chat, [ChatMember]) {
        struct Response: Codable {
            let data: ChatWithMembersData
        }
        struct ChatWithMembersData: Codable {
            let chat: Chat
            let members: [ChatMember]
        }
        
        let url = "\(chatBaseURL)/chats/\(chatId)/with-members"
        print("🌐 GET \(url)")
        let response: Response = try await network.get(url)
        return (response.data.chat, response.data.members)
    }
}
