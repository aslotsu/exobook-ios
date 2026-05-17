//
//  FriendsListView.swift
//  Exobook
//
//  Created by GPT-5.3-Codex on 10/05/2026.
//

import SwiftUI

@MainActor
struct FriendsListView: View {
    @Environment(\.currentUser) private var currentUser

    private let friendsAPI = FriendsAPIService()
    private let exobookAPI = ExobookAPIService()

    @State private var friends: [Friend] = []
    @State private var userProfiles: [String: User] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var inFlightRemovals: Set<String> = []

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section("All Friends") {
                if friends.isEmpty && !isLoading {
                    VStack(spacing: 6) {
                        Text("No friends yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("When you connect with people, they’ll show up here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else {
                    ForEach(friends) { friend in
                        NavigationLink(destination: UserProfileView(userId: friend.id)) {
                            HStack(spacing: 12) {
                                ProfileImageView(
                                    imageURL: userProfiles[friend.id]?.avatarURL,
                                    userName: userProfiles[friend.id]?.name ?? friend.id,
                                    size: 40
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(userProfiles[friend.id]?.displayName ?? friend.id)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(userProfiles[friend.id]?.username.map { "@\($0)" } ?? friend.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(formattedAddedAt(friend.addedAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Remove", role: .destructive) {
                                Task { await removeFriend(friend.id) }
                            }
                            .disabled(inFlightRemovals.contains(friend.id))
                        }
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFriends()
        }
        .refreshable {
            await loadFriends()
        }
    }

    private func loadFriends() async {
        guard let userId = currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await friendsAPI.getFriends(userId: userId)
            friends = response.friends
            await loadUserProfiles(for: response.friends.map(\.id))
        } catch {
            errorMessage = "Failed to load friends."
        }
    }

    private func removeFriend(_ friendId: String) async {
        guard let userId = currentUser?.id else { return }
        inFlightRemovals.insert(friendId)
        defer { inFlightRemovals.remove(friendId) }

        do {
            _ = try await friendsAPI.removeFriend(userId: userId, friendId: friendId)
            friends.removeAll { $0.id == friendId }
            userProfiles[friendId] = nil
        } catch {
            errorMessage = "Failed to remove friend."
        }
    }

    private func loadUserProfiles(for userIds: [String]) async {
        let uniqueIds = Array(Set(userIds))
        var nextProfiles = userProfiles

        for userId in uniqueIds where nextProfiles[userId] == nil {
            if let user = try? await exobookAPI.getUser(id: userId) {
                nextProfiles[userId] = user
            }
        }

        userProfiles = nextProfiles
    }

    private func formattedAddedAt(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return raw
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
