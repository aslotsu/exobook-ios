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
        case id = "chat_id"
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
        if pic.starts(with: "http") {
            return URL(string: pic)
        }
        if pic.starts(with: "/") {
            return URL(string: "https://linkio.ca\(pic)")
        }
        return URL(string: "https://exobook.s3.amazonaws.com/\(pic)")
    }
    
    // KEEP this - needed because API uses "userid" not "user_id"
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
    }
}


