//
//  InviteStore.swift
//
//  Singleton that holds pending chat invites received via Pusher.
//  Views observe this directly; RealtimeManager feeds it.
//

import Foundation
import Observation

@MainActor
@Observable
final class InviteStore {
    static let shared = InviteStore()
    private init() {}

    var pendingInvites: [ChatInviteEvent] = []
    var unreadCount: Int { pendingInvites.count }

    func add(_ invite: ChatInviteEvent) {
        guard !pendingInvites.contains(where: { $0.chatId == invite.chatId }) else { return }
        pendingInvites.append(invite)
    }

    func remove(chatId: String) {
        pendingInvites.removeAll { $0.chatId == chatId }
    }
}
