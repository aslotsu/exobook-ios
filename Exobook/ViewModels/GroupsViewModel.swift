//
//  GroupsViewModel.swift
//

import Foundation
import Observation

@MainActor
@Observable
final class GroupsViewModel {
    private let api = GroupsAPIService()

    var allGroups: [CommunityGroup] = []
    var myGroups: [CommunityGroup] = []
    var isLoading = false
    var error: String?

    var newGroupName = ""
    var newGroupDescription = ""
    var isCreating = false
    var createError: String?

    func loadGroups(userId: String) async {
        isLoading = true
        error = nil
        async let all = api.getAllGroups()
        async let mine = api.getUserGroups(userId: userId)
        do {
            allGroups = try await all
            myGroups = try await mine
        } catch {
            self.error = "Failed to load groups: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func createGroup(user: User) async -> CommunityGroup? {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { createError = "Name is required."; return nil }
        isCreating = true
        createError = nil
        defer { isCreating = false }
        do {
            let req = CreateCommunityGroupRequest(
                name: name,
                description: newGroupDescription.isEmpty ? nil : newGroupDescription,
                createdBy: user.id,
                creatorName: user.displayName
            )
            let group = try await api.createGroup(req)
            allGroups.insert(group, at: 0)
            myGroups.insert(group, at: 0)
            newGroupName = ""
            newGroupDescription = ""
            return group
        } catch {
            createError = error.localizedDescription
            return nil
        }
    }

    func joinGroup(_ group: CommunityGroup, userId: String) async {
        do {
            try await api.joinGroup(groupId: group.id, userId: userId)
            if !myGroups.contains(where: { $0.id == group.id }) { myGroups.append(group) }
        } catch {
            self.error = "Failed to join: \(error.localizedDescription)"
        }
    }

    func leaveGroup(_ group: CommunityGroup, userId: String) async {
        do {
            try await api.leaveGroup(groupId: group.id, userId: userId)
            myGroups.removeAll { $0.id == group.id }
        } catch {
            self.error = "Failed to leave: \(error.localizedDescription)"
        }
    }

    func isMember(of group: CommunityGroup) -> Bool {
        myGroups.contains { $0.id == group.id }
    }
}
