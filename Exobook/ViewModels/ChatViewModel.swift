import Foundation
import SwiftUI
import Observation
import PhotosUI

struct AttachedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let data: Data
}

@MainActor
@Observable
class ChatViewModel {
    // Dependencies
    private let chatService: ChatService
    private let chatId: String
    private let api = ExobookAPIService()
    let currentUserId: String

    // State
    var messages: [Message] = []
    var input: String = ""
    var isLoading = false
    var error: String?
    
    // Attachments
    var selectedItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var selectedFiles: [AttachedFile] = []
    var isUploading = false
    
    // Designated Initializer
    init(chatId: String, currentUserId: String, chatService: ChatService) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatService = chatService
    }
    
    // Convenience Initializer
    convenience init(chat: ChatSummary, currentUserId: String) {
        let service = ExobookChatService(currentUserId: currentUserId)
        self.init(chatId: chat.id, currentUserId: currentUserId, chatService: service)
    }
    
    // MARK: - Actions
    
    func loadMessages() async {
        isLoading = true
        error = nil
        
        do {
            let fetched = try await chatService.fetchMessages(chatId: chatId)
            self.messages = fetched.sorted { $0.createdAt < $1.createdAt }
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to load messages: \(error)")
        }
        
        isLoading = false
    }
    
    func sendMessage() async {
        let textToSend = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow sending if there are attachments, even if text is empty
        guard !textToSend.isEmpty || !selectedImages.isEmpty || !selectedFiles.isEmpty else { return }
        guard !isUploading else { return }
        
        isUploading = true
        
        // Optimistic update (Text only, attachments harder to optimistically render without local IDs logic)
        // We'll just show text for now in optimistic
        if !textToSend.isEmpty {
            let optimisticMessage = Message(
                id: UUID().uuidString,
                chatId: chatId,
                senderId: currentUserId,
                text: textToSend,
                createdAt: Date(),
                isMine: true,
                images: nil,
                files: nil
            )
            await appendMessage(optimisticMessage)
        }
        // Clear input immediately
        input = ""
        
        do {
            var imageIds: [String] = []
            var fileIds: [String] = []
            
            // 1. Upload Images
            if !selectedImages.isEmpty {
                let imagesData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                if !imagesData.isEmpty {
                    imageIds = try await api.uploadImages(imagesData)
                }
            }
            
            // 2. Upload Files
            if !selectedFiles.isEmpty {
                let uploadableFiles = selectedFiles.map { (data: $0.data, filename: $0.name, mimeType: "application/pdf") }
                // Note: assuming PDF/doc for now, or could detect mime type from ext
                if !uploadableFiles.isEmpty {
                    fileIds = try await api.uploadFiles(uploadableFiles)
                }
            }
            
            // 3. Send Message
            try await chatService.sendMessage(
                chatId: chatId,
                text: textToSend,
                images: imageIds,
                files: fileIds
            )
            
            // Clear attachments
            selectedImages = []
            selectedItems = []
            selectedFiles = []
            
        } catch {
            self.error = "Failed to send message: \(error.localizedDescription)"
            print("❌ Failed to send message: \(error)")
        }
        
        isUploading = false
    }
    
    func subscribeToRealtimeUpdates() async {
        do {
            try await chatService.subscribeToMessages(chatId: chatId) { [weak self] newMessage in
                Task { @MainActor [weak self] in
                    await self?.appendMessage(newMessage)
                }
            }
        } catch {
            print("❌ Failed to subscribe to chat: \(error)")
        }
    }
    
    func unsubscribe() {
        chatService.unsubscribe(chatId: chatId)
    }
    
    func appendMessage(_ message: Message) async {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            // Check if existing is missing attachments/content and update?
            // Usually we just replace.
            messages[index] = message
        } else {
             messages.append(message)
        }
    }
}
