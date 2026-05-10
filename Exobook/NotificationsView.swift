//
//  NotificationsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

import SwiftData

struct NotificationsView: View {
    @Environment(\.currentUser) private var currentUser
    
    // Sort by timestamp descending to show newest first
    @Query(sort: \CachedNotification.timestamp, order: .reverse) private var notifications: [CachedNotification]
    @State private var navigationManager = NotificationNavigationManager.shared
    
    var body: some View {
        Group {
            if notifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !notifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: markAllAsRead) {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Mark all as read")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func markAllAsRead() {
        if let userId = currentUser?.id {
            // StatsCacheManager.shared.markAllNotificationsAsRead(forUserId: userId)
             // Or iterate if helper not available yet, but we added it
             StatsCacheManager.shared.markAllNotificationsAsRead(forUserId: userId)
        }
    }
    
    private func handleNotificationTap(_ notification: CachedNotification) {
        // Mark as opened
        StatsCacheManager.shared.markNotificationAsOpened(id: notification.id)
        
        // Handle navigation
        guard let type = NotificationType(rawValue: notification.typeRawValue) else { return }
        
        print("🔔 Tapped notification: \(type), Resource: \(notification.resourceId)")
        
        switch type {
        case .postLike, .postComment, .commentLike, .commentReply:
            navigationManager.navigateToPost(postId: notification.resourceId)
        case .chatMessage:
            navigationManager.navigateToChat(chatId: notification.resourceId)
        case .mention, .follow, .announcement:
             // Already here
             break
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We'll notify you when something arrives!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Notifications List
    
    private var notificationsList: some View {
        List {
            ForEach(notifications) { notification in
                Button(action: { handleNotificationTap(notification) }) {
                   NotificationRow(notification: notification)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    if !notification.isRead {
                        Button("Read") {
                            StatsCacheManager.shared.markNotificationAsRead(id: notification.id)
                        }
                        .tint(.blue)
                    }
                    Button("Delete", role: .destructive) {
                         // Add delete support if needed, requires context access
                         // For now just hide or implementation detail
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: CachedNotification
    
    // Helper to map string type to enum for styling
    var type: NotificationType {
        NotificationType(rawValue: notification.typeRawValue) ?? .announcement
    }
    
    var icon: String {
        switch type {
        case .postLike, .commentLike: return "heart.fill"
        case .postComment, .commentReply: return "bubble.left.fill"
        case .follow: return "person.fill.badge.plus"
        case .mention: return "at"
        case .chatMessage: return "message.fill"
        case .announcement: return "megaphone.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .postLike, .commentLike: return .red
        case .postComment, .commentReply: return .blue
        case .follow: return .green
        case .mention: return .orange
        case .chatMessage: return .pink
        case .announcement: return .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 18))
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(notification.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary) + Text(" ago")
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            // Unread indicator dot
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(notification.isOpened ? Color.clear : (notification.isRead ? Color.clear : Color.blue.opacity(0.03)))
        .contentShape(Rectangle()) // Make entire row tappable
    }
}

#Preview {
    NotificationsView()
        .modelContainer(for: CachedNotification.self, inMemory: true)
}
