//
//  InviteUserView.swift
//  Invite another user into an existing chat.
//

import SwiftUI

struct InviteUserView: View {
    let chatId: String
    let chatTitle: String
    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [SearchHit] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var sentIds: Set<String> = []
    @State private var error: String?

    private let searchService = SearchService()
    private let inviteAPI = ChatInviteAPIService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding()

                if let err = error {
                    Text(err).font(.caption).foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if isSearching {
                    ProgressView().padding()
                } else if results.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(results.filter { $0.document.isUserResult }) { hit in
                            UserInviteRow(
                                hit: hit,
                                alreadySent: sentIds.contains(hit.document.id),
                                onInvite: { Task { await sendInvite(to: hit) } }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
                Spacer()
            }
            .navigationTitle("Invite to Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search by name…", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { performSearch() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func performSearch() {
        searchTask?.cancel()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { results = []; isSearching = false; return }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if let resp = try? await searchService.search(query: q) {
                await MainActor.run { results = resp.hits; isSearching = false }
            } else {
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func sendInvite(to hit: SearchHit) async {
        guard let currentUser else { return }
        error = nil
        do {
            try await inviteAPI.sendInvite(
                chatId: chatId,
                senderId: currentUser.id,
                recipientId: hit.document.id,
                inviterName: currentUser.name,
                chatName: chatTitle
            )
            sentIds.insert(hit.document.id)
        } catch {
            self.error = "Failed to send invite: \(error.localizedDescription)"
        }
    }
}

// MARK: - Row

private struct UserInviteRow: View {
    let hit: SearchHit
    let alreadySent: Bool
    let onInvite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(hit.document.displayName.prefix(1).uppercased())
                        .font(.headline).foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(hit.document.displayName).font(.headline)
                if let bio = hit.document.displayBio, !bio.isEmpty {
                    Text(bio).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if alreadySent {
                Label("Invited", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Button("Invite", action: onInvite)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
