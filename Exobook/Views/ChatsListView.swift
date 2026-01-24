//
//  ChatsListView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI

struct ChatsListView: View {
    @State private var chats: [ChatSummary] = []
    @State private var isLoading = false
    @State private var error: String?
    let service: ChatService

    @State private var showingNewChat = false
    
    var body: some View {
        List {
            ForEach(chats) { chat in
                NavigationLink(value: chat) {
                    ChatRow(chat: chat)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(adaptiveBackground)
        .navigationTitle("Chats")
        .navigationDestination(for: ChatSummary.self) { chat in
            ChatThreadView(chat: chat, service: service, currentUserId: service.currentUserId)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewChat = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .fullScreenCover(isPresented: $showingNewChat) {
            NewChatView(service: service)
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay {
            if isLoading && chats.isEmpty {
                ProgressView()
            } else if chats.isEmpty && !isLoading {
                emptyState
            } else if let error, chats.isEmpty {
                VStack(spacing: 8) {
                    Text("Failed to load chats").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }.padding()
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
            
            Text("Start a conversation with someone!")
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
        defer { isLoading = false }
        do {
            chats = try await service.fetchChats()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
}

struct ChatRow: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: chat.avatarURL, title: chat.title)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(chat.title).font(.headline)
                    Spacer()
                    Text(chat.lastTimestamp, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.lastMessage)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct Avatar: View {
    let url: URL?
    let title: String

    var body: some View {
        ZStack {
            if let url {
                // Use our improved ProfileImageView with SVG detection
                ProfileImageView(imageURL: url, userName: title, size: 48)
            } else {
                Color.secondary.opacity(0.15)
                Text(initials(from: title)).font(.headline)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private func initials(from s: String) -> String {
        let comps = s.split(separator: " ")
        let letters = comps.prefix(2).compactMap { $0.first?.uppercased() }
        return letters.joined()
    }
}
