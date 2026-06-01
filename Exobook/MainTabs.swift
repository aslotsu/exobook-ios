//
//  MainTabs.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI
import Combine

enum ExoTab: Int, CaseIterable {
    case feed, groups, meetings, chats, profile
}

struct MainTabs: View {
    @State private var selection: ExoTab = .feed
    @GestureState private var dragOffset: CGFloat = 0
    @State private var navigationManager = NotificationNavigationManager.shared
    @Environment(\.currentUser) private var currentUser

    // Navigation paths for each tab
    @State private var feedPath = NavigationPath()
    @State private var groupsPath = NavigationPath()
    @State private var meetingsPath = NavigationPath()
    @State private var chatsPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    // Post loading state
    @State private var isLoadingPost = false
    @State private var loadedPost: Post?

    // Real-time events
    @State private var hasConfiguredRealtime = false

    // Notifications bell badge
    @State private var unreadNotifCount: Int = 0
    @State private var notifSubscription: AnyCancellable?
    private let notifAPI = NotificationsAPIService()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $feedPath) {
                FeedView()
                    .navigationTitle("Feed")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: Post.self) { post in
                        PostDetailView(post: post)
                    }
            }
            .tabItem { Label("Feed", systemImage: "house") }
            .tag(ExoTab.feed)

            GroupsView()
                .embedInNav(title: "Groups", path: $groupsPath)
                .tabItem { Label("Groups", systemImage: "person.3") }
                .tag(ExoTab.groups)

            MeetingsView()
                .embedInNav(title: "Meetings", path: $meetingsPath)
                .tabItem { Label("Meetings", systemImage: "calendar") }
                .tag(ExoTab.meetings)

            ChatsView()
                .embedInNav(title: "Chats", path: $chatsPath)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .tag(ExoTab.chats)

            ProfileView()
                .embedInNav(title: "Profile", path: $profilePath)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(ExoTab.profile)
        }
        .tint(.blue)
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 40
                    let drag = value.predictedEndTranslation.width

                    if drag < -threshold { moveTab(+1) }
                    if drag >  threshold { moveTab(-1) }
                }
        )
        .onChange(of: navigationManager.pendingNavigation) { oldValue, newValue in
            handlePendingNavigation(newValue)
        }
        .onChange(of: navigationManager.selectedTab) { oldValue, newValue in
            selection = newValue
        }
        .onChange(of: selection) { _, _ in }
        .onAppear {
            configureRealtimeIfNeeded()
        }
        .task(id: currentUser?.id) {
            await refreshUnreadCount()
            subscribeToNotificationEvents()
        }
        .overlay {
            if isLoadingPost {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading post...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .systemBackground))
                    )
                }
            }
        }
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

    
    // MARK: - Navigation Handling

    private func handlePendingNavigation(_ destination: NavigationDestination?) {
        guard let destination = destination else { return }

        print("🧭 Handling navigation to: \(destination.description)")

        switch destination {
        case .post(let postId):
            navigateToPost(postId)
        case .chat(let chatId):
            // TODO: Implement chat navigation
            print("📱 Chat navigation not yet implemented: \(chatId)")
            navigationManager.clearNavigation()
        case .profile(let userId):
            // TODO: Implement profile navigation
            print("📱 Profile navigation not yet implemented: \(userId)")
            navigationManager.clearNavigation()
        case .notifications:
            // Notifications are now shown in the feed top bar
            selection = .feed
            navigationManager.clearNavigation()
        }
    }

    private func navigateToPost(_ postId: String) {
        guard let userId = currentUser?.id else {
            print("❌ No current user")
            navigationManager.clearNavigation()
            return
        }

        Task {
            isLoadingPost = true

            do {
                let api = LinkioAPIService()
                let post = try await api.getPost(id: postId)

                // Wait a brief moment to ensure tab switch completes
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Navigate on feed tab
                feedPath.append(post)

                print("✅ Navigated to post: \(postId)")
                navigationManager.clearNavigation()
            } catch {
                print("❌ Failed to load post \(postId): \(error)")
                navigationManager.clearNavigation()
            }

            isLoadingPost = false
        }
    }

    // MARK: - Notifications bell badge

    private func refreshUnreadCount() async {
        guard let userId = currentUser?.id else {
            unreadNotifCount = 0
            return
        }
        if let count = try? await notifAPI.fetchUnreadCount(userId: userId) {
            unreadNotifCount = count
        }
    }

    private func subscribeToNotificationEvents() {
        guard notifSubscription == nil else { return }
        notifSubscription = RealtimeManager.shared.newNotificationSubject
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task { @MainActor in
                    await refreshUnreadCount()
                }
            }
    }

    // MARK: - Real-time Configuration

    private func configureRealtimeIfNeeded() {
        guard !hasConfiguredRealtime, let userId = currentUser?.id else { return }

        hasConfiguredRealtime = true

        // Configure Pusher with credentials from APIConfig
        RealtimeManager.shared.configure(
            pusherKey: APIConfig.pusherKey,
            cluster: APIConfig.pusherCluster,
            userId: userId
        )

        print("✅ Real-time events configured for user: \(userId)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("🔍 DIAGNOSTIC: Pusher status check at 3 seconds")
                // This will show in Xcode console if Pusher is connected
            }
    }
}

// MARK: - Per-tab NavigationStacks
private extension View {
    func embedInNav(title: String, path: Binding<NavigationPath>) -> some View {
        NavigationStack(path: path) {
            self
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabs()
}
