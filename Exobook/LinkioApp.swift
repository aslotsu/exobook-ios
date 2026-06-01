//
//  LinkioApp.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.


import SwiftUI
import Supabase
import FirebaseCore
import FirebaseMessaging
import SwiftData

final class LinkioAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        Task { @MainActor in
            NotificationManager.shared.remoteNotificationsRegistered()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

@main
struct LinkioApp: App {
    @UIApplicationDelegateAdaptor(LinkioAppDelegate.self) private var appDelegate
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab: Int = 0
    @State private var navigationPath = NavigationPath()

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        print("✅ Firebase initialized")

        // Attach the Supabase Bearer token to every outgoing request.
        // Fast path: AuthenticationManager.currentSession is set during bootstrap
        // from the Keychain-persisted session — synchronous, never throws.
        // Fallback: ask the Supabase SDK directly (handles refresh).
        NetworkService.shared.authTokenProvider = {
            if let token = AuthenticationManager.shared.sessionAccessToken {
                return token
            }
            do {
                return try await supabase.auth.session.accessToken
            } catch {
                print("[auth] authTokenProvider: no valid session — \(error)")
                return nil
            }
        }

        // X-Authenticated-User-ID — required by backends that don't validate JWT directly.
        NetworkService.shared.userIdProvider = {
            AuthenticationManager.shared.currentUser?.id
                ?? AuthenticationManager.shared.currentSession?.user.id.uuidString.lowercased()
        }

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
