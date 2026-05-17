//
//  Chat.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

// MARK: - Chat

struct Chat: Decodable {
    let id: String
    let lastMessage: String?
    let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case lastMessageTimestamp = "last_message_timestamp"
        case timestamp
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage)

        if let millis = try? container.decode(Int64.self, forKey: .lastMessageTimestamp) {
            lastMessageAt = Self.dateFromEpoch(millis)
        } else if let millis = try? container.decode(Int64.self, forKey: .timestamp) {
            lastMessageAt = Self.dateFromEpoch(millis)
        } else if let iso = try? container.decode(String.self, forKey: .lastMessageAt),
                  let date = Self.dateFromISO8601(iso) {
            lastMessageAt = date
        } else if let iso = try? container.decode(String.self, forKey: .updatedAt),
                  let date = Self.dateFromISO8601(iso) {
            lastMessageAt = date
        } else if let iso = try? container.decode(String.self, forKey: .createdAt),
                  let date = Self.dateFromISO8601(iso) {
            lastMessageAt = date
        } else {
            lastMessageAt = nil
        }
    }

    private static func dateFromEpoch(_ epoch: Int64) -> Date {
        // Accept either milliseconds or seconds.
        if epoch > 10_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(epoch) / 1000.0)
        }
        return Date(timeIntervalSince1970: TimeInterval(epoch))
    }

    private static func dateFromISO8601(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return fallback.date(from: value)
    }
}

struct ChatMember: Codable, Identifiable, Hashable {
    let userId: String
    let username: String
    let userBio: String?
    let userPic: String?

    var id: String { userId }

    var avatarURL: URL? {
        resolveAvatarURL(userPic)
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
