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
            ChatThreadView(chat: chat, service: service)
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay {
            if isLoading && chats.isEmpty { ProgressView() }
            if let error, chats.isEmpty {
                VStack(spacing: 8) {
                    Text("Failed to load chats").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
        }
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
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.15)
                }
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
