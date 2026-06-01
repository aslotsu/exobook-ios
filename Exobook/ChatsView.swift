//
//  ChatsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct ChatsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var chatService: ChatService?
    
    var body: some View {
        Group {
            if let chatService = chatService {
                ChatsListView(service: chatService)
            } else if let user = currentUser {
                Color.clear.onAppear {
                    initializeChatService(for: user)
                }
            } else {
                Text("User not found")
            }
        }
    }
    
    private func initializeChatService(for user: User) {
        chatService = LinkioChatService(currentUserId: user.id)
    }
}
