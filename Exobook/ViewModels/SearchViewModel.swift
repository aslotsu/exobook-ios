//
//  SearchViewModel.swift
//  Exobook
//
//  Created by Alfred Lotsu on 25/01/2026.
//

import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    private let linkioAPI = LinkioAPIService()
    private let realtimeManager = RealtimeManager.shared
    
    // State
    @Published var searchText: String = "" {
        didSet {
            // Trigger search after a small delay (debounce)
            searchTask?.cancel()
            if !searchText.isEmpty && searchText.count >= 2 {
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await performSearch()
                }
            } else if searchText.isEmpty {
                clearResults()
            }
        }
    }
    
    @Published var selectedTab: SearchTab = .all
    @Published var postResults: [TypesensePostDocument] = []
    @Published var userResults: [TypesenseUserDocument] = []
    @Published var isSearching = false
    
    @Published var postsFoundCount = 0
    @Published var usersFoundCount = 0
    
    var foundCount: Int {
        postsFoundCount + usersFoundCount
    }
    
    // User context
    private let userId: String
    
    enum SearchTab: String, CaseIterable {
        case all = "All"
        case posts = "Posts"
        case users = "Users"
    }
    
    // Recent searches (persisted in UserDefaults)
    var recentSearches: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: "recent_searches_\(userId)") ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "recent_searches_\(userId)")
        }
    }
    
    private var searchTask: Task<Void, Never>?
    
    init(userId: String) {
        self.userId = userId
    }
    
    // MARK: - Search
    
    func performSearch()  async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count >= 2 else {
            clearResults()
            return
        }
        
        print("[Search] 🔍 Starting search for: '\(query)'")
        isSearching = true
        
        do {
            // Use Typesense search API (search both collections)
            print("[Search] 📡 Calling searchAll API...")
            let response = try await linkioAPI.searchAll(query: query, perPage: 20)
            
            // Extract documents from hits
            if let posts = response.posts {
                postResults = posts.hits.map { $0.document }
                postsFoundCount = posts.found
            } else {
                postResults = []
                postsFoundCount = 0
            }
            
            if let users = response.users {
                userResults = users.hits.map { $0.document }
                usersFoundCount = users.found
            } else {
                userResults = []
                usersFoundCount = 0
            }
            
            print("[Search] ✅ Found \(postsFoundCount) posts and \(usersFoundCount) users")
            
            // Initialize counts for search results
            let posts = postResults.compactMap { doc -> Post? in
                createPost(from: doc)
            }
            
            if !posts.isEmpty {
                realtimeManager.initializeCounts(posts: posts)
                await loadBatchStats(for: posts)
            }
            
            // Save to recent searches
            saveRecentSearch(query)
            
        } catch {
            print("[Search] ❌ Error: \(error.localizedDescription)")
            clearResults()
        }
        
        isSearching = false
    }
    
    private func clearResults() {
        postResults = []
        userResults = []
        postsFoundCount = 0
        usersFoundCount = 0
    }
    
    // Helper to create Post from TypesensePostDocument
    private func createPost(from doc: TypesensePostDocument) -> Post? {
        guard let createdTimestamp = doc.createdAt,
              let updatedTimestamp = doc.updatedAt else {
            return nil
        }
        
        let created = Date(timeIntervalSince1970: TimeInterval(createdTimestamp))
        let updated = Date(timeIntervalSince1970: TimeInterval(updatedTimestamp))
        
        // Build JSON string and decode
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
    
    private func loadBatchStats(for posts: [Post]) async {
        let postIds = posts.map { $0.id }
        
        do {
            async let likeCounts = linkioAPI.getBatchLikeCounts(userId: userId, postIds: postIds)
            async let commentCounts = linkioAPI.getBatchCommentCounts(userId: userId, postIds: postIds)
            
            let (likes, comments) = try await (likeCounts, commentCounts)
            
            realtimeManager.batchInitializeCounts(
                likeCounts: likes,
                commentCounts: comments,
                posts: posts
            )
            
        } catch {
            print("[Search] Failed to load stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recent Searches
    
    private func saveRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var searches = recentSearches
        
        // Remove if already exists
        searches.removeAll { $0 == trimmed }
        
        // Add to front
        searches.insert(trimmed, at: 0)
        
        // Keep only last 10
        if searches.count > 10 {
            searches = Array(searches.prefix(10))
        }
        
        recentSearches = searches
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
    }
    
    func clearRecentSearches() {
        recentSearches = []
    }
}
