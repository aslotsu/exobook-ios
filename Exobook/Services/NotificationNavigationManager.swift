//
//  NotificationNavigationManager.swift
//  Exobook
//
//  Created by Alfred Lotsu
//

import SwiftUI
import Combine

/// Manages navigation triggered by notification taps
@MainActor
@Observable
class NotificationNavigationManager {
    static let shared = NotificationNavigationManager()

    // Navigation state
    var pendingNavigation: NavigationDestination?
    var selectedTab: ExoTab = .feed

    // Published for SwiftUI observation
    private var navigationSubject = PassthroughSubject<NavigationDestination, Never>()

    private init() {}

    /// Request navigation to a specific destination (called when notification is tapped)
    func navigateTo(_ destination: NavigationDestination) {
        print("📍 Navigation requested: \(destination)")
        pendingNavigation = destination

        // Switch to appropriate tab based on destination
        switch destination {
        case .post:
            selectedTab = .feed
        case .chat:
            selectedTab = .chats
        case .profile:
            selectedTab = .profile
        case .notifications:
            selectedTab = .feed   // notifications shown via bell in feed top bar
        }
    }

    /// Clear pending navigation after it's been handled
    func clearNavigation() {
        pendingNavigation = nil
    }

    /// Navigate to a post by ID
    func navigateToPost(postId: String) {
        navigateTo(.post(id: postId))
    }

    /// Navigate to a chat by ID
    func navigateToChat(chatId: String) {
        navigateTo(.chat(id: chatId))
    }

    /// Navigate to a user profile
    func navigateToProfile(userId: String) {
        navigateTo(.profile(id: userId))
    }

    /// Navigate to notifications tab
    func navigateToNotifications() {
        navigateTo(.notifications)
    }
}

// MARK: - Navigation Destination

enum NavigationDestination: Equatable {
    case post(id: String)
    case chat(id: String)
    case profile(id: String)
    case notifications

    var description: String {
        switch self {
        case .post(let id): return "Post(\(id))"
        case .chat(let id): return "Chat(\(id))"
        case .profile(let id): return "Profile(\(id))"
        case .notifications: return "Notifications"
        }
    }
}
