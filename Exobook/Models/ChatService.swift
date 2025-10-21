//
//  ChatService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation

@MainActor
protocol ChatService {
    func fetchChats() async throws -> [ChatSummary]
    func fetchMessages(chatId: UUID) async throws -> [Message]
    func sendMessage(chatId: UUID, text: String) async throws
    func subscribeToMessages(chatId: UUID, onEvent: @escaping (Message) -> Void) async throws
    func unsubscribe(chatId: UUID)
}

final class MockChatService: ChatService {
    private var listeners: [UUID: [(Message) -> Void]] = [:]
    private let me = UUID()

    func fetchChats() async throws -> [ChatSummary] {
        [
            ChatSummary(id: UUID(), title: "Elionore", avatarURL: nil, lastMessage: "On y va à 18h ?", lastTimestamp: .now.addingTimeInterval(-300), unreadCount: 2),
            ChatSummary(id: UUID(), title: "Team Exobook", avatarURL: nil, lastMessage: "Build passes ✅", lastTimestamp: .now.addingTimeInterval(-7200), unreadCount: 0),
            ChatSummary(id: UUID(), title: "Gigi Morissette", avatarURL: nil, lastMessage: "Merci !", lastTimestamp: .now.addingTimeInterval(-86400), unreadCount: 0)
        ]
    }

    func fetchMessages(chatId: UUID) async throws -> [Message] {
        let other = UUID()
        return [
            Message(id: UUID(), chatId: chatId, senderId: other, text: "Salut 👋", createdAt: .now.addingTimeInterval(-3600), isMine: false),
            Message(id: UUID(), chatId: chatId, senderId: me,    text: "Hey! prêt ?", createdAt: .now.addingTimeInterval(-3550), isMine: true),
            Message(id: UUID(), chatId: chatId, senderId: other, text: "Toujours", createdAt: .now.addingTimeInterval(-3500), isMine: false)
        ]
    }

    func sendMessage(chatId: UUID, text: String) async throws {
        let msg = Message(id: UUID(), chatId: chatId, senderId: me, text: text, createdAt: .now, isMine: true)
        listeners[chatId]?.forEach { $0(msg) }
        // Simulate reply
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let reply = Message(id: UUID(), chatId: chatId, senderId: UUID(), text: "👍", createdAt: .now, isMine: false)
            await MainActor.run { self.listeners[chatId]?.forEach { $0(reply) } }
        }
    }

    func subscribeToMessages(chatId: UUID, onEvent: @escaping (Message) -> Void) async throws {
        listeners[chatId, default: []].append(onEvent)
    }

    func unsubscribe(chatId: UUID) {
        listeners.removeValue(forKey: chatId)
    }
}
