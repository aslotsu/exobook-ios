//
//  ExploreViewModel.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
class ExploreViewModel {
    private let searchService = SearchService()
    private let exobookAPI = ExobookAPIService()
    
    // User context
    let userId: String
    let userYear: Int
    let userCourses: [String]
    
    // Search state
    var searchQuery = ""
    var searchResults: [SearchHit] = []
    var isSearching = false
    var searchError: String?
    
    // Filter state
    var selectedTab: SearchTab = .all
    
    // Recommended content
    var recommendedPosts: [Post] = []
    var isLoadingRecommended = false
    
    // Debounce timer
    private var searchTask: Task<Void, Never>?
    
    init(userId: String, year: Int, courses: [String]) {
        self.userId = userId
        self.userYear = year
        self.userCourses = courses
    }
    
    enum SearchTab: String, CaseIterable {
        case all = "All"
        case users = "Users"
        case posts = "Posts"
    }
    
    // Filtered results based on selected tab
    var filteredResults: [SearchHit] {
        switch selectedTab {
        case .all:
            return searchResults
        case .users:
            return searchResults.filter { $0.document.isUserResult }
        case .posts:
            return searchResults.filter { !$0.document.isUserResult }
        }
    }
    
    // MARK: - Search Operations
    
    func performSearch() {
        // Cancel previous search
        searchTask?.cancel()
        
        // Clear results if query is empty
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Don't search if query is too short
        guard searchQuery.count >= 2 else {
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await executeSearch()
        }
    }
    
    private func executeSearch() async {
        isSearching = true
        searchError = nil
        
        do {
            let response = try await searchService.search(query: searchQuery)
            searchResults = response.hits
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchError = nil
        searchTask?.cancel()
    }
    
    // MARK: - Recommended Content
    
    func loadRecommendedContent() async {
        guard recommendedPosts.isEmpty else { return }
        
        isLoadingRecommended = true
        
        do {
            // Load recommended posts based on user's courses
            let request = AllPostsRequest(
                courses: userCourses.isEmpty ? ["General"] : userCourses,
                year: userYear,
                id: userId
            )
            
            recommendedPosts = try await exobookAPI.getAllPosts(request: request)
        } catch {
            print("Failed to load recommended posts: \(error)")
        }
        
        isLoadingRecommended = false
    }
    
    // MARK: - Navigation Helpers
    
    var shouldShowEmptyState: Bool {
        !isSearching && searchQuery.count >= 2 && searchResults.isEmpty
    }
    
    var shouldShowRecommended: Bool {
        searchQuery.isEmpty && !isLoadingRecommended
    }
}
