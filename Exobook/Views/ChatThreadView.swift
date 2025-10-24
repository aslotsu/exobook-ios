//
//  ChatThreadView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI

struct ChatThreadView: View {
    let chat: ChatSummary
    let service: ChatService

    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var keyboardPadding: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            MessageList(messages: messages)
            Divider()
            inputBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
        .background(adaptiveBackground)
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await listenKeyboard()
            }
        }
        .task {
            await load()
            try? await service.subscribeToMessages(chatId: chat.id) { new in
                Task { await appendMessage(new) }
            }
        }
        .onDisappear {
            service.unsubscribe(chatId: chat.id)
        }
        .overlay {
            if isLoading && messages.isEmpty { ProgressView() }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: keyboardPadding) }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .tint(.blue)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await service.fetchMessages(chatId: chat.id).sorted { $0.createdAt < $1.createdAt }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        try? await service.sendMessage(chatId: chat.id, text: text)
    }

    @MainActor
    private func appendMessage(_ message: Message) {
        messages.append(message)
    }

    private func listenKeyboard() async {
        // Simple keyboard padding using publishers
        for await notif in NotificationCenter.default.notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
            guard
                let userInfo = notif.userInfo,
                let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { continue }
            let height = UIScreen.main.bounds.height
            let safeAreaBottom = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets.bottom ?? 0
            let padding = max(0, height - endFrame.origin.y - safeAreaBottom)
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardPadding = padding
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
}

private struct MessageList: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(message.isMine ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            if !message.isMine { Spacer(minLength: 40) }
        }
    }
}
