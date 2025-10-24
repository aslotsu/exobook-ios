//
//  MainTabs.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

enum ExoTab: Int, CaseIterable {
    case feed, explore, notifications, chats, profile
}

struct MainTabs: View {
    @State private var selection: ExoTab = .feed
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        TabView(selection: $selection) {
            FeedView()
                .embedInNav(title: "Feed")
                .tabItem { Label("Feed", systemImage: "house") }
                .tag(ExoTab.feed)

            ExploreView()
                .embedInNav(title: "Explore")
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(ExoTab.explore)
            
            NotificationsView()
                .embedInNav(title: "Notifications")
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(ExoTab.notifications)

            ChatsView()
                .embedInNav(title: "Chats")
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .tag(ExoTab.chats)

            ProfileView()
                .embedInNav(title: "Profile")
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(ExoTab.profile)
        }
        .tint(.blue) // Exobook blue for selected tab items
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 40
                    // Use predicted end to feel more natural
                    let drag = value.predictedEndTranslation.width

                    if drag < -threshold { moveTab(+1) }   // swipe left → next tab
                    if drag >  threshold { moveTab(-1) }   // swipe right → previous tab
                }
        )
    }

    private func moveTab(_ direction: Int) {
        guard let current = ExoTab.allCases.firstIndex(of: selection) else { return }
        let newIndex = max(0, min(ExoTab.allCases.count - 1, current + direction))
        guard newIndex != current else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            selection = ExoTab.allCases[newIndex]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Per-tab NavigationStacks
private extension View {
    func embedInNav(title: String) -> some View {
        NavigationStack {
            self
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}


#Preview {
    MainTabs()
}
