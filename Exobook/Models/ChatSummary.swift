//
//  ChatSummary.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation
import SwiftUI

struct ChatSummary: Identifiable, Hashable {
    let id: String  // Keep as String to preserve exact case from backend
    let title: String
    let avatarURL: URL?
    let lastMessage: String
    let lastTimestamp: Date?
    let unreadCount: Int
    let members: [ChatMember]
    
    init(
        id: String,
        title: String,
        avatarURL: URL?,
        lastMessage: String,
        lastTimestamp: Date?,
        unreadCount: Int,
        members: [ChatMember]
    ) {
        self.id = id
        self.title = title
        self.avatarURL = avatarURL
        self.lastMessage = lastMessage
        self.lastTimestamp = lastTimestamp
        self.unreadCount = unreadCount
        self.members = members
    }

    init(
        chat: Chat,
        members: [ChatMember],
        currentUserId: String,
        unreadCount: Int = 0,
        lastMessageOverride: String? = nil,
        lastTimestampOverride: Date? = nil
    ) {
        self.id = chat.id
        self.members = members

        let topic = chat.metadata?.topic?.trimmingCharacters(in: .whitespacesAndNewlines)
        let headerImage = chat.headerImage?.trimmingCharacters(in: .whitespacesAndNewlines)

        // DM: exactly 2 members, no topic set → use the other person's name and avatar.
        if members.count == 2,
           (topic == nil || topic!.isEmpty),
           let other = members.first(where: { $0.userId != currentUserId }) {
            self.title = other.username.isEmpty ? "Chat" : other.username
            self.avatarURL = other.avatarURL
        } else {
            // Group chat: use metadata.topic, fall back to a members summary.
            if let topic, !topic.isEmpty {
                self.title = topic
            } else {
                let names = members.prefix(3).map(\.username).joined(separator: ", ")
                self.title = names.isEmpty ? "Group Chat" : names
            }
            self.avatarURL = headerImage.flatMap { URL(string: $0) }
        }
        
        self.lastMessage = lastMessageOverride ?? chat.lastMessage ?? "No messages yet"
        self.lastTimestamp = lastTimestampOverride ?? chat.lastMessageAt
        self.unreadCount = unreadCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatSummary, rhs: ChatSummary) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChatSummary {
    var isDirectMessage: Bool {
        let parts = id.split(separator: "_", omittingEmptySubsequences: false)
        return parts.count == 2
            && !parts[0].isEmpty
            && !parts[1].isEmpty
            && parts[0] != parts[1]
            && !id.hasPrefix("group_")
    }

    var isGroupChat: Bool {
        !isDirectMessage
    }
}

struct Message: Identifiable, Hashable {
    let id: String
    let chatId: String  // Keep as String to preserve exact case
    let senderId: String
    let text: String
    let createdAt: Date
    let isMine: Bool
    let images: [String]?
    let files: [String]?
}
