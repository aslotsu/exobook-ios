//
//  SearchView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 25/01/2026.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    @StateObject private var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    
    init(user: User?) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(userId: user?.id ?? ""))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                Divider()
                
                // Tab Picker
                if !viewModel.searchText.isEmpty {
                    Picker("Search Tab", selection: $viewModel.selectedTab) {
                        ForEach(SearchViewModel.SearchTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Content based on state
                if viewModel.searchText.isEmpty {
                    // Recent searches or suggestions
                    recentSearchesView
                } else if viewModel.isSearching {
                    // Loading state
                    loadingView
                } else if viewModel.foundCount == 0 {
                    // Empty state
                    emptyStateView
                } else {
                    // Results
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search posts...", text: $viewModel.searchText)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit {
                    Task {
                        await viewModel.performSearch()
                    }
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Recent Searches
    
    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.recentSearches.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.recentSearches, id: \.self) { search in
                                Button(action: {
                                    viewModel.searchText = search
                                    Task {
                                        await viewModel.performSearch()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                        
                                        Text(search)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            viewModel.removeRecentSearch(search)
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                viewModel.clearRecentSearches()
                            }
                            .font(.subheadline)
                        }
                    }
                }
                
                // Suggested searches
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(suggestedSearches, id: \.self) { suggestion in
                            Button(action: {
                                viewModel.searchText = suggestion
                                Task {
                                    await viewModel.performSearch()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Suggested")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var suggestedSearches: [String] {
        [
            "study groups",
            "textbooks for sale",
            "exam tips",
            "project partners",
            "tutoring"
        ]
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try searching for something else")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Determine which sections to show based on tab
                let showPosts = viewModel.selectedTab == .all || viewModel.selectedTab == .posts
                let showUsers = viewModel.selectedTab == .all || viewModel.selectedTab == .users
                
                // Users Section
                if showUsers && !viewModel.userResults.isEmpty {
                    if viewModel.selectedTab == .all {
                        Text("Users")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    ForEach(viewModel.userResults) { doc in
                        NavigationLink(destination: UserProfileView(userId: doc.id)) {
                            TypesenseUserResultCard(document: doc, searchQuery: viewModel.searchText)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                    
                    if viewModel.selectedTab == .all && showPosts && !viewModel.postResults.isEmpty {
                        Divider().padding(.vertical, 8)
                    }
                }
                
                // Posts Section
                if showPosts && !viewModel.postResults.isEmpty {
                    if viewModel.selectedTab == .all {
                        Text("Posts")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    
                    ForEach(viewModel.postResults) { doc in
                        if let post = createPost(from: doc) {
                            NavigationLink(destination: PostDetailView(post: post)) {
                                TypesenseSearchResultCard(
                                    document: doc,
                                    currentUserId: currentUser?.id ?? "",
                                    searchQuery: viewModel.searchText
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // Helper to create Post from TypesensePostDocument  
    private func createPost(from doc: TypesensePostDocument) -> Post? {
        guard let createdTimestamp = doc.createdAt,
              let updatedTimestamp = doc.updatedAt else {
            return nil
        }
        
        let created = Date(timeIntervalSince1970: TimeInterval(createdTimestamp))
        let updated = Date(timeIntervalSince1970: TimeInterval(updatedTimestamp))
        
        let jsonDict: [String: Any] = [
            "id": doc.id,
            "user_id": doc.userId,
            "username": doc.username,
            "user_name": doc.userName ?? doc.username,
            "user_bio": doc.userBio,
            "user_campus": doc.userCampus,
            "user_programme": doc.userProgramme,
            "user_year": doc.userYear,
            "user_picture": doc.userPicture,
            "title": doc.title,
            "content": doc.content,
            "subject": doc.subject,
            "images": doc.images ?? [],
            "likes": [],
            "comments": [],
            "created_at": ISO8601DateFormatter().string(from: created),
            "updated_at": ISO8601DateFormatter().string(from: updated)
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Post.self, from: jsonData)
    }
}

// MARK: - Typesense Search Result Card

struct TypesenseSearchResultCard: View {
    let document: TypesensePostDocument
    let currentUserId: String
    let searchQuery: String
    
    private let realtimeManager = RealtimeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ProfileImageView(
                    imageURL: userAvatarURL,
                    userName: document.userName ?? document.username,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.userName ?? document.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 6) {
                        Text(document.subject)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if let timestamp = document.createdAt {
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Text(Date(timeIntervalSince1970: TimeInterval(timestamp)), style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if !document.title.isEmpty {
                    Text(highlightedText(document.title))
                        .font(.headline)
                        .lineLimit(2)
                }
                
                Text(highlightedText(document.content.htmlStripped))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Stats
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.caption)
                    Text("\(realtimeManager.getLikeCount(for: document.id))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                    Text("\(realtimeManager.getCommentCount(for: document.id))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var userAvatarURL: URL? {
        let picture = document.userPicture
        if picture.lowercased().hasSuffix(".svg") {
            return nil
        }
        if picture.starts(with: "http") {
            return URL(string: picture)
        }
        if picture.starts(with: "/") {
            return URL(string: "https://exobook.ca\(picture)")
        }
        return URL(string: "https://exobook.s3.amazonaws.com/\(picture)")
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        // Simple highlighting
        if let range = attributed.range(of: searchQuery, options: [.caseInsensitive]) {
            attributed[range].foregroundColor = .blue
            attributed[range].font = .headline
        }
        
        return attributed
    }
}

#Preview {
    SearchView(user: .mock)
}

// MARK: - Typesense User Result Card

struct TypesenseUserResultCard: View {
    let document: TypesenseUserDocument
    let searchQuery: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ProfileImageView(
                imageURL: avatarURL,
                userName: document.username ?? document.name,
                size: 50
            )
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedText(document.username ?? document.name))
                    .font(.headline)
                
                if let bio = document.bio {
                    Text(highlightedText(bio))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    if let campus = document.campus {
                        Text(campus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let program = document.program {
                        if document.campus != nil {
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        Text(program)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var avatarURL: URL? {
        // Handle avatar URL similarly to SearchResultCard
        let picture = document.picture ?? ""
        if picture.isEmpty { return nil }
        
        if picture.lowercased().hasSuffix(".svg") { return nil }
        
        if picture.starts(with: "http") {
            return URL(string: picture)
        }
        if picture.starts(with: "/") {
            return URL(string: "https://exobook.ca\(picture)")
        }
        return URL(string: "https://exobook.s3.amazonaws.com/\(picture)")
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        if let range = attributed.range(of: searchQuery, options: [.caseInsensitive]) {
            attributed[range].foregroundColor = .blue
            attributed[range].font = .headline
        }
        
        return attributed
    }
}
