//
//  JoinRequestsView.swift
//  For chat admins/creators to review and approve pending join requests.
//

import SwiftUI

struct JoinRequestsView: View {
    let chatId: String
    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss

    private let inviteAPI = ChatInviteAPIService()
    private let mainAPI = LinkioAPIService()

    @State private var requestorIds: [String] = []
    @State private var requestors: [String: User] = [:]   // userId → User
    @State private var isLoading = false
    @State private var approvedIds: Set<String> = []
    @State private var inProgressIds: Set<String> = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && requestorIds.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requestorIds.isEmpty {
                    ContentUnavailableView(
                        "No Pending Requests",
                        systemImage: "person.badge.clock",
                        description: Text("No one has requested to join this chat.")
                    )
                } else {
                    List {
                        if let err = error {
                            Section { Text(err).font(.caption).foregroundStyle(.red) }
                        }
                        Section("\(requestorIds.count) pending") {
                            ForEach(requestorIds, id: \.self) { userId in
                                RequestRow(
                                    userId: userId,
                                    user: requestors[userId],
                                    isApproved: approvedIds.contains(userId),
                                    isLoading: inProgressIds.contains(userId),
                                    onApprove: { Task { await approve(userId: userId) } }
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Join Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isLoading { ProgressView() }
                }
            }
            .task { await loadRequests() }
            .refreshable { await loadRequests() }
        }
    }

    private func loadRequests() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            requestorIds = try await inviteAPI.getJoinRequests(chatId: chatId)
            // Fetch each user's profile concurrently (ignoring individual failures)
            await withTaskGroup(of: (String, User?).self) { group in
                for uid in requestorIds {
                    group.addTask { (uid, try? await mainAPI.getUser(id: uid)) }
                }
                for await (uid, user) in group {
                    if let user { requestors[uid] = user }
                }
            }
        } catch {
            self.error = "Failed to load requests: \(error.localizedDescription)"
        }
    }

    private func approve(userId: String) async {
        inProgressIds.insert(userId)
        error = nil
        defer { inProgressIds.remove(userId) }

        let user = requestors[userId]
        let member = ChatMember(
            userId: userId,
            username: user?.name ?? userId,
            userBio: user?.bio,
            userPic: user?.picture
        )
        do {
            try await inviteAPI.approveRequest(chatId: chatId, requester: member)
            approvedIds.insert(userId)
            requestorIds.removeAll { $0 == userId }
        } catch {
            self.error = "Failed to approve: \(error.localizedDescription)"
        }
    }
}

// MARK: - Row

private struct RequestRow: View {
    let userId: String
    let user: User?
    let isApproved: Bool
    let isLoading: Bool
    let onApprove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Text((user?.name ?? userId).prefix(1).uppercased())
                        .font(.headline).foregroundStyle(.purple)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.name ?? userId).font(.headline)
                if let bio = user?.bio, !bio.isEmpty {
                    Text(bio).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else if isApproved {
                Label("Approved", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Button("Approve", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
