//
//  NotificationManager.swift
//  Exobook
//
//  Manages local and push notifications for the app
//

import Foundation
import UserNotifications
import UIKit
import Combine
import FirebaseMessaging

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var badgeCount: Int = 0

    private let notificationCenter = UNUserNotificationCenter.current()
    private var currentFCMUserId: String?
    private var hasAPNSToken = false
    private var isFetchingFCMToken = false

    // Navigation handler - will be set by app
    var onNotificationTap: ((NotificationType, String) -> Void)?

    private override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await notificationCenter.requestAuthorization(options: options)

        if granted {
            print("✅ Notification permission granted")
            await registerForRemoteNotifications()
        } else {
            print("❌ Notification permission denied")
        }

        await checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            authorizationStatus = settings.authorizationStatus
            print("📱 Notification authorization status: \(authorizationStatus.rawValue)")
        }
    }

    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Local Notifications

    func showNotification(
        title: String,
        body: String,
        type: NotificationType,
        resourceId: String,
        badge: Bool = true
    ) async {
        // Check if authorized
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("⚠️ Not authorized to show notifications")
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if badge {
            badgeCount += 1
            content.badge = NSNumber(value: badgeCount)
        }

        // Add user info for handling tap
        content.userInfo = [
            "type": type.rawValue,
            "resourceId": resourceId
        ]

        // Add category for actions
        content.categoryIdentifier = type.categoryIdentifier

        // Create request with unique identifier
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Show immediately
        )

        do {
            try await notificationCenter.add(request)
            print("✅ Notification added: \(title)")
        } catch {
            print("❌ Failed to add notification: \(error)")
        }
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        badgeCount = max(0, count)
        UIApplication.shared.applicationIconBadgeNumber = badgeCount
    }

    func incrementBadge() {
        badgeCount += 1
        UIApplication.shared.applicationIconBadgeNumber = badgeCount
    }

    func decrementBadge() {
        badgeCount = max(0, badgeCount - 1)
        UIApplication.shared.applicationIconBadgeNumber = badgeCount
    }

    func clearBadge() {
        badgeCount = 0
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // MARK: - Notification Management

    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        clearBadge()
    }

    func removePendingNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - FCM Token Management

    func setupFCM(userId: String) {
        Messaging.messaging().delegate = self
        currentFCMUserId = userId

        guard hasAPNSToken else {
            Task {
                await registerForRemoteNotifications()
            }
            print("ℹ️ Waiting for APNS token before fetching FCM token.")
            return
        }

        fetchAndRegisterFCMToken(userId: userId)
    }

    func remoteNotificationsRegistered() {
        hasAPNSToken = true

        guard let userId = currentFCMUserId else {
            print("✅ APNS token received; FCM registration will run after user loads.")
            return
        }

        fetchAndRegisterFCMToken(userId: userId)
    }

    private func fetchAndRegisterFCMToken(userId: String) {
        guard !isFetchingFCMToken else { return }
        isFetchingFCMToken = true

        Messaging.messaging().token { token, error in
            Task { @MainActor in
                self.isFetchingFCMToken = false

                if let error = error {
                    print("❌ Error fetching FCM token: \(error)")
                    return
                }

                guard let token else {
                    print("⚠️ FCM token fetch returned nil.")
                    return
                }

                print("✅ FCM token received: \(token)")
                if self.currentFCMUserId == userId {
                    await self.registerFCMToken(userId: userId, token: token)
                }
            }
        }
    }

    private func registerFCMToken(userId: String, token: String) async {
        let deviceInfo: [String: Any] = [
            "model": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]

        do {
            let api = LinkioAPIService()
            let response = try await api.registerDeviceToken(
                userId: userId,
                token: token,
                platform: "ios",
                deviceInfo: deviceInfo
            )
            print("✅ Device token registered successfully: \(response.message)")
        } catch {
            print("❌ Failed to register device token: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    // Called when notification is received while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("📬 Notification received in foreground: \(notification.request.content.title)")

        // Show banner, play sound, and update badge even when app is open
        return [.banner, .sound, .badge]
    }

    // Called when user taps on notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let resourceId = userInfo["resourceId"] as? String else {
            print("⚠️ Invalid notification data")
            return
        }

        print("👆 User tapped notification - Type: \(type), Resource: \(resourceId)")

        // Handle on main actor
        await MainActor.run {
            onNotificationTap?(type, resourceId)
        }
    }
}

// MARK: - Notification Types

enum NotificationType: String {
    case postLike = "post_like"
    case postComment = "post_comment"
    case commentLike = "comment_like"
    case commentReply = "comment_reply"
    case chatMessage = "chat_message"
    case mention = "mention"
    case follow = "follow"
    case announcement = "announcement"

    var categoryIdentifier: String {
        switch self {
        case .postLike: return "POST_LIKE_CATEGORY"
        case .postComment: return "POST_COMMENT_CATEGORY"
        case .commentLike: return "COMMENT_LIKE_CATEGORY"
        case .commentReply: return "COMMENT_REPLY_CATEGORY"
        case .chatMessage: return "CHAT_MESSAGE_CATEGORY"
        case .mention: return "MENTION_CATEGORY"
        case .follow: return "FOLLOW_CATEGORY"
        case .announcement: return "ANNOUNCEMENT_CATEGORY"
        }
    }
}

// MARK: - Notification Actions

extension NotificationManager {

    func setupNotificationCategories() async {
        // Define actions for different notification types

        // Chat message actions
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )

        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: []
        )

        let chatCategory = UNNotificationCategory(
            identifier: NotificationType.chatMessage.categoryIdentifier,
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            options: []
        )

        // Post like actions
        let viewPostAction = UNNotificationAction(
            identifier: "VIEW_POST_ACTION",
            title: "View Post",
            options: [.foreground]
        )

        let postLikeCategory = UNNotificationCategory(
            identifier: NotificationType.postLike.categoryIdentifier,
            actions: [viewPostAction],
            intentIdentifiers: [],
            options: []
        )

        // Comment actions
        let viewCommentAction = UNNotificationAction(
            identifier: "VIEW_COMMENT_ACTION",
            title: "View Comment",
            options: [.foreground]
        )

        let commentCategory = UNNotificationCategory(
            identifier: NotificationType.postComment.categoryIdentifier,
            actions: [viewCommentAction],
            intentIdentifiers: [],
            options: []
        )

        // Register all categories
        notificationCenter.setNotificationCategories([
            chatCategory,
            postLikeCategory,
            commentCategory
        ])

        print("✅ Notification categories configured")
    }
}

// MARK: - MessagingDelegate

extension NotificationManager: MessagingDelegate {

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM registration token refreshed: \(fcmToken ?? "nil")")

        // Token refresh - update backend with new token
        guard let fcmToken = fcmToken else { return }

        // Note: We need userId here. In a real app, you'd store this in UserDefaults or similar
        // For now, we'll just log it. The app will register the token on next login.
        print("ℹ️  FCM token refreshed. Will register on next app launch.")
    }
}
