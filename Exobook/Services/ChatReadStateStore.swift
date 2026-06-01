//
//  ChatReadStateStore.swift
//  Exobook
//

import Foundation

@MainActor
final class ChatReadStateStore {
    static let shared = ChatReadStateStore()

    private init() {}

    func lastReadDate(chatId: String, userId: String) -> Date? {
        guard let timestamp = UserDefaults.standard.object(
            forKey: storageKey(chatId: chatId, userId: userId)
        ) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    func markRead(chatId: String, userId: String, at date: Date = Date()) {
        UserDefaults.standard.set(
            date.timeIntervalSince1970,
            forKey: storageKey(chatId: chatId, userId: userId)
        )
    }

    private func storageKey(chatId: String, userId: String) -> String {
        "chat_last_read_\(userId)_\(chatId)"
    }
}
