//
//  ChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation

@MainActor
protocol ChatService {
    var currentUserId: String { get }

    func fetchChats() async throws -> [ChatSummary]
    func fetchMessages(chatId: String) async throws -> [Message]
    func sendMessage(chatId: String, text: String) async throws
    func subscribeToMessages(chatId: String, onEvent: @escaping (Message) -> Void) async throws
    func unsubscribe(chatId: String)
    func markChatRead(chatId: String) async throws
}

//final class MockChatService: ChatService {
//    private var listeners: [String: [(Message) -> Void]] = [:]
//    private let me = UUID()
//
//    var currentUserId: String { me.uuidString }
//
//    func fetchChats() async throws -> [ChatSummary] {
//        // Create dummy chats with proper Chat and ChatMember objects
//        let chat1 = Chat(id: UUID().uuidString, password: nil, headerImage: nil, metadata: nil, length: 5, lastMessage: "On y va à 18h ?", membersKey: nil)
//        let members1 = [ChatMember(userId: me.uuidString, username: "Me", userBio: nil, userPic: nil), ChatMember(userId: UUID().uuidString, username: "Elionore", userBio: nil, userPic: nil)]
//
//        let chat2 = Chat(id: UUID().uuidString, password: nil, headerImage: nil, metadata: nil, length: 10, lastMessage: "Build passes ✅", membersKey: nil)
//        let members2 = [ChatMember(userId: me.uuidString, username: "Me", userBio: nil, userPic: nil), ChatMember(userId: UUID().uuidString, username: "Team Exobook", userBio: nil, userPic: nil)]
//
//        return [
//            ChatSummary(chat: chat1, members: members1, currentUserId: me.uuidString),
//            ChatSummary(chat: chat2, members: members2, currentUserId: me.uuidString)
//        ]
//    }
//
//    func fetchMessages(chatId: String) async throws -> [Message] {
//        let other = UUID()
//        return [
//
//        ]
//    }
//
//    func sendMessage(chatId: String, text: String) async throws {
//        let msg = Message(id: UUID(), chatId: chatId, senderId: me, text: text, createdAt: .now, isMine: true)
//        listeners[chatId]?.forEach { $0(msg) }
//        // Simulate reply
//        Task {
//            try? await Task.sleep(nanoseconds: 800_000_000)
//            let reply = Message(id: UUID(), chatId: chatId, senderId: UUID(), text: "👍", createdAt: .now, isMine: false)
//            await MainActor.run { self.listeners[chatId]?.forEach { $0(reply) } }
//        }
//    }
//
//    func subscribeToMessages(chatId: String, onEvent: @escaping (Message) -> Void) async throws {
//        listeners[chatId, default: []].append(onEvent)
//    }
//
//    func unsubscribe(chatId: String) {
//        listeners.removeValue(forKey: chatId)
//    }
//}
