//
//  CachedNotification.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import SwiftData

@Model
final class CachedNotification {
    @Attribute(.unique) var id: String
    var typeRawValue: String
    var title: String
    var message: String
    var timestamp: Date
    var resourceId: String // ID of post, comment, etc.
    var userId: String?     // Current user ID (owner of this notification)
    
    // Status
    var isRead: Bool    // Has been seen in the list
    var isOpened: Bool  // Has been tapped/interacted with
    
    // Additional metadata for display
    var actionUserId: String?
    var actionUserName: String?
    var actionUserPicture: String?

    /// DynamoDB sort key for the notif row. Required for server mark-read / delete.
    /// Nil for FCM-only entries that haven't been merged with a server fetch yet.
    var actionKey: String?

    init(
        id: String = UUID().uuidString,
        type: String, // Store raw string from NotificationType
        title: String,
        message: String,
        timestamp: Date = Date(),
        resourceId: String,
        userId: String?,
        isRead: Bool = false,
        isOpened: Bool = false,
        actionUserId: String? = nil,
        actionUserName: String? = nil,
        actionUserPicture: String? = nil,
        actionKey: String? = nil
    ) {
        self.id = id
        self.typeRawValue = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.resourceId = resourceId
        self.userId = userId
        self.isRead = isRead
        self.isOpened = isOpened
        self.actionUserId = actionUserId
        self.actionUserName = actionUserName
        self.actionUserPicture = actionUserPicture
        self.actionKey = actionKey
    }
}
