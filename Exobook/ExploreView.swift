//
//
//  ExploreView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct ExploreView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: ExploreViewModel?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    exploreContent(viewModel: viewModel)
                } else if let user = currentUser {
                    ProgressView("Loading...")
                        .task {
                            initializeViewModel(for: user)
                        }
                } else {
                    Text("User not found")
                }
            }
            .navigationTitle("Explore")
        }
    }
    
    @ViewBuilder
    private func exploreContent(viewModel: ExploreViewModel) -> some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar(viewModel: viewModel)
            
            // Tab filter (only show when searching)
            if !viewModel.searchQuery.isEmpty {
                tabFilter(viewModel: viewModel)
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
                        searchResults(viewModel: viewModel)
                    } else {
                        // Recommended content when not searching
                        recommendedSection(viewModel: viewModel)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
        }
        .task {
            await viewModel.loadRecommendedContent()
        }
    }

    private func initializeViewModel(for user: User) {
        let courseCodes = user.courseCodes
        let newViewModel = ExploreViewModel(
            userId: user.id,
            year: user.year ?? 1,
            courses: courseCodes.isEmpty ? ["General"] : courseCodes
        )
        
        Task { @MainActor in
            viewModel = newViewModel
            print("✅ ExploreViewModel initialized for user: \(user.id)")
        }
    }
    
    // MARK: - Search Bar
    
    private func searchBar(viewModel: ExploreViewModel) -> some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users, posts...", text: $vm.searchQuery)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .onChange(of: vm.searchQuery) {
                        vm.performSearch()
                    }
                
                if !vm.searchQuery.isEmpty {
                    Button(action: { vm.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            
            if isSearchFocused || !vm.searchQuery.isEmpty {
                Button("Cancel") {
                    vm.clearSearch()
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
    
    private func tabFilter(viewModel: ExploreViewModel) -> some View {
        @Bindable var vm = viewModel
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ExploreViewModel.SearchTab.allCases, id: \.self) { tab in
                    Button(action: { vm.selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(vm.selectedTab == tab ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                vm.selectedTab == tab
                                    ? Color.blue
                                    : Color(uiColor: .secondarySystemBackground)
                            )
                            .foregroundColor(
                                vm.selectedTab == tab
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
    
    private func searchResults(viewModel: ExploreViewModel) -> some View {
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
    
    private func recommendedSection(viewModel: ExploreViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended for you")
                .font(.title2)
                .fontWeight(.bold)

            if currentUser != nil {
                NavigationLink {
                    MeetingsView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Course Meetings")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("See upcoming study sessions, RSVP, or host one for your classes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            
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
                        currentUserId: currentUser?.id ?? "",
                        isBookmarked: false,
                        onLike: {},
                        onComment: {},
                        onBookmark: {},
                        onDelete: {},
                        onReport: {}
                    )
                }
            }
        }
    }
}


#Preview {
    ExploreView()
}
