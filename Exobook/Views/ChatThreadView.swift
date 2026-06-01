//
//  ChatThreadView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SDWebImageSwiftUI
import Combine

struct UUIDWrapper: Identifiable {
    let id: String
}

struct ChatThreadView: View {
    let chat: ChatSummary
    @State private var viewModel: ChatViewModel
    @State private var typingCancellable: AnyCancellable?

    @State private var keyboardPadding: CGFloat = 0
    @State private var selectedProfileId: String?
    @State private var isImporterPresented = false
    @State private var showingMembers = false

    init(chat: ChatSummary, service: ChatService, currentUserId: String) {
        self.chat = chat
        self._viewModel = State(initialValue: ChatViewModel(chatId: chat.id, currentUserId: currentUserId, chatService: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatThreadHeader(
                chat: chat,
                currentUserId: viewModel.currentUserId,
                onProfile: { member in selectedProfileId = member.userId },
                onMembers: { showingMembers = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appBackground)

            Divider()

            MessageList(
                messages: viewModel.messages,
                currentUserId: viewModel.currentUserId,
                isLoadingOlder: viewModel.isLoadingOlder,
                hasMore: viewModel.hasMoreMessages,
                onLoadOlder: { Task { await viewModel.loadOlderMessages() } },
                onEdit: { viewModel.beginEdit($0) },
                onDelete: { msg in Task { await viewModel.deleteMessage(msg) } }
            )

            if !viewModel.typingUsers.isEmpty {
                TypingIndicatorView()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Divider()
            attachmentPreview

            if viewModel.editingMessage != nil {
                editBanner
            }

            inputBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
        }
        .background(Color.appBackground)
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { Task { await listenKeyboard() } }
        .task {
            await viewModel.loadMessages()
            await viewModel.subscribeToRealtimeUpdates()
            subscribeTyping()
        }
        .onDisappear { viewModel.unsubscribe(); typingCancellable?.cancel() }
        .overlay {
            if viewModel.isLoading && viewModel.messages.isEmpty { ProgressView() }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: keyboardPadding) }
        .sheet(item: profileBinding) { wrapper in
            NavigationStack { UserProfileView(userId: wrapper.id) }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.content], onCompletion: handleFileImport)
        .onChange(of: viewModel.selectedItems, initial: false, handlePhotoSelection)
        .animation(.easeInOut(duration: 0.2), value: viewModel.typingUsers.isEmpty)
        .sheet(isPresented: $showingMembers) {
            ChatMembersView(members: chat.members, currentUserId: viewModel.currentUserId)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if chat.members.count == 2,
                   let other = chat.members.first(where: { $0.userId != viewModel.currentUserId }) {
                    Button { selectedProfileId = other.userId } label: {
                        Label("View Profile", systemImage: "person.circle")
                    }
                } else {
                    Button { showingMembers = true } label: {
                        Label("Members (\(chat.members.count))", systemImage: "person.2")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var profileBinding: Binding<UUIDWrapper?> {
        Binding(get: { selectedProfileId.map(UUIDWrapper.init) }, set: { _ in selectedProfileId = nil })
    }

    // MARK: - Typing subscription

    private func subscribeTyping() {
        typingCancellable = RealtimeManager.shared
            .typingPublisher(chatId: chat.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak viewModel] event in
                viewModel?.handleTypingEvent(userId: event.userId, isTyping: event.isTyping)
            }
    }

    // MARK: - Edit banner

    private var editBanner: some View {
        HStack {
            Image(systemName: "pencil")
                .foregroundStyle(.blue)
            Text("Editing message")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { viewModel.cancelEdit() }
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    // MARK: - Attachments

    @ViewBuilder
    private var attachmentPreview: some View {
        if !viewModel.selectedImages.isEmpty || !viewModel.selectedFiles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.selectedImages.count, id: \.self) { i in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.selectedImages[i])
                                .resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button { viewModel.selectedImages.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.5))
                            }.padding(2)
                        }
                    }
                    ForEach(viewModel.selectedFiles) { file in
                        ZStack(alignment: .topTrailing) {
                            VStack {
                                Image(systemName: "doc.fill").font(.title2)
                                Text(file.name).font(.caption2).lineLimit(1).frame(width: 50)
                            }
                            .frame(width: 60, height: 60)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(8)
                            Button {
                                viewModel.selectedFiles.removeAll { $0.id == file.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.5))
                            }.padding(2)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $viewModel.selectedItems, matching: .images) {
                Image(systemName: "photo").font(.system(size: 20)).foregroundColor(.secondary)
            }
            Button { isImporterPresented = true } label: {
                Image(systemName: "paperclip").font(.system(size: 20)).foregroundColor(.secondary)
            }

            TextField(viewModel.editingMessage != nil ? "Edit message…" : "Message", text: $viewModel.input)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemGray6)))
                .font(.system(size: 15))
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.sendMessage() } }
                .onChange(of: viewModel.input) { viewModel.handleInputChange() }

            Button { Task { await viewModel.sendMessage() } } label: {
                ZStack {
                    Circle().fill(sendButtonBackground).frame(width: 32, height: 32)
                    if viewModel.isUploading {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: viewModel.editingMessage != nil ? "checkmark" : "arrow.up")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
            .disabled((viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        viewModel.selectedImages.isEmpty && viewModel.selectedFiles.isEmpty) || viewModel.isUploading)
        }
    }

    private var sendButtonBackground: some ShapeStyle {
        let empty = viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && viewModel.selectedImages.isEmpty && viewModel.selectedFiles.isEmpty
        return empty
            ? AnyShapeStyle(Color(.systemGray4))
            : AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
            viewModel.selectedFiles.append(AttachedFile(url: url, name: url.lastPathComponent, data: data))
        }
    }

    private func handlePhotoSelection(_ old: [PhotosPickerItem], _ new: [PhotosPickerItem]) {
        Task {
            viewModel.selectedImages = await withTaskGroup(of: UIImage?.self) { group in
                for item in new { group.addTask { try? await item.loadTransferable(type: Data.self).flatMap(UIImage.init) } }
                return await group.reduce(into: []) { if let img = $1 { $0.append(img) } }
            }
        }
    }

    private func listenKeyboard() async {
        for await notif in NotificationCenter.default.notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
            guard let userInfo = notif.userInfo,
                  let end = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { continue }
            let safeBottom = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.bottom ?? 0
            let padding = max(0, UIScreen.main.bounds.height - end.origin.y - safeBottom)
            withAnimation(.easeOut(duration: 0.2)) { keyboardPadding = padding }
        }
    }
}

private struct ChatThreadHeader: View {
    let chat: ChatSummary
    let currentUserId: String
    let onProfile: (ChatMember) -> Void
    let onMembers: () -> Void

    private var otherMember: ChatMember? {
        chat.members.first { $0.userId != currentUserId }
    }

    private var subtitle: String {
        if chat.isDirectMessage, let otherMember {
            let bio = otherMember.userBio?.trimmingCharacters(in: .whitespacesAndNewlines)
            return bio?.isEmpty == false ? bio! : "Direct message"
        }

        let count = chat.members.count
        return "\(count) member\(count == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfileImageView(imageURL: chat.avatarURL, userName: chat.title, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if chat.isDirectMessage, let otherMember {
                Button {
                    onProfile(otherMember)
                } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("View \(otherMember.username)'s profile")
            } else {
                Button {
                    onMembers()
                } label: {
                    Label("Members", systemImage: "person.2")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("View chat members")
            }
        }
    }
}

// MARK: - MessageList

private struct MessageList: View {
    let messages: [Message]
    let currentUserId: String
    let isLoadingOlder: Bool
    let hasMore: Bool
    let onLoadOlder: () -> Void
    let onEdit: (Message) -> Void
    let onDelete: (Message) -> Void

    @State private var isNearBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Load-older trigger at the top
                        if hasMore {
                            Button {
                                onLoadOlder()
                            } label: {
                                if isLoadingOlder {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Text("Load earlier messages")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        ForEach(messages) { msg in
                            MessageBubble(message: msg,
                                          onEdit: msg.isMine ? { onEdit(msg) } : nil,
                                          onDelete: msg.isMine ? { onDelete(msg) } : nil)
                                .id(msg.id)
                                .padding(.horizontal, 14)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Color.clear.frame(height: 1).id("bottom")
                            .onAppear { isNearBottom = true }
                            .onDisappear { isNearBottom = false }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    if isNearBottom { scrollToBottom(proxy: proxy, animated: true) }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }

                if !isNearBottom {
                    ScrollToBottomButton { scrollToBottom(proxy: proxy, animated: true) }
                        .padding(.trailing, 16).padding(.bottom, 16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { proxy.scrollTo(last.id, anchor: .bottom) }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .offset(y: phase == i ? -4 : 0)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { phase = 1 }
    }
}

// MARK: - Scroll-to-bottom button

private struct ScrollToBottomButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1).frame(width: 44, height: 44)
                Image(systemName: "arrow.down").font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: Message
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if let images = message.images, !images.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                        ForEach(images, id: \.self) { imageId in
                            WebImage(url: resolveMediaURL(imageId))
                                .resizable().indicator(.activity).scaledToFill()
                                .frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: 220)
                }

                if let files = message.files, !files.isEmpty {
                    ForEach(files, id: \.self) { fileId in
                        Link(destination: resolveMediaURL(fileId) ?? URL(string: "https://linkio.ca")!) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("Attachment").font(.caption).lineLimit(1)
                            }
                            .padding(8).background(Color.secondary.opacity(0.1)).cornerRadius(8)
                        }
                    }
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .padding(12)
                        .background(message.isMine ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contextMenu {
                            if let onEdit {
                                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                            }
                            if let onDelete {
                                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                }

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 6)
            }
            if !message.isMine { Spacer(minLength: 40) }
        }
    }
}
