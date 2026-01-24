//
//  ExobookChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import PusherSwift

@MainActor
final class ExobookChatService: ChatService {
    private let chatAPI = ChatAPIService()
    let currentUserId: String
    private var realtimeManager = RealtimeManager.shared
    
    // Pusher client for chat real-time messaging
    private var pusher: Pusher!
    
    // Store active chat subscriptions: chatId -> (channel, callback)
    private var activeSubscriptions: [String: (PusherChannel, (Message) -> Void)] = [:]
    
    init(currentUserId: String) {
        self.currentUserId = currentUserId
        setupPusher()
    }
    
    private func setupPusher() {
        // Pusher credentials from centralized configuration
        let pusherKey = PusherConfig.key
        let pusherCluster = PusherConfig.cluster

        let options = PusherClientOptions(host: .cluster(pusherCluster))
        pusher = Pusher(key: pusherKey, options: options)
        pusher.connect()

        print("🔴 Chat Pusher configured for user: \(currentUserId)")
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
        print("📡 Subscribing to messages for chat: \(chatId)")
        
        // Unsubscribe if already subscribed to this chat
        if activeSubscriptions[chatId] != nil {
            unsubscribe(chatId: chatId)
        }
        
        // Channel name format from backend: "chat-{chatID}"
        let channelName = "chat-\(chatId)"
        let channel = pusher.subscribe(channelName)
        
        // Bind to "new-message" event from backend
        channel.bind(eventName: "new-message") { [weak self] event in
            print("📥 [PUSHER EVENT] new-message received")
            guard let self = self else { return }
            
            // Extract JSON data from PusherEvent
            guard let eventData = event.data,
                  let jsonData = eventData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse new-message event data")
                print("📦 Event data string: \(event.data ?? "nil")")
                return
            }
            
            print("📦 Parsed new-message JSON: \(json)")
            Task { @MainActor in
                self.handleNewMessage(data: json, chatId: chatId, onEvent: onEvent)
            }
        }
        
        // Store subscription
        activeSubscriptions[chatId] = (channel, onEvent)
        
        print("✅ Subscribed to channel: \(channelName)")
    }
    
    func unsubscribe(chatId: String) {
        print("🔇 Unsubscribing from chat: \(chatId)")
        
        guard let (channel, _) = activeSubscriptions[chatId] else {
            print("⚠️ No active subscription for chat: \(chatId)")
            return
        }
        
        let channelName = "chat-\(chatId)"
        channel.unbindAll()
        pusher.unsubscribe(channelName)
        activeSubscriptions.removeValue(forKey: chatId)
        
        print("✅ Unsubscribed from channel: \(channelName)")
    }
    
    // MARK: - Private Helpers
    
    private func handleNewMessage(data: [String: Any], chatId: String, onEvent: @escaping (Message) -> Void) {
        print("🔍 Processing new-message event...")
        
        // Parse message event from backend
        // Backend sends: ChatMessageEvent with chatID, messageID, userID, username, words, images, files, timestamp
        guard let messageId = data["message_id"] as? String,
              let userId = data["user_id"] as? String,
              let timestamp = data["timestamp"] as? Int64 else {
            print("❌ Invalid new-message data structure!")
            print("📦 Expected: {message_id, user_id, timestamp, ...}")
            print("📦 Received: \(String(describing: data))")
            return
        }
        
        let words = data["words"] as? String ?? ""
        let username = data["username"] as? String ?? "Unknown"
        let images = data["images"] as? [String]
        let files = data["files"] as? [String]
        
        print("💬 NEW-MESSAGE PARSED SUCCESSFULLY:")
        print("   📌 Message ID: \(messageId)")
        print("   👤 From: \(username) (\(userId))")
        print("   💭 Text: \(String(words.prefix(50)))")
        print("   🔄 Is current user: \(userId == currentUserId ? "YES" : "NO")")
        
        // Don't process messages from current user (they're already shown optimistically)
        if userId == currentUserId {
            print("⏩ Skipping own message (already shown optimistically)")
            return
        }
        
        // Convert timestamp (milliseconds) to Date
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        
        let message = Message(
            id: messageId,
            chatId: chatId,
            senderId: userId,
            text: words,
            createdAt: date,
            isMine: false,
            images: images,
            files: files
        )
        
        print("✅ Calling onEvent callback to append message to UI")
        onEvent(message)
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
    private let chatBaseURL = "https://mchats.exobook.ca/api"
    
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
