//
//  GroupsAPIService.swift
//

import Foundation

// MARK: - Models

struct CommunityGroup: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String?
    let createdBy: String?
    let creatorName: String?
    let members: [String]
    let chatID: String?
    let createdAt: String?
    let updatedAt: String?

    var memberCount: Int {
        members.count
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, members
        case createdBy = "created_by"
        case creatorName = "creator_name"
        case chatID = "chat_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateCommunityGroupRequest: Encodable {
    let name: String
    let description: String?
    let createdBy: String
    let creatorName: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case createdBy = "created_by"
        case creatorName = "creator_name"
    }
}

// MARK: - Service

@MainActor
final class GroupsAPIService {
    private let network = NetworkService.shared
    private let base = APIConfig.baseAPI

    private struct SingleEnvelope: Decodable {
        let data: CommunityGroup
    }
    private struct StatusResponse: Decodable {
        let message: String?
    }

    func getAllGroups() async throws -> [CommunityGroup] {
        try await network.get("\(base)/api/groups")
    }

    func getUserGroups(userId: String) async throws -> [CommunityGroup] {
        try await network.get("\(base)/api/groups/\(userId)")
    }

    func getGroup(id: String) async throws -> CommunityGroup {
        let env: SingleEnvelope = try await network.get("\(base)/api/group/\(id)")
        return env.data
    }

    func createGroup(_ req: CreateCommunityGroupRequest) async throws -> CommunityGroup {
        let env: SingleEnvelope = try await network.post("\(base)/api/group", body: req)
        return env.data
    }

    func joinGroup(groupId: String, userId: String) async throws {
        let _: StatusResponse = try await network.patch(
            "\(base)/api/group/\(groupId)/join/\(userId)", body: EmptyBody()
        )
    }

    func leaveGroup(groupId: String, userId: String) async throws {
        let _: StatusResponse = try await network.delete(
            "\(base)/api/group/\(groupId)/members/\(userId)"
        )
    }

    func deleteGroup(id: String) async throws {
        let _: StatusResponse = try await network.delete("\(base)/api/group/\(id)")
    }
}

private struct EmptyBody: Encodable {}
