//
//  InviteInboxView.swift
//

import SwiftUI

struct InviteInboxView: View {
    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss
    private let store = InviteStore.shared
    private let inviteAPI = ChatInviteAPIService()

    @State private var actionError: String?
    @State private var inProgressIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if store.pendingInvites.isEmpty {
                    ContentUnavailableView(
                        "No Invites",
                        systemImage: "envelope",
                        description: Text("You have no pending chat invites.")
                    )
                } else {
                    List {
                        if let err = actionError {
                            Section {
                                Text(err).font(.caption).foregroundStyle(.red)
                            }
                        }
                        ForEach(store.pendingInvites) { invite in
                            InviteRow(
                                invite: invite,
                                isLoading: inProgressIds.contains(invite.chatId),
                                onAccept: { Task { await accept(invite) } },
                                onDecline: { Task { await decline(invite) } }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Chat Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func accept(_ invite: ChatInviteEvent) async {
        guard let user = currentUser else { return }
        inProgressIds.insert(invite.chatId)
        actionError = nil
        defer { inProgressIds.remove(invite.chatId) }

        let member = ChatMember(
            userId: user.id, username: user.name,
            userBio: user.bio, userPic: user.picture
        )
        do {
            try await inviteAPI.acceptInvite(chatId: invite.chatId, user: member)
            store.remove(chatId: invite.chatId)
        } catch {
            actionError = "Failed to accept invite: \(error.localizedDescription)"
        }
    }

    private func decline(_ invite: ChatInviteEvent) async {
        guard let user = currentUser else { return }
        inProgressIds.insert(invite.chatId)
        actionError = nil
        defer { inProgressIds.remove(invite.chatId) }

        let member = ChatMember(
            userId: user.id, username: user.name,
            userBio: user.bio, userPic: user.picture
        )
        do {
            try await inviteAPI.rejectInvite(chatId: invite.chatId, user: member)
            store.remove(chatId: invite.chatId)
        } catch {
            actionError = "Failed to decline invite: \(error.localizedDescription)"
        }
    }
}

// MARK: - Invite Row

private struct InviteRow: View {
    let invite: ChatInviteEvent
    let isLoading: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.chatName ?? "Chat Invite")
                        .font(.headline)
                    Text("\(invite.inviterName) invited you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    Button(action: onDecline) {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    Button(action: onAccept) {
                        Text("Accept")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
