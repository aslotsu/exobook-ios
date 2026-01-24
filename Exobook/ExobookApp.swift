//
//  ExobookApp.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.


import SwiftUI
import Supabase
import FirebaseCore
import SwiftData

@main
struct ExobookApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab: Int = 0
    @State private var navigationPath = NavigationPath()

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        print("✅ Firebase initialized")

        // Configure notification categories
        Task {
            await NotificationManager.shared.setupNotificationCategories()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .onOpenURL { url in
                    Task {
                        do { try await supabase.auth.session(from: url) }
                        catch { print("Deep link error:", error) }
                    }
                }
                .onAppear {
                    setupNotificationHandling()
                }
                .environmentObject(notificationManager)
                .modelContainer(StatsCacheManager.shared.modelContainer)
        }
    }

    private func setupNotificationHandling() {
        // Request notification permissions
        Task {
            do {
                try await NotificationManager.shared.requestAuthorization()
                print("✅ Notification permissions configured")
            } catch {
                print("❌ Failed to request notification permissions: \(error)")
            }
        }

        // Handle notification taps
        NotificationManager.shared.onNotificationTap = { type, resourceId in
            handleNotificationTap(type: type, resourceId: resourceId)
        }
    }

    private func handleNotificationTap(type: NotificationType, resourceId: String) {
        print("🔔 Handling notification tap - Type: \(type), Resource: \(resourceId)")

        let navigationManager = NotificationNavigationManager.shared

        // Navigate based on notification type
        switch type {
        case .postLike, .postComment, .commentLike, .commentReply:
            // Navigate to post detail
            navigationManager.navigateToPost(postId: resourceId)
            print("✅ Initiated navigation to post: \(resourceId)")

        case .chatMessage:
            // Navigate to chat thread
            navigationManager.navigateToChat(chatId: resourceId)
            print("✅ Initiated navigation to chat: \(resourceId)")

        case .mention, .follow, .announcement:
            // Navigate to notifications tab to see details
            navigationManager.navigateToNotifications()
            print("✅ Navigated to notifications tab")
        }

        // Clear badge when user interacts with notification
        NotificationManager.shared.decrementBadge()
    }
}
