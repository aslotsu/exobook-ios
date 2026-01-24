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

struct UUIDWrapper: Identifiable {
    let id: String
}

struct ChatThreadView: View {
    let chat: ChatSummary
    @State private var viewModel: ChatViewModel
    
    // UI-specific state
    @State private var keyboardPadding: CGFloat = 0
    @State private var selectedProfileId: String?
    @State private var isImporterPresented = false

    init(chat: ChatSummary, service: ChatService, currentUserId: String) {
        self.chat = chat
        self._viewModel = State(initialValue: ChatViewModel(chatId: chat.id, currentUserId: currentUserId, chatService: service))
    }

    var body: some View {
        let mainStack = VStack(spacing: 0) {
            MessageList(messages: viewModel.messages)
            Divider()
            attachmentPreview
            inputBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
        }
        
        return mainStack
            .background(adaptiveBackground)
            .navigationTitle(chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { Task { await listenKeyboard() } }
            .task {
                await viewModel.loadMessages()
                await viewModel.subscribeToRealtimeUpdates()
            }
            .onDisappear { viewModel.unsubscribe() }
            .overlay {
                if viewModel.isLoading && viewModel.messages.isEmpty { 
                    ProgressView() 
                }
            }
            .safeAreaInset(edge: .bottom) { 
                Color.clear.frame(height: keyboardPadding) 
            }
            .sheet(item: profileBinding) { wrapper in
                NavigationStack {
                    UserProfileView(userId: wrapper.id)
                }
            }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.content], onCompletion: handleFileImport)
            .onChange(of: viewModel.selectedItems, initial: false, handlePhotoSelection)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if let otherUser = chat.members.first(where: { $0.userId != viewModel.currentUserId }) {
                Button("View Profile") {
                    selectedProfileId = otherUser.userId
                }
            }
        }
    }
    
    private var profileBinding: Binding<UUIDWrapper?> {
        Binding(
            get: { selectedProfileId != nil ? UUIDWrapper(id: selectedProfileId!) : nil },
            set: { _ in selectedProfileId = nil }
        )
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                let file = AttachedFile(url: url, name: url.lastPathComponent, data: data)
                viewModel.selectedFiles.append(file)
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
    
    private func handlePhotoSelection(_ oldItems: [PhotosPickerItem], _ newItems: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            viewModel.selectedImages = images
        }
    }
    
    @ViewBuilder
    private var attachmentPreview: some View {
        if !viewModel.selectedImages.isEmpty || !viewModel.selectedFiles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.selectedImages.count, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button {
                                viewModel.selectedImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.5))
                            }
                            .padding(2)
                        }
                    }
                    
                    ForEach(viewModel.selectedFiles) { file in
                        ZStack(alignment: .topTrailing) {
                            VStack {
                                Image(systemName: "doc.fill")
                                    .font(.title2)
                                Text(file.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .frame(width: 50)
                            }
                            .frame(width: 60, height: 60)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button {
                                if let index = viewModel.selectedFiles.firstIndex(where: { $0.id == file.id }) {
                                    viewModel.selectedFiles.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.5))
                            }
                            .padding(2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Photos Picker
            PhotosPicker(selection: $viewModel.selectedItems, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            
            // File Picker
            Button {
                isImporterPresented = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            
            // Text input
            TextField("Message", text: $viewModel.input)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .font(.system(size: 15))
                .submitLabel(.send)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

            // Send button
            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(sendButtonBackground)
                        .frame(width: 32, height: 32)
                    
                    if viewModel.isUploading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled((viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.selectedImages.isEmpty && viewModel.selectedFiles.isEmpty) || viewModel.isUploading)
        }
    }

    private var sendButtonBackground: some ShapeStyle {
        if viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.selectedImages.isEmpty && viewModel.selectedFiles.isEmpty {
            return AnyShapeStyle(Color(.systemGray4))
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func listenKeyboard() async {
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
    @State private var isNearBottom = true
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                                .padding(.horizontal, 14)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear { isNearBottom = true }
                            .onDisappear { isNearBottom = false }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    if isNearBottom {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }

                if !isNearBottom {
                    ScrollToBottomButton {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

private struct ScrollToBottomButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                // Images
                if let images = message.images, !images.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                        ForEach(images, id: \.self) { imageId in
                            let urlString = imageId.hasPrefix("http") ? imageId : "https://exobook.s3.amazonaws.com/\(imageId)"
                            WebImage(url: URL(string: urlString))
                                .resizable()
                                .indicator(.activity)
                                .scaledToFill()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: 220)
                }
                
                // Files
                if let files = message.files, !files.isEmpty {
                    ForEach(files, id: \.self) { fileId in
                        let urlString = fileId.hasPrefix("http") ? fileId : "https://exobook.s3.amazonaws.com/\(fileId)"
                         Link(destination: URL(string: urlString) ?? URL(string: "https://exobook.ca")!) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("Attachment")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .padding(12)
                        .background(message.isMine ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            if !message.isMine { Spacer(minLength: 40) }
        }
    }
}
