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
        // Use centralized Pusher configuration
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
            let chatIds = chats.map { $0.id }
            // Fetch unread counts in bulk
            let unreadMap = try await chatAPI.getUnreadCounts(userId: currentUserId, chatIds: chatIds)
            // Fetch last messages in bulk
            let lastMessages = try await chatAPI.getLastMessages(chatIds: chatIds)
            
            // For each chat, get members to build ChatSummary
            var summaries: [ChatSummary] = []
            
            for chat in chats {
                do {
                    print("📥 Fetching members for chat: \(chat.id)")
                    let members = try await chatAPI.getChatMembers(chatId: chat.id)
                    print("✅ Got \(members.count) members")
                    let unread = unreadMap[chat.id] ?? 0
                    // Merge last message text and timestamp when available
                    let lastInfo = lastMessages[chat.id]
                    let lastText = lastInfo?.message ?? chat.lastMessage ?? "No messages yet"
                    let lastDate: Date = {
                        if let ts = lastInfo?.timestamp { return Date(timeIntervalSince1970: Double(ts) / 1000.0) }
                        else { return Date.distantPast }
                    }()
                    let summary = ChatSummary(
                        chat: chat,
                        members: members,
                        currentUserId: currentUserId,
                        unreadCount: unread,
                        lastMessageOverride: lastText,
                        lastTimestampOverride: lastDate
                    )
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

    func markChatRead(chatId: String) async throws {
        try await chatAPI.markChatRead(userId: currentUserId, chatId: chatId)
    }
    
    func fetchMessages(chatId: String) async throws -> [Message] {
        let messages = try await chatAPI.getMessages(chatId: chatId)
        
        // Convert ChatMessage to Message
        return messages.map { chatMsg in
            Message(
                id: chatMsg.messageId,
                chatId: chatId,
                senderId: chatMsg.userId,
                text: chatMsg.words,
                createdAt: chatMsg.date,
                isMine: chatMsg.userId == currentUserId
            )
        }
    }
    
    func sendMessage(chatId: String, text: String) async throws {
        try await chatAPI.sendMessage(
            chatId: chatId,
            userId: currentUserId,
            text: text
        )
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
        channel.bind(eventName: "new-message") { [weak self] data in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.handleNewMessage(data: data, chatId: chatId, onEvent: onEvent)
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

    // Subscribe to typing indicators on a chat channel
    func subscribeToTyping(
        chatId: String,
        onTypingStart: @escaping (_ userId: String, _ username: String) -> Void,
        onTypingStop: @escaping (_ userId: String) -> Void
    ) throws {
        let channelName = "chat-\(chatId)"
        let channel = pusher.subscribe(channelName)

        channel.bind(eventName: "user_typing") { data in
            guard let dict = data as? [String: Any] else { return }
            let userId = (dict["user_id"] as? String) ?? ""
            let username = (dict["username"] as? String) ?? "User"
            if !userId.isEmpty { onTypingStart(userId, username) }
        }

        channel.bind(eventName: "user_stop_typing") { data in
            guard let dict = data as? [String: Any] else { return }
            let userId = (dict["user_id"] as? String) ?? ""
            if !userId.isEmpty { onTypingStop(userId) }
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleNewMessage(data: Any?, chatId: String, onEvent: @escaping (Message) -> Void) {
        guard let dict = data as? [String: Any] else {
            print("⚠️ Invalid new-message data")
            return
        }
        
        // Parse message event from backend
        // Backend sends: ChatMessageEvent with chatID, messageID, userID, username, words, images, files, timestamp
        guard let messageId = dict["message_id"] as? String,
              let userId = dict["user_id"] as? String,
              let timestamp = dict["timestamp"] as? Int64 else {
            print("⚠️ Missing required fields in new-message event")
            return
        }
        
        let words = dict["words"] as? String ?? ""
        
        // Don't process messages from current user (they're already shown optimistically)
        if userId == currentUserId {
            print("⏩ Skipping own message: \(messageId)")
            return
        }
        
        // Convert timestamp (milliseconds) to Date
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        
        let message = Message(
            id:  messageId ,
            chatId: chatId,
            senderId:userId,
            text: words,
            createdAt: date,
            isMine: false
        )
        
        print("💬 Received new message: \(messageId) from \(userId)")
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
    let data: [ChatMessage]
}

struct MessageResponse: Codable {
    let success: Bool
    let data: ChatMessage?
}

// MARK: - Chat API Service

@MainActor
class ChatAPIService {
    private let network = NetworkService.shared
    private let chatBaseURL = "\(APIConfig.chatAPI)/api"
    
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
        let response: MessagesResponse = try await network.get("\(chatBaseURL)/chats/\(chatId)/messages/all")
        return response.data
    }
    
    func sendMessage(chatId: String, userId: String, text: String) async throws {
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
        
        let request = SendMessageRequest(
            chatId: chatId,
            userId: userId,
            words: text,
            images: [],
            files: [],
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        // Don't decode response - we use optimistic updates in UI
        // Just check that the request succeeds (201 status)
        let _: MessageResponse = try await network.post("\(chatBaseURL)/chats/\(chatId)/messages/new", body: request)
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

    // MARK: - Unread Tracking

    struct UnreadCountsResponse: Codable {
        let success: Bool
        let data: UnreadCountsData
    }

    struct UnreadCountsData: Codable {
        let user_id: String
        let unread_counts: [String: Int]
        let total_unread: Int
    }

    func getUnreadCounts(userId: String, chatIds: [String]) async throws -> [String: Int] {
        let joined = chatIds.joined(separator: ",")
        let url = "\(chatBaseURL)/unread/counts?user_id=\(userId)&chat_ids=\(joined)"
        let response: UnreadCountsResponse = try await network.get(url)
        return response.data.unread_counts
    }

    struct MarkReadRequest: Encodable {
        let user_id: String
        let chat_id: String
    }

    func markChatRead(userId: String, chatId: String) async throws {
        let req = MarkReadRequest(user_id: userId, chat_id: chatId)
        let _: EmptyResponse = try await network.post("\(chatBaseURL)/unread/mark-read", body: req)
    }

    // MARK: - Last Messages (bulk)
    struct LastMessageInfo: Codable {
        let chat_id: String
        let message: String?
        let timestamp: Int64?
        let user_id: String?
        let found: Bool
    }

    struct LastMessagesRequest: Encodable {
        let chat_ids: [String]
    }

    struct LastMessagesEnvelope: Codable {
        let data: LastMessagesData
    }

    struct LastMessagesData: Codable {
        let last_messages: [String: LastMessageInfo]
        let count: Int
    }

    func getLastMessages(chatIds: [String]) async throws -> [String: LastMessageInfo] {
        if chatIds.isEmpty { return [:] }
        let req = LastMessagesRequest(chat_ids: chatIds)
        let envelope: LastMessagesEnvelope = try await network.post("\(chatBaseURL)/chats/last-messages", body: req)
        return envelope.data.last_messages
    }
}
