//
//  ChatSummary.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation
import SwiftUI

struct ChatSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let avatarURL: URL?
    let lastMessage: String
    let lastTimestamp: Date
    let unreadCount: Int
}

struct Message: Identifiable, Hashable {
    let id: UUID
    let chatId: UUID
    let senderId: UUID
    let text: String
    let createdAt: Date
    let isMine: Bool
}
