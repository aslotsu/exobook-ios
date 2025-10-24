//
//  NotificationsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [NotificationItem] = []
    
    var body: some View {
        Group {
            if notifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .background(adaptiveBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications) { notification in
                    NotificationRow(notification: notification)
                    Divider()
                }
            }
        }
    }
}

// MARK: - Models

struct NotificationItem: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let isRead: Bool
    let actionUserId: String?
    let actionUserName: String?
    let postId: String?
    
    enum NotificationType {
        case like
        case comment
        case follow
        case mention
        case announcement
    }
    
    var icon: String {
        switch type {
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .follow: return "person.fill.badge.plus"
        case .mention: return "at"
        case .announcement: return "megaphone.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .like: return .red
        case .comment: return .blue
        case .follow: return .green
        case .mention: return .orange
        case .announcement: return .purple
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: NotificationItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(notification.iconColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: notification.icon)
                        .foregroundColor(notification.iconColor)
                        .font(.system(size: 18))
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(notification.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(notification.isRead ? Color.clear : Color.blue.opacity(0.05))
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
