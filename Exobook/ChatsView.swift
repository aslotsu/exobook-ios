//
//  ChatsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct ChatsView: View {
    @State private var chatService: ChatService = MockChatService()
    @State private var useRealService = false
    
    var body: some View {
        NavigationStack {
            ChatsListView(service: chatService)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(useRealService ? "Mock" : "Live") {
                            chatService = useRealService ? MockChatService() : SupabaseChatService()
                            useRealService.toggle()
                        }
                        .font(.caption)
                    }
                }
        }
    }
}
