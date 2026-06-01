//
//  LinkioChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import Combine
import os

@MainActor
final class LinkioChatService: ChatService {
    private let chatAPI = ChatAPIService()
    private let unreadAPI = UnreadAPIService()
    let currentUserId: String
    private let realtimeManager = RealtimeManager.shared
    private let readStateStore = ChatReadStateStore.shared

    private var subscriptions: [String: AnyCancellable] = [:]

    init(currentUserId: String) {
        self.currentUserId = currentUserId
    }

    // MARK: - Chats

    func fetchChats() async throws -> [ChatSummary] {
        let chats = try await chatAPI.getUserChats(userId: currentUserId)
        guard !chats.isEmpty else { return [] }

        let allIds = chats.map(\.id)

        // Batch-fetch members and last-message info in parallel — zero N+1 requests.
        async let membersMapTask = chatAPI.batchGetMembers(chatIds: allIds)
        async let lastMsgsTask = chatAPI.batchGetLastMessages(chatIds: allIds)
        let membersMap = (try? await membersMapTask) ?? [:]
        let lastMsgsMap = (try? await lastMsgsTask) ?? [:]

        var summaries: [ChatSummary] = []

        for chat in chats {
            let members: [ChatMember]
            if let batchResult = membersMap[chat.id] {
                members = batchResult
            } else {
                members = (try? await chatAPI.getChatMembers(chatId: chat.id)) ?? []
            }

            // Use Redis last-message info for text and timestamp.
            let lastInfo = lastMsgsMap[chat.id]
            let lastMessageOverride: String? = (chat.lastMessage?.isEmpty ?? true) ? lastInfo?.message : nil
            let lastTimestampOverride: Date? = lastInfo?.date

            // Seed local read state for brand-new chats so they don't appear unread.
            if let ts = lastTimestampOverride,
               readStateStore.lastReadDate(chatId: chat.id, userId: currentUserId) == nil {
                readStateStore.markRead(chatId: chat.id, userId: currentUserId, at: ts)
            }

            let summary = ChatSummary(
                chat: chat,
                members: members,
                currentUserId: currentUserId,
                unreadCount: 0,
                lastMessageOverride: lastMessageOverride,
                lastTimestampOverride: lastTimestampOverride
            )
            summaries.append(summary)
        }

        summaries.sort { ($0.lastTimestamp ?? .distantPast) > ($1.lastTimestamp ?? .distantPast) }

        // Fetch server-side unread counts in one bulk call.
        let chatIds = summaries.map(\.id)
        if let unreadMap = try? await unreadAPI.getUnreadInfoBulk(userId: currentUserId, chatIds: chatIds) {
            summaries = summaries.map { summary in
                let count = unreadMap[summary.id]?.unreadCount ?? 0
                return summary.withUnreadCount(count)
            }
        }

        return summaries
    }

    // MARK: - Messages

    func fetchMessages(chatId: String) async throws -> (messages: [Message], hasMore: Bool) {
        let result = try await chatAPI.getPaginatedMessages(chatId: chatId, limit: 50)
        return (result.messages.map { toMessage($0, chatId: chatId) }, result.hasMore)
    }

    func fetchOlderMessages(chatId: String, before: Date, limit: Int = 50) async throws -> (messages: [Message], hasMore: Bool) {
        let result = try await chatAPI.getMessagesBefore(chatId: chatId, before: before, limit: limit)
        return (result.messages.map { toMessage($0, chatId: chatId) }, result.hasMore)
    }

    // MARK: - Send / Edit / Delete

    func sendMessage(chatId: String, text: String, images: [String]?, files: [String]?) async throws {
        try await chatAPI.sendMessage(
            chatId: chatId,
            userId: currentUserId,
            text: text,
            images: images ?? [],
            files: files ?? []
        )
    }

    func editMessage(chatId: String, messageId: String, newText: String) async throws {
        try await chatAPI.editMessage(chatId: chatId, messageId: messageId, newText: newText)
    }

    func deleteMessage(chatId: String, messageId: String) async throws {
        try await chatAPI.deleteMessage(chatId: chatId, messageId: messageId)
    }

    // MARK: - Realtime

    func subscribeToMessages(chatId: String, onEvent: @escaping (Message) -> Void) async throws {
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

    // MARK: - Private

    private func toMessage(_ m: ChatMessage, chatId: String) -> Message {
        Message(
            id: m.messageId,
            chatId: chatId,
            senderId: m.userId,
            text: m.words,
            createdAt: m.date,
            isMine: m.userId == currentUserId,
            images: m.images,
            files: m.files
        )
    }
}

// MARK: - Last Message Info (from Redis bulk endpoint)

struct LastMessageInfo: Decodable {
    let message: String?
    let timestamp: Int64?
    let userId: String?
    let found: Bool

    enum CodingKeys: String, CodingKey {
        case message, found, timestamp
        case userId = "user_id"
    }

    var date: Date? {
        guard let ts = timestamp, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
    }
}

// MARK: - API Response Types

struct ChatResponse: Decodable {
    let data: Chat
}

struct ChatsResponse: Decodable {
    let success: Bool?
    let data: [Chat]?

    var chats: [Chat] { data ?? [] }
}

struct MessagesResponse: Decodable {
    let success: Bool
    let data: [ChatMessage]
    let page: Int?
    let limit: Int?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case success, data, page, limit
        case hasMore = "has_more"
    }
}

struct MessageResponse: Decodable {
    let success: Bool
    let data: ChatMessage?
}

// MARK: - Chat API Service

@MainActor
class ChatAPIService {
    private let network = NetworkService.shared
    private let chatBaseURL = APIConfig.chatAPI

    func getUserChats(userId: String) async throws -> [Chat] {
        let response: ChatsResponse = try await network.get("\(chatBaseURL)/users/\(userId)/chats")
        return response.chats
    }

    func getPaginatedMessages(chatId: String, limit: Int = 50) async throws -> (messages: [ChatMessage], hasMore: Bool) {
        let url = "\(chatBaseURL)/chats/\(chatId)/messages/paginated?limit=\(limit)"
        let response: MessagesResponse = try await network.get(url)
        return (response.data, response.hasMore ?? false)
    }

    func getMessagesBefore(chatId: String, before: Date, limit: Int = 50) async throws -> (messages: [ChatMessage], hasMore: Bool) {
        let ts = Int64(before.timeIntervalSince1970 * 1000)
        let url = "\(chatBaseURL)/chats/\(chatId)/messages/before?timestamp=\(ts)&limit=\(limit)"
        let response: MessagesResponse = try await network.get(url)
        return (response.data, response.hasMore ?? false)
    }

    func getLatestMessage(chatId: String) async throws -> ChatMessage? {
        let (messages, _) = try await getPaginatedMessages(chatId: chatId, limit: 1)
        return messages.first
    }

    func sendMessage(chatId: String, userId: String, text: String, images: [String], files: [String]) async throws {
        struct Body: Encodable {
            let chatId: String
            let userId: String
            let words: String
            let images: [String]
            let files: [String]
            let timestamp: Int64

            enum CodingKeys: String, CodingKey {
                case chatId = "chat_id"
                case userId = "user_id"
                case words, images, files, timestamp
            }
        }
        let body = Body(chatId: chatId, userId: userId, words: text, images: images, files: files,
                        timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        let _: MessageResponse = try await network.post("\(chatBaseURL)/chats/\(chatId)/messages/new", body: body)
    }

    func editMessage(chatId: String, messageId: String, newText: String) async throws {
        struct Body: Encodable { let words: String }
        struct EditResponse: Decodable { let success: Bool }
        let _: EditResponse = try await network.put(
            "\(chatBaseURL)/chats/\(chatId)/messages/\(messageId)",
            body: Body(words: newText)
        )
    }

    func deleteMessage(chatId: String, messageId: String) async throws {
        struct DeleteResponse: Decodable { let success: Bool }
        let _: DeleteResponse = try await network.delete(
            "\(chatBaseURL)/chats/\(chatId)/messages/\(messageId)"
        )
    }

    func getChatMembers(chatId: String) async throws -> [ChatMember] {
        struct MembersResponse: Decodable {
            let success: Bool
            let data: MembersList
        }
        let response: MembersResponse = try await network.get("\(chatBaseURL)/chats/\(chatId)/members")
        return response.data.members
    }

    // Returns { chatId: { message, timestamp, user_id, found } } from Redis last-message store
    func batchGetLastMessages(chatIds: [String]) async throws -> [String: LastMessageInfo] {
        struct Body: Encodable { let chat_ids: [String] }
        struct Envelope: Decodable {
            let data: Inner
            struct Inner: Decodable {
                let lastMessages: [String: LastMessageInfo]
                enum CodingKeys: String, CodingKey { case lastMessages = "last_messages" }
            }
        }
        let envelope: Envelope = try await network.post("\(chatBaseURL)/chats/last-messages", body: Body(chat_ids: chatIds))
        return envelope.data.lastMessages
    }

    func batchGetMembers(chatIds: [String]) async throws -> [String: [ChatMember]] {
        struct Body: Encodable { let chat_ids: [String] }
        // Backend returns { success: true, data: { "chatId": [Member] } }
        struct Envelope: Decodable {
            let data: [String: [ChatMember]]?
        }
        let envelope: Envelope = try await network.post("\(chatBaseURL)/chats/batch-members", body: Body(chat_ids: chatIds))
        return envelope.data ?? [:]
    }

    func getChatWithMembers(chatId: String) async throws -> (Chat, [ChatMember]) {
        struct Response: Decodable {
            let data: ChatWithMembersData
        }
        struct ChatWithMembersData: Decodable {
            let chat: Chat
            let members: [ChatMember]
        }
        let response: Response = try await network.get("\(chatBaseURL)/chats/\(chatId)/with-members")
        return (response.data.chat, response.data.members)
    }
}

// MARK: - Unread API Service

@MainActor
final class UnreadAPIService {
    private let network = NetworkService.shared
    private let base = APIConfig.chatAPI

    struct UnreadInfo: Decodable {
        let userId: String
        let chatId: String
        let unreadCount: Int
        let hasUnread: Bool
        let lastSeenTimestamp: Int64?
        let lastReadMessageId: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case chatId = "chat_id"
            case unreadCount = "unread_count"
            case hasUnread = "has_unread"
            case lastSeenTimestamp = "last_seen_timestamp"
            case lastReadMessageId = "last_read_message_id"
        }
    }

    private struct BulkResponse: Decodable {
        let chats: [String: UnreadInfo]
    }

    private struct BulkResponseEnvelope: Decodable {
        let data: BulkResponse?
        let chats: [String: UnreadInfo]?

        func unpack() -> [String: UnreadInfo] { data?.chats ?? chats ?? [:] }
    }

    private struct MarkReadRequest: Encodable {
        let userId: String
        let chatId: String
        let messageId: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case chatId = "chat_id"
            case messageId = "message_id"
        }
    }

    private struct MarkReadResponse: Decodable {
        let userId: String?
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    func getUnreadInfoBulk(userId: String, chatIds: [String]) async throws -> [String: UnreadInfo] {
        let joined = chatIds.joined(separator: ",")
        let url = "\(base)/unread/info-bulk?user_id=\(userId)&chat_ids=\(joined)"
        let envelope: BulkResponseEnvelope = try await network.get(url)
        return envelope.unpack()
    }

    func markRead(userId: String, chatId: String, messageId: String? = nil) async throws {
        let body = MarkReadRequest(userId: userId, chatId: chatId, messageId: messageId)
        let _: MarkReadResponse = try await network.post("\(base)/unread/mark-read", body: body)
    }
}

// MARK: - ChatSummary helper

extension ChatSummary {
    func withUnreadCount(_ count: Int) -> ChatSummary {
        ChatSummary(
            id: id,
            title: title,
            avatarURL: avatarURL,
            lastMessage: lastMessage,
            lastTimestamp: lastTimestamp,
            unreadCount: count,
            members: members
        )
    }
}
