//
//  ChatsListView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI

struct ChatsListView: View {
    private enum ChatTab: String, CaseIterable, Identifiable {
        case directMessages = "DMs"
        case groups = "Groups"

        var id: String { rawValue }
    }

    @State private var chats: [ChatSummary] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var hasLoaded = false
    @State private var selectedTab: ChatTab = .directMessages
    let service: ChatService

    @State private var showingNewChat = false
    @State private var showingInviteInbox = false
    private let inviteStore = InviteStore.shared
    
    var body: some View {
        List {
            Picker("Chat type", selection: $selectedTab) {
                ForEach(ChatTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden)

            ForEach(visibleChats) { chat in
                NavigationLink(value: chat) {
                    ChatRow(chat: chat)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Chats")
        .navigationDestination(for: ChatSummary.self) { chat in
            ChatThreadView(chat: chat, service: service, currentUserId: service.currentUserId)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingInviteInbox = true }) {
                    Image(systemName: "envelope")
                        .overlay(alignment: .topTrailing) {
                            if inviteStore.unreadCount > 0 {
                                Text("\(inviteStore.unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewChat = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .fullScreenCover(isPresented: $showingNewChat) {
            NewChatView(service: service)
        }
        .sheet(isPresented: $showingInviteInbox) {
            InviteInboxView()
        }
        .refreshable {
            hasLoaded = false
            await load()
        }
        .task {
            guard !hasLoaded else { return }
            await load()
        }
        .overlay {
            if isLoading && chats.isEmpty {
                ProgressView()
            } else if let error, chats.isEmpty {
                VStack(spacing: 8) {
                    Text("Failed to load chats").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }.padding()
            } else if visibleChats.isEmpty && !isLoading {
                emptyState
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Chats Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingNewChat = true }) {
                Label("New Chat", systemImage: "square.and.pencil")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            chats = try await service.fetchChats()
            if selectedTab == .directMessages,
               chats.contains(where: \.isGroupChat),
               !chats.contains(where: \.isDirectMessage) {
                selectedTab = .groups
            }
            hasLoaded = true
            print("[Chats] loaded \(chats.count) chats")
        } catch {
            print("[Chats] ❌ fetchChats failed: \(error)")
            self.error = error.localizedDescription
        }
    }

    private var visibleChats: [ChatSummary] {
        switch selectedTab {
        case .directMessages:
            return chats.filter(\.isDirectMessage)
        case .groups:
            return chats.filter(\.isGroupChat)
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .directMessages:
            return "Start a conversation with someone!"
        case .groups:
            return "Join or create a group to see it here."
        }
    }
    
}

struct ChatRow: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 10) {
            Avatar(url: chat.avatarURL, title: chat.title)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if let lastTimestamp = chat.lastTimestamp {
                        Text(lastTimestamp, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(chat.lastMessage)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue))
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct Avatar: View {
    let url: URL?
    let title: String

    var body: some View {
        ZStack {
            if let url {
                ProfileImageView(imageURL: url, userName: title, size: 44)
            } else {
                Circle().fill(color(for: title))
                Text(initials(from: title))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func initials(from s: String) -> String {
        s.split(separator: " ").prefix(2).compactMap { $0.first?.uppercased() }.joined()
    }

    // Deterministic color from the title so the same chat always gets the same color.
    private func color(for s: String) -> Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo, .cyan]
        let hash = s.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}
