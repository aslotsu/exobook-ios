//
//  ExobookAPIService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
class ExobookAPIService {
    private let network = NetworkService.shared
    private let baseURL = APIConfig.baseAPI
    
    // MARK: - Posts
    
    func createPost(_ post: CreatePostRequest) async throws -> Post {
        try await network.post("\(baseURL)/api/post", body: post)
    }
    
    func getAllPosts(request: AllPostsRequest) async throws -> [Post] {
        try await network.post("\(baseURL)/api/post/all", body: request)
    }
    
    func getUserPosts(userId: String) async throws -> [Post] {
        try await network.get("\(baseURL)/api/post/\(userId)")
    }
    
    func getPost(id: String) async throws -> Post {
        try await network.get("\(baseURL)/api/post/one/\(id)")
    }
    
    func deletePost(id: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/post/\(id)")
    }
    
    func updatePost(id: String, post: UpdatePostRequest) async throws -> Post {
        try await network.put("\(baseURL)/api/post/\(id)", body: post)
    }
    
    func likePost(id: String, userId: String) async throws -> EmptyResponse {
        try await network.patch("\(baseURL)/post/\(id)/\(userId)", body: EmptyBody())
    }
    
    func unlikePost(id: String, userId: String) async throws -> EmptyResponse {
        try await network.patch("\(baseURL)/api/post/\(id)/\(userId)", body: EmptyBody())
    }
    
    // MARK: - Replies
    
    func createReply(_ reply: CreateReplyRequest) async throws -> Reply {
        try await network.post("\(baseURL)/api/replies", body: reply)
    }
    
    func createNestedReply(_ reply: CreateNestedReplyRequest) async throws -> Reply {
        try await network.post("\(baseURL)/api/nested-replies", body: reply)
    }
    
    func getReplies(postId: String) async throws -> [Reply] {
        try await network.get("\(baseURL)/api/replies/\(postId)")
    }
    
    func getNestedReplies(replyId: String) async throws -> [Reply] {
        try await network.get("\(baseURL)/api/nested-replies/\(replyId)")
    }
    
    func deleteReply(id: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/replies/\(id)")
    }
    
    func updateReply(id: String, reply: UpdateReplyRequest) async throws -> Reply {
        try await network.put("\(baseURL)/api/replies/\(id)", body: reply)
    }
    
    // MARK: - Users
    
    func createUser(_ user: CreateUserRequest) async throws -> User {
        try await network.post("\(baseURL)/api/users", body: user)
    }
    
    func getUser(id: String) async throws -> User {
        try await network.get("\(baseURL)/api/users/\(id)")
    }
    
    func updateUser(_ user: UpdateUserRequest) async throws -> User {
        try await network.put("\(baseURL)/api/users", body: user)
    }
    
    func deleteUser(id: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/users/\(id)")
    }
    
    func setCampus(userId: String, campus: String) async throws -> EmptyResponse {
        try await network.post("\(baseURL)/api/campus/\(userId)", body: ["campus": campus])
    }
    
    // MARK: - Shopping
    
    func getItems(campus: String) async throws -> [ShoppingItem] {
        try await network.get("\(baseURL)/api/shopping/\(campus)")
    }
    
    func getItem(itemId: String) async throws -> ShoppingItem {
        try await network.get("\(baseURL)/api/shopping/one/\(itemId)")
    }
    
    func getMyItems() async throws -> [ShoppingItem] {
        try await network.get("\(baseURL)/api/shopping/mine")
    }
    
    func createItem(_ item: CreateItemRequest) async throws -> ShoppingItem {
        try await network.post("\(baseURL)/api/shopping/new-item", body: item)
    }
    
    func deleteItem(itemId: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/shopping/\(itemId)")
    }
    
    // MARK: - Meetings
    
    func getMeetings(courses: String) async throws -> [Meeting] {
        try await network.get("\(baseURL)/api/meetings/\(courses)")
    }
    
    func getMeeting(id: String) async throws -> Meeting {
        try await network.get("\(baseURL)/api/meetings/one/\(id)")
    }
    
    func createMeeting(_ meeting: CreateMeetingRequest) async throws -> Meeting {
        try await network.post("\(baseURL)/api/meetings/", body: meeting)
    }
    
    func deleteMeeting(id: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/meetings/\(id)")
    }
    
    // MARK: - Groups
    
    func getMyGroups(userId: String) async throws -> [ExobookGroup] {
        try await network.get("\(baseURL)/api/groups/\(userId)")
    }
    
    func getGroup(id: String) async throws -> ExobookGroup {
        try await network.get("\(baseURL)/api/group/\(id)")
    }
    
    func createGroup(_ group: CreateGroupRequest) async throws -> ExobookGroup {
        try await network.post("\(baseURL)/api/group", body: group)
    }
    
    func joinGroup(id: String) async throws -> EmptyResponse {
        try await network.patch("\(baseURL)/api/group/\(id)", body: EmptyBody())
    }
    
    // MARK: - Universities & Courses
    
    func getAllUniversities() async throws -> [University] {
        try await network.get("\(baseURL)/api/unis")
    }
    
    func getCourses(universityId: String) async throws -> [Course] {
        try await network.get("\(baseURL)/api/courses/\(universityId)")
    }
    
    func getMyCourses(userId: String) async throws -> [Course] {
        try await network.get("\(baseURL)/api/courses/user/\(userId)")
    }
}

// MARK: - Request/Response Models

private struct EmptyBody: Encodable {}

// Posts
struct CreatePostRequest: Encodable {
    let userId: String
    let title: String
    let content: String
    let tags: [String]?
}

struct AllPostsRequest: Encodable {
    let courses: [String]  // course codes
    let year: Int
    let id: String  // user id
}

struct UpdatePostRequest: Encodable {
    let title: String?
    let content: String?
}

struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let userName: String
    let userBio: String
    let userCampus: String
    let userProgramme: String
    let userYear: Int
    let userPicture: String
    let title: String
    let content: String
    let subject: String  // course_code
    let images: [String]
    let likes: [String]
    let comments: [String]
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var likeCount: Int { likes.count }
    var commentCount: Int { comments.count }
    var userAvatarURL: URL? {
        if userPicture.starts(with: "http") {
            return URL(string: userPicture)
        }
        return URL(string: "https://exobook.s3.amazonaws.com/\(userPicture)")
    }
    var imageURLs: [URL] {
        images.compactMap { URL(string: "https://exobook.s3.amazonaws.com/\($0)") }
    }
}

// Replies
struct CreateReplyRequest: Encodable {
    let postId: String
    let userId: String
    let content: String
}

struct CreateNestedReplyRequest: Encodable {
    let replyId: String
    let userId: String
    let content: String
}

struct UpdateReplyRequest: Encodable {
    let content: String
}

struct Reply: Codable, Identifiable {
    let id: String
    let postId: String?
    let replyId: String?
    let userId: String
    let content: String
    let createdAt: Date
}

// Users
struct CreateUserRequest: Encodable {
    let id: String
    let email: String
    let name: String
}

struct UpdateUserRequest: Encodable {
    let id: String
    let name: String?
    let bio: String?
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let bio: String?
    let campus: String?
}

// Shopping
struct CreateItemRequest: Encodable {
    let title: String
    let description: String
    let price: Double
    let campus: String
}

struct ShoppingItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let campus: String
    let sellerId: String
}

// Meetings
struct CreateMeetingRequest: Encodable {
    let title: String
    let description: String
    let courses: [String]
    let date: Date
}

struct Meeting: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let courses: [String]
    let date: Date
}

// Groups
struct CreateGroupRequest: Encodable {
    let name: String
    let description: String
}

struct ExobookGroup: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
}

// Universities & Courses
struct University: Codable, Identifiable {
    let id: String
    let name: String
}

struct Course: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
}
