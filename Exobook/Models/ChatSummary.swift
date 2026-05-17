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
        chat: Chat,
        members: [ChatMember],
        currentUserId: String,
        lastMessageOverride: String? = nil,
        lastTimestampOverride: Date? = nil
    ) {
        self.id = chat.id  // Use chat ID as-is from backend
        self.members = members
        
        // For 1-on-1 chats, title is other person's name
        if members.count == 2, let otherMember = members.first(where: { $0.userId != currentUserId }) {
            self.title = otherMember.username
            self.avatarURL = otherMember.avatarURL
        } else {
            // Group chat
            self.title = "Group Chat"
            self.avatarURL = nil
        }
        
        self.lastMessage = lastMessageOverride ?? chat.lastMessage ?? "No messages yet"
        self.lastTimestamp = lastTimestampOverride ?? chat.lastMessageAt
        self.unreadCount = 0 // TODO: Implement unread tracking
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatSummary, rhs: ChatSummary) -> Bool {
        lhs.id == rhs.id
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
