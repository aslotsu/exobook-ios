//
//
//  ExploreView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct ExploreView: View {
    @State private var viewModel = ExploreViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tab filter (only show when searching)
                if !viewModel.searchQuery.isEmpty {
                    tabFilter
                }
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isSearching {
                            // Loading state
                            ProgressView()
                                .padding()
                        } else if viewModel.shouldShowEmptyState {
                            // Empty search results
                            emptySearchState
                        } else if !viewModel.searchQuery.isEmpty {
                            // Search results
                            searchResults
                        } else {
                            // Recommended content when not searching
                            recommendedSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Explore")
            .task {
                await viewModel.loadRecommendedContent()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users, posts...", text: $viewModel.searchQuery)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchQuery) {
                        viewModel.performSearch()
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            
            if isSearchFocused || !viewModel.searchQuery.isEmpty {
                Button("Cancel") {
                    viewModel.clearSearch()
                    isSearchFocused = false
                }
                .transition(.move(edge: .trailing))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(.default, value: isSearchFocused)
    }
    
    // MARK: - Tab Filter
    
    private var tabFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ExploreViewModel.SearchTab.allCases, id: \.self) { tab in
                    Button(action: { viewModel.selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedTab == tab
                                    ? Color.blue
                                    : Color(uiColor: .secondarySystemBackground)
                            )
                            .foregroundColor(
                                viewModel.selectedTab == tab
                                    ? .white
                                    : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        VStack(spacing: 16) {
            // Results count
            HStack {
                Text("\(viewModel.filteredResults.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Results list
            ForEach(viewModel.filteredResults) { hit in
                SearchResultCard(hit: hit)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try searching with different keywords")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Recommended Section
    
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended for you")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.isLoadingRecommended {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.recommendedPosts.isEmpty {
                Text("No recommendations available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.recommendedPosts.prefix(10)) { post in
                    PostCard(
                        post: post,
                        isLiked: false,
                        isBookmarked: false,
                        onLike: {},
                        onComment: {},
                        onBookmark: {}
                    )
                }
            }
        }
    }
}


#Preview {
    ExploreView()
}
