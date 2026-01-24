//
//  Chat.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

// MARK: - Chat

struct Chat: Codable {
    let id: String
    let lastMessage: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case lastMessage = "last_message"
    }
}

struct ChatMember: Codable, Identifiable, Hashable {
    let userId: String
    let username: String
    let userBio: String?
    let userPic: String?

    var id: String { userId }

    var avatarURL: URL? {
        guard let pic = userPic else { return nil }
        
        // If userPic is an SVG file, return nil to trigger CloudFront fallback
        if pic.lowercased().hasSuffix(".svg") {
            return nil
        }
        
        if pic.starts(with: "http") {
            return URL(string: pic)
        }
        if pic.starts(with: "/") {
            return URL(string: "https://exobook.ca\(pic)")
        }
        return URL(string: "https://exobook.amazonaws.com/\(pic)")
    }

    // API uses "userid" not "user_id" (lowercase, not snake_case)
    enum CodingKeys: String, CodingKey {
        case userId = "userid"
        case username
        case userBio = "userbio"
        case userPic = "userpic"
    }
}

// MARK: - Member


// MARK: - MembersList

struct MembersList: Codable {
    let chatId: String
    let members: [ChatMember]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case members
        case count
    }
}

// MARK: - Message

struct ChatMessage: Codable, Identifiable {
    let chatId: String
    let messageId: String
    let timestamp: Int64
    let userId: String
    let words: String
    let images: [String]?
    let files: [String]?
    let createdAt: String?  // Backend sends this as string (duplicate of timestamp)

    var id: String { messageId }
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case messageId = "message_id"
        case timestamp
        case userId = "user_id"
        case words
        case images
        case files
        case createdAt = "created_at"
    }
}



