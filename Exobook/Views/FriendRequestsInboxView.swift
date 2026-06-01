//
//  FriendRequestsInboxView.swift
//  Exobook
//
//  Created by GPT-5.3-Codex on 10/05/2026.
//

import SwiftUI

@MainActor
struct FriendRequestsInboxView: View {
    @Environment(\.currentUser) private var currentUser

    private let friendsAPI = FriendsAPIService()
    private let linkioAPI = LinkioAPIService()

    @State private var pendingRequests: [FriendRequest] = []
    @State private var userProfiles: [String: User] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var inFlightActions: Set<String> = []

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section("Pending Requests") {
                if pendingRequests.isEmpty && !isLoading {
                    VStack(spacing: 6) {
                        Text("No pending requests")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("You’re all caught up.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else {
                    ForEach(pendingRequests) { request in
                        pendingRequestRow(request)
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Friend Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    @ViewBuilder
    private func pendingRequestRow(_ request: FriendRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProfileImageView(
                    imageURL: userProfiles[request.fromId]?.avatarURL,
                    userName: userProfiles[request.fromId]?.name ?? request.fromId,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(userProfiles[request.fromId]?.displayName ?? request.fromId)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(userProfiles[request.fromId]?.username.map { "@\($0)" } ?? request.fromId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Button("Accept") {
                    Task {
                        await respondToRequest(request, decision: .accepted)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionInFlight("respond-\(request.id)"))

                Button("Decline") {
                    Task {
                        await respondToRequest(request, decision: .declined)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isActionInFlight("respond-\(request.id)"))
            }
        }
        .padding(.vertical, 4)
    }

    private func loadData() async {
        guard let userId = currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pending = try await friendsAPI.getPendingRequests(userId: userId)
            pendingRequests = pending.requests
            await loadUserProfiles(for: pending.requests.map(\.fromId))
        } catch {
            errorMessage = "Failed to load friends data."
        }
    }

    private func respondToRequest(_ request: FriendRequest, decision: FriendRequestDecision) async {
        guard let currentUser else { return }
        let actionKey = "respond-\(request.id)"
        inFlightActions.insert(actionKey)
        defer { inFlightActions.remove(actionKey) }

        do {
            _ = try await friendsAPI.respondToRequest(
                fromId: request.fromId,
                toId: currentUser.id,
                status: decision
            )
            pendingRequests.removeAll { $0.id == request.id }
            if pendingRequests.allSatisfy({ $0.fromId != request.fromId }) {
                userProfiles[request.fromId] = nil
            }
        } catch {
            errorMessage = "Failed to update friend request."
        }
    }

    private func isActionInFlight(_ key: String) -> Bool {
        inFlightActions.contains(key)
    }

    private func loadUserProfiles(for userIds: [String]) async {
        let uniqueIds = Array(Set(userIds))
        var nextProfiles = userProfiles

        for userId in uniqueIds where nextProfiles[userId] == nil {
            if let user = try? await linkioAPI.getUser(id: userId) {
                nextProfiles[userId] = user
            }
        }

        userProfiles = nextProfiles
    }
}
