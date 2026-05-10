//
//  NewChatView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    @State private var searchText = ""
    @State private var searchResults: [SearchHit] = []
    @State private var isSearching = false
    @State private var navigateToChatId: String?
    @State private var chatSummary: ChatSummary?
    
    let service: ChatService
    private let searchService = SearchService()
    private let chatAPI = ChatAPIService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by name or email", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // Results
                if isSearching {
                    ProgressView()
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No users found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(searchResults.filter { $0.document.isUserResult }) { hit in
                            Button(action: {
                                Task {
                                    await startChat(with: hit.document)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    // Avatar
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Text(hit.document.displayName.prefix(1).uppercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.blue)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hit.document.displayName)
                                            .font(.headline)
                                        
                                        if let bio = hit.document.displayBio, !bio.isEmpty {
                                            Text(bio)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $chatSummary) { summary in
                ChatThreadView(chat: summary, service: service, currentUserId: service.currentUserId)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let response = try await searchService.search(query: searchText)
                await MainActor.run {
                    searchResults = response.hits
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    print("Search error: \(error)")
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    @State private var isCreatingChat = false
    
    private func startChat(with document: SearchDocument) async {
        guard let currentUser = currentUser,
              let otherUserId = document.id as String? else { return }
        
        isCreatingChat = true
        
        do {
            // Step 1: Check if chat exists
            let chatExists = try await checkChatExists(user1: currentUser.id, user2: otherUserId)
            
            let chatId: String
            
            if chatExists {
                // Step 2a: Find existing chat ID
                if let existingChatId = try await findExistingChat(user1: currentUser.id, user2: otherUserId) {
                    print("✅ Found existing chat: \(existingChatId)")
                    chatId = existingChatId
                } else {
                    throw NSError(domain: "Chat", code: -1, userInfo: [NSLocalizedDescriptionKey: "Chat exists but ID not found"])
                }
            } else {
                // Step 2b: Create new chat
                chatId = try await createNewChat(
                    currentUser: currentUser,
                    otherUser: document
                )
                print("✅ Created new chat: \(chatId)")
            }
            
            // Step 3: Fetch chat details and navigate
            let (chat, members) = try await chatAPI.getChatWithMembers(chatId: chatId)
            let summary = ChatSummary(chat: chat, members: members, currentUserId: currentUser.id)
            
            await MainActor.run {
                self.chatSummary = summary
                self.navigateToChatId = chatId
            }
        } catch {
            print("❌ Failed to start chat: \(error)")
            isCreatingChat = false
        }
    }
    
    private func checkChatExists(user1: String, user2: String) async throws -> Bool {
        struct Response: Codable {
            let success: Bool
            let data: CheckData
        }
        struct CheckData: Codable {
            let hasDirectChat: Bool
            let user1Id: String?
            let user2Id: String?
            
           
        }
        
        let url = "\(APIConfig.chatAPI)/check-chat?user1=\(user1)&user2=\(user2)"
        let response: Response = try await NetworkService.shared.get(url)
        return response.data.hasDirectChat
    }
    
    private func findExistingChat(user1: String, user2: String) async throws -> String? {
        struct Response: Codable {
            let data: ChatData
        }
        struct ChatData: Codable {
            let chatId: String
            let found: Bool
        }
        
        let url = "\(APIConfig.chatAPI)/find-chat?user1=\(user1)&user2=\(user2)"
        let response: Response = try await NetworkService.shared.get(url)
        
        // Return nil if not found or chat_id is empty
        if !response.data.found || response.data.chatId.isEmpty {
            return nil
        }
        
        return response.data.chatId
    }
    
    private func createNewChat(currentUser: User, otherUser: SearchDocument) async throws -> String {
        struct CreateChatRequest: Encodable {
            let chat: ChatInfo
            let members: [Member]
            
            struct ChatInfo: Encodable {
                let id: String
                let password: String
                let headerImage: String
                let metadata: Metadata
            }
            
            struct Metadata: Encodable {
                let topic: String
                let createdBy: CreatedBy
                let isPrivate: Bool
            }
            
            struct CreatedBy: Encodable {
                let name: String
                let id: String
            }
            
            struct Member: Encodable {
                let userid: String
                let username: String
                let userbio: String
                let userpic: String
            }
        }
        
        // Generate UUID on client side
        let chatId = UUID().uuidString
        
        let request = CreateChatRequest(
            chat: CreateChatRequest.ChatInfo(
                id: chatId,
                password: "",
                headerImage: otherUser.picture ?? "",
                metadata: CreateChatRequest.Metadata(
                    topic: "",
                    createdBy: CreateChatRequest.CreatedBy(
                        name: currentUser.name,
                        id: currentUser.id
                    ),
                    isPrivate: true
                )
            ),
            members: [
                CreateChatRequest.Member(
                    userid: currentUser.id,
                    username: currentUser.name,
                    userbio: currentUser.bio ?? "",
                    userpic: currentUser.picture ?? ""
                ),
                CreateChatRequest.Member(
                    userid: otherUser.id,
                    username: otherUser.displayName,
                    userbio: otherUser.displayBio ?? "",
                    userpic: otherUser.picture ?? ""
                )
            ]
        )
        
        struct CreateChatResponse: Codable {
            let success: Bool
            let data: CreateChatData
            let message: String?
        }
        struct CreateChatData: Codable {
            let chat: Chat
            let members: [ChatMember]
        }
        
        let response: CreateChatResponse = try await NetworkService.shared.post(
            "\(APIConfig.chatAPI)/chats/with-members",
            body: request
        )
        
        // Return the chat ID generated by backend
        return response.data.chat.id
    }
}
