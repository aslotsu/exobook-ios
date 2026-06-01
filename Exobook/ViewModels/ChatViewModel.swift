import Foundation
import SwiftUI
import Observation
import PhotosUI
import os

struct AttachedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let data: Data
}

@MainActor
@Observable
class ChatViewModel {
    private let chatService: ChatService
    private let chatId: String
    private let api = LinkioAPIService()
    private let readStateStore = ChatReadStateStore.shared
    private let unreadAPI = UnreadAPIService()
    let currentUserId: String

    // Messages & pagination
    var messages: [Message] = []
    var hasMoreMessages = false
    var isLoadingOlder = false

    // Compose
    var input: String = ""
    var isLoading = false
    var error: String?

    // Attachments
    var selectedItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var selectedFiles: [AttachedFile] = []
    var isUploading = false

    // Typing
    var typingUsers: [String] = []
    private var typingTask: Task<Void, Never>?
    private var isTyping = false

    // Edit
    var editingMessage: Message? = nil

    init(chatId: String, currentUserId: String, chatService: ChatService) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatService = chatService
    }

    convenience init(chat: ChatSummary, currentUserId: String) {
        let service = LinkioChatService(currentUserId: currentUserId)
        self.init(chatId: chat.id, currentUserId: currentUserId, chatService: service)
    }

    // MARK: - Load messages

    func loadMessages() async {
        isLoading = true
        error = nil
        do {
            let (fetched, more) = try await chatService.fetchMessages(chatId: chatId)
            messages = fetched.sorted { $0.createdAt < $1.createdAt }
            hasMoreMessages = more
            await syncReadState()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadOlderMessages() async {
        guard !isLoadingOlder, hasMoreMessages, let oldest = messages.first else { return }
        isLoadingOlder = true
        do {
            let (older, more) = try await chatService.fetchOlderMessages(chatId: chatId, before: oldest.createdAt, limit: 50)
            let sorted = older.sorted { $0.createdAt < $1.createdAt }
            messages.insert(contentsOf: sorted, at: 0)
            hasMoreMessages = more
        } catch {
            Log.chat.error("Failed to load older messages: \(error)")
        }
        isLoadingOlder = false
    }

    // MARK: - Read state

    private func syncReadState() async {
        guard let lastMessage = messages.last else { return }
        readStateStore.markRead(chatId: chatId, userId: currentUserId, at: lastMessage.createdAt)
        try? await unreadAPI.markRead(userId: currentUserId, chatId: chatId, messageId: lastMessage.id)
    }

    // MARK: - Send

    func sendMessage() async {
        if let editing = editingMessage {
            await commitEdit(editing)
            return
        }

        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty || !selectedFiles.isEmpty else { return }
        guard !isUploading else { return }

        isUploading = true
        stopTyping()

        if !text.isEmpty {
            let optimistic = Message(id: UUID().uuidString, chatId: chatId, senderId: currentUserId,
                                     text: text, createdAt: Date(), isMine: true, images: nil, files: nil)
            await appendMessage(optimistic)
        }
        input = ""

        do {
            var imageIds: [String] = []
            var fileIds: [String] = []
            if !selectedImages.isEmpty {
                let data = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                imageIds = try await api.uploadImages(data)
            }
            if !selectedFiles.isEmpty {
                let uploadable = selectedFiles.map { (data: $0.data, filename: $0.name, mimeType: "application/pdf") }
                fileIds = try await api.uploadFiles(uploadable)
            }
            try await chatService.sendMessage(chatId: chatId, text: text, images: imageIds, files: fileIds)
            selectedImages = []; selectedItems = []; selectedFiles = []
        } catch {
            self.error = "Failed to send: \(error.localizedDescription)"
        }

        isUploading = false
    }

    // MARK: - Edit

    func beginEdit(_ message: Message) {
        editingMessage = message
        input = message.text
    }

    func cancelEdit() {
        editingMessage = nil
        input = ""
    }

    private func commitEdit(_ message: Message) async {
        let newText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else { cancelEdit(); return }
        editingMessage = nil
        input = ""
        do {
            try await chatService.editMessage(chatId: chatId, messageId: message.id, newText: newText)
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                let updated = Message(id: message.id, chatId: message.chatId, senderId: message.senderId,
                                      text: newText, createdAt: message.createdAt, isMine: message.isMine,
                                      images: message.images, files: message.files)
                messages[idx] = updated
            }
        } catch {
            self.error = "Failed to edit: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    func deleteMessage(_ message: Message) async {
        do {
            try await chatService.deleteMessage(chatId: chatId, messageId: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {
            self.error = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Typing

    func handleInputChange() {
        guard !input.isEmpty else {
            stopTyping()
            return
        }
        startTyping()
    }

    private func startTyping() {
        typingTask?.cancel()
        if !isTyping {
            isTyping = true
            Task { await postTypingEvent("user_typing") }
        }
        typingTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { await MainActor.run { self.stopTyping() } }
        }
    }

    func stopTyping() {
        typingTask?.cancel()
        typingTask = nil
        guard isTyping else { return }
        isTyping = false
        Task { await postTypingEvent("user_stop_typing") }
    }

    private func postTypingEvent(_ type: String) async {
        struct Body: Encodable {
            let type: String
            let chatId: String
            let userId: String
            enum CodingKeys: String, CodingKey {
                case type
                case chatId = "chat_id"
                case userId = "user_id"
            }
        }
        struct Resp: Decodable { let message: String? }
        _ = try? await NetworkService.shared.post(
            "\(APIConfig.chatAPI)/realtime",
            body: Body(type: type, chatId: chatId, userId: currentUserId)
        ) as Resp
    }

    // MARK: - Realtime

    func subscribeToRealtimeUpdates() async {
        do {
            try await chatService.subscribeToMessages(chatId: chatId) { [weak self] msg in
                Task { @MainActor [weak self] in await self?.appendMessage(msg) }
            }
        } catch {
            Log.chat.error("Failed to subscribe to chat: \(error)")
        }
    }

    func subscribeToTyping() {
        // RealtimeManager publishes typing events on the same chat-{chatId} channel.
        // We handle them via a dedicated publisher added below.
    }

    func unsubscribe() {
        stopTyping()
        chatService.unsubscribe(chatId: chatId)
    }

    func appendMessage(_ message: Message) async {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        if !message.isMine {
            readStateStore.markRead(chatId: chatId, userId: currentUserId, at: message.createdAt)
            try? await unreadAPI.markRead(userId: currentUserId, chatId: chatId, messageId: message.id)
        }
    }

    func handleTypingEvent(userId: String, isTyping: Bool) {
        if isTyping {
            if !typingUsers.contains(userId) { typingUsers.append(userId) }
        } else {
            typingUsers.removeAll { $0 == userId }
        }
    }
}
