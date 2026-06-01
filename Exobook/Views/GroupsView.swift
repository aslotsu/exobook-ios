//
//  GroupsView.swift
//

import SwiftUI

struct GroupsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel = GroupsViewModel()
    @State private var selectedGroup: CommunityGroup?
    @State private var showingCreate = false
    @State private var searchText = ""

    var filteredGroups: [CommunityGroup] {
        searchText.isEmpty ? viewModel.allGroups
            : viewModel.allGroups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.myGroups.isEmpty {
                    Section("My Groups") {
                        ForEach(viewModel.myGroups) { group in
                            GroupRow(group: group, isMember: true)
                                .onTapGesture { selectedGroup = group }
                        }
                    }
                }

                Section("All Groups") {
                    if viewModel.isLoading && viewModel.allGroups.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if filteredGroups.isEmpty {
                        Text("No groups found")
                            .foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(filteredGroups) { group in
                            GroupRow(group: group, isMember: viewModel.isMember(of: group))
                                .onTapGesture { selectedGroup = group }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .searchable(text: $searchText, prompt: "Search groups")
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable {
                if let uid = currentUser?.id { await viewModel.loadGroups(userId: uid) }
            }
            .task {
                if let uid = currentUser?.id { await viewModel.loadGroups(userId: uid) }
            }
            .navigationDestination(item: $selectedGroup) { group in
                GroupDetailView(group: group, viewModel: viewModel)
            }
            .sheet(isPresented: $showingCreate) {
                CreateGroupSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: CommunityGroup
    let isMember: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(group.name).font(.headline)
                    if isMember {
                        Text("Joined")
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundColor(.green)
                    }
                }
                if let desc = group.description {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    @Bindable var viewModel: GroupsViewModel
    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Name", text: $viewModel.newGroupName)
                    TextField("Description (optional)", text: $viewModel.newGroupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let err = viewModel.createError {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if let currentUser,
                               (await viewModel.createGroup(user: currentUser)) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}
