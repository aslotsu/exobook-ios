//
//  ChatsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct ChatsView: View {
    @State private var chatService: ChatService = MockChatService()
    @State private var serviceMode: ServiceMode = .mock
    
    enum ServiceMode: String, CaseIterable {
        case mock = "Mock"
        case supabase = "Supabase"
        case dynamoDB = "DynamoDB"
    }
    
    var body: some View {
        NavigationStack {
            ChatsListView(service: chatService)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu(serviceMode.rawValue) {
                            ForEach(ServiceMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue) {
                                    switchService(to: mode)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
        }
    }
    
    private func switchService(to mode: ServiceMode) {
        serviceMode = mode
        switch mode {
        case .mock:
            chatService = MockChatService()
        case .supabase:
            chatService = SupabaseChatService()
        case .dynamoDB:
            chatService = DynamoDBChatService()
        }
    }
}
