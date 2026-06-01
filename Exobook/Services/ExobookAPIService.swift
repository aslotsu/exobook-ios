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

    private func userHeaders(for userID: String) -> [String: String] {
        ["X-Authenticated-User-ID": userID.lowercased()]
    }
    
    // MARK: - Posts
    
    func createPost(_ post: CreatePostRequest) async throws -> Post {
        let response: CreatePostResponse = try await network.post(
            "\(baseURL)/api/post",
            body: post,
            headers: userHeaders(for: post.userId)
        )
        return response.created
    }
    
    func getAllPosts(request: AllPostsRequest) async throws -> [Post] {
        let response: PostsResponse = try await network.post("\(baseURL)/api/post/all", body: request)
        return response.posts
    }
    
    func getUserPosts(userId: String) async throws -> [Post] {
        try await network.get("\(baseURL)/api/post/\(userId)")
    }
    
    func getPost(id: String) async throws -> Post {
        try await network.get("\(baseURL)/api/post/one/\(id)")
    }
    
    func deletePost(id: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.delete("\(baseURL)/api/post/\(id)")
    }
    
    func updatePost(id: String, post: UpdatePostRequest) async throws -> Post {
        let _: MutationCountResponse = try await network.put("\(baseURL)/api/post/\(id)", body: post)
        return try await getPost(id: id)
    }
    
    func likePost(id: String, userId: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.patch(
            "\(baseURL)/post/\(id)/\(userId)",
            body: EmptyBody(),
            headers: userHeaders(for: userId)
        )
    }
    
    func unlikePost(id: String, userId: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.patch(
            "\(baseURL)/api/post/\(id)/\(userId)",
            body: EmptyBody(),
            headers: userHeaders(for: userId)
        )
    }
    
    // MARK: - Redis Stats (Batch Fetching)
    
    func getBatchLikeCounts(userId: String, postIds: [String]) async throws -> [String: Int] {
        let request = BatchStatsRequest(postIds: postIds)
        return try await network.post("\(baseURL)/redis/likes/mine/\(userId)", body: request)
    }
    
    func getBatchCommentCounts(userId: String, postIds: [String]) async throws -> [String: Int] {
        let request = BatchCommentStatsRequest(commentIds: postIds)
        return try await network.post("\(baseURL)/redis/likes/mine/comment/\(userId)", body: request)
    }
    
    func getPostStats(postId: String) async throws -> PostStats {
        let response: PostStatsResponse = try await network.get("\(baseURL)/redis/stats/\(postId)")
        return response.stats
    }
    
    // MARK: - Replies
    
    func createReply(_ reply: CreateReplyRequest) async throws -> Reply {
        try await network.post(
            "\(baseURL)/api/replies",
            body: reply,
            headers: userHeaders(for: reply.userId)
        )
    }
    
    func createNestedReply(_ reply: CreateNestedReplyRequest) async throws -> Reply {
        try await network.post(
            "\(baseURL)/api/nested-replies",
            body: reply,
            headers: userHeaders(for: reply.userId)
        )
    }
    
    func getReplies(postId: String) async throws -> [Reply] {
        try await network.get("\(baseURL)/api/replies/\(postId)")
    }
    
    func getNestedReplies(replyId: String) async throws -> [Reply] {
        try await network.get("\(baseURL)/api/nested-replies/\(replyId)")
    }
    
    func deleteReply(id: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.delete("\(baseURL)/api/replies/\(id)")
    }
    
    func updateReply(id: String, reply: UpdateReplyRequest) async throws -> Reply {
        let _: MutationCountResponse = try await network.put("\(baseURL)/api/replies/\(id)", body: reply)
        return try await network.get("\(baseURL)/api/comment/one/\(id)")
    }
    
    // MARK: - Users
    
    func createUser(_ user: CreateUserRequest) async throws -> CreateUserResponse {
        try await network.post(
            "\(baseURL)/api/users",
            body: user,
            headers: userHeaders(for: user.id)
        )
    }
    
    func getUser(id: String) async throws -> User {
        try await network.get("\(baseURL)/api/users/\(id)")
    }
    
    func getUserWithCourses(id: String) async throws -> User {
        // This will fetch user with their enrolled courses
        try await network.get("\(baseURL)/api/users/\(id)")
    }
    
    func updateUser(_ user: UpdateUserRequest) async throws -> User {
        let _: FlexibleAcknowledgementResponse = try await network.put(
            "\(baseURL)/api/users",
            body: user,
            headers: userHeaders(for: user.id)
        )
        return try await getUser(id: user.id)
    }
    
    func deleteUser(id: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.delete("\(baseURL)/api/users/\(id)")
    }
    
    func setCampus(userId: String, campus: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.post(
            "\(baseURL)/api/campus/\(userId)",
            body: ["campus": campus],
            headers: userHeaders(for: userId)
        )
    }
    
    // MARK: - Shopping
    
    func getItems(campus: String) async throws -> [ShoppingItem] {
        try await network.get("\(baseURL)/api/shopping/\(campus)")
    }
    
    func getItem(itemId: String) async throws -> ShoppingItem {
        try await network.get("\(baseURL)/api/shopping/one/\(itemId)")
    }
    
    func getMyItems(userId: String) async throws -> [ShoppingItem] {
        try await network.get(
            "\(baseURL)/api/shopping/mine?id=\(userId)",
            headers: userHeaders(for: userId)
        )
    }
    
    func createItem(_ item: CreateItemRequest) async throws -> ShoppingItem {
        try await network.post("\(baseURL)/api/shopping/new-item", body: item)
    }
    
    func deleteItem(itemId: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.delete("\(baseURL)/api/shopping/\(itemId)")
    }
    
    // MARK: - Meetings
    
    func getMeetings(courses: String) async throws -> [Meeting] {
        try await network.get("\(baseURL)/api/meetings/\(courses)")
    }
    
    func getMeeting(id: String) async throws -> Meeting {
        try await network.get("\(baseURL)/api/meetings/one/\(id)")
    }
    
    func createMeeting(_ meeting: CreateMeetingRequest) async throws -> FlexibleAcknowledgementResponse {
        try await network.post(
            "\(baseURL)/api/meetings/",
            body: meeting,
            headers: userHeaders(for: meeting.creator)
        )
    }
    
    func deleteMeeting(id: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.delete("\(baseURL)/api/meetings/\(id)")
    }
    
    // MARK: - Groups
    
    func getMyGroups(userId: String) async throws -> [ExobookGroup] {
        try await network.get("\(baseURL)/api/groups/\(userId)")
    }
    
    func getGroup(id: String) async throws -> ExobookGroup {
        let response: GroupEnvelope = try await network.get("\(baseURL)/api/group/\(id)")
        return response.data
    }
    
    func createGroup(_ group: CreateGroupRequest) async throws -> FlexibleAcknowledgementResponse {
        try await network.post(
            "\(baseURL)/api/group",
            body: group,
            headers: userHeaders(for: group.createdBy)
        )
    }
    
    func joinGroup(userId: String, groupId: String) async throws -> FlexibleAcknowledgementResponse {
        try await network.patch(
            "\(baseURL)/api/group/\(userId)?groupId=\(groupId)",
            body: EmptyBody(),
            headers: userHeaders(for: userId)
        )
    }
    
    // MARK: - Universities & Courses
    
    func getAllUniversities() async throws -> [University] {
        try await network.get("\(baseURL)/api/unis")
    }
    
    func getCourses(universityId: String) async throws -> [Course] {
        try await network.get("\(baseURL)/api/courses/\(universityId)")
    }
    
    func getMyCourses(userId: String) async throws -> [UserCourseItem] {
        let response: UserCoursesResponse = try await network.get("\(baseURL)/api/courses/user/\(userId)")
        return response.list
    }
}

// MARK: - Request/Response Models

private struct EmptyBody: Encodable {}

// Posts
struct CreatePostRequest: Encodable {
    let userId: String
    let username: String
    let userPicture: String
    let userBio: String
    let userProgramme: String
    let userYear: Int
    let userCampus: String
    let subject: String
    let title: String
    let content: String
    let images: [String]
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

struct PostsResponse: Codable {
    let posts: [Post]
    let hasMore: Bool
    let page: Int
    let limit: Int
}

struct CreatePostResponse: Codable {
    let created: Post
}

struct MutationCountResponse: Codable {
    let updated: Int?
    let deleted: Int?
}

struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let userName: String?
    let userBio: String
    let userCampus: String
    let userProgramme: String
    let userYear: Int
    let userPicture: String
    let title: String
    let content: String
    let subject: String  // course_code
    let images: [String]
    let likes: [String]?
    let comments: [String]?
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var likeCount: Int { likes?.count ?? 0 }
    var commentCount: Int { comments?.count ?? 0 }
    var userAvatarURL: URL? {
        if userPicture.starts(with: "http") {
            return URL(string: userPicture)
        }
        // If path starts with /, it's a static asset from linkio.ca
        if userPicture.starts(with: "/") {
            return URL(string: "https://linkio.ca\(userPicture)")
        }
        // Otherwise it's from S3
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
    let bio: String
    let picture: String
    let school: String
    let country: String
    let campus: String
    let infoUpdated: Bool
    let program: String
    let year: Int

    init(
        id: String,
        email: String,
        name: String,
        bio: String = "Eager to try out Exobook!",
        picture: String = "",
        school: String = "",
        country: String = "",
        campus: String = "",
        infoUpdated: Bool = false,
        program: String = "",
        year: Int = 1
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.bio = bio
        self.picture = picture
        self.school = school
        self.country = country
        self.campus = campus
        self.infoUpdated = infoUpdated
        self.program = program
        self.year = year
    }
}

struct CreateUserResponse: Decodable {
    let message: String?
    let success: Bool?
    let rowsAffected: Int?
    let username: String?
}

struct UpdateUserRequest: Encodable {
    let id: String
    let name: String?
    let bio: String?
    let country: String?
    let picture: String?
    let campus: String?
    let program: String?
    let year: Int?

    init(
        id: String,
        name: String? = nil,
        bio: String? = nil,
        country: String? = nil,
        picture: String? = nil,
        campus: String? = nil,
        program: String? = nil,
        year: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.bio = bio
        self.country = country
        self.picture = picture
        self.campus = campus
        self.program = program
        self.year = year
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case bio
        case country
        case picture
        case campus
        case program = "programme"
        case year
    }
}

// Shopping
struct CreateItemRequest: Encodable {
    let sellerId: String
    let address: String
    let category: String
    let name: String
    let description: String
    let price: Int
    let highPrice: Int
    let lowPrice: Int
    let pictures: [String]
    let qtySold: Int
    let campus: String
}

struct ShoppingItem: Codable, Identifiable {
    let id: String
    let itemId: String?
    let sellerId: String
    let address: String
    let category: String
    let name: String
    let description: String
    let price: Int
    let highPrice: Int?
    let lowPrice: Int?
    let pictures: [String]?
    let campus: String
    let qtySold: Int?

    var title: String { name }
}

// Meetings
struct CreateMeetingRequest: Encodable {
    let creator: String
    let title: String
    let creatorName: String
    let creatorBio: String
    let course: String
    let location: String
    let coordinates: String
    let startTime: Date
}

struct Meeting: Codable, Identifiable {
    let id: String
    let creator: String
    let title: String
    let creatorName: String
    let creatorBio: String
    let course: String
    let createdAt: Date
    let location: String
    let coordinates: String
    let startTime: Date
    let willAttend: [String]?
}

// Groups
struct CreateGroupRequest: Encodable {
    let name: String
    let description: String
    let createdBy: String
    let creatorName: String
}

struct ExobookGroup: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let createdBy: String
    let creatorName: String
    let members: [String]
    let chatCode: String
    let createdAt: Date
    let updatedAt: Date
}

struct GroupEnvelope: Decodable {
    let data: ExobookGroup
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

struct UserCoursesResponse: Codable {
    let id: String
    let list: [UserCourseItem]
}

struct UserCourseItem: Codable {
    let courseCode: String
    let courseName: String
    let programName: String
    let year: String

    private enum CodingKeys: String, CodingKey {
        case courseCode
        case courseName
        case programName
        case year
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courseCode = try container.decode(String.self, forKey: .courseCode)
        courseName = try container.decode(String.self, forKey: .courseName)
        programName = try container.decode(String.self, forKey: .programName)

        if let stringYear = try? container.decode(String.self, forKey: .year) {
            year = stringYear
        } else if let intYear = try? container.decode(Int.self, forKey: .year) {
            year = String(intYear)
        } else {
            year = ""
        }
    }
}

// Redis Stats
struct BatchStatsRequest: Encodable {
    let postIds: [String]
    
    // For likes endpoint
    enum CodingKeys: String, CodingKey {
        case postIds = "post_ids"
    }
}

struct BatchCommentStatsRequest: Encodable {
    let commentIds: [String]
    
    // For comments endpoint
    enum CodingKeys: String, CodingKey {
        case commentIds = "comment_ids"
    }
}

struct PostStatsResponse: Codable {
    let stats: PostStats
}

struct PostStats: Codable {
    let likes: Int
    let replies: Int
}

struct FlexibleAcknowledgementResponse: Decodable {
    let message: String?
    let count: Int?
    let success: Bool?

    private enum CodingKeys: String, CodingKey {
        case message
        case count
        case deleted
        case updated
        case data
        case success
        case rowsAffected
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer() {
            if let stringValue = try? singleValue.decode(String.self) {
                message = stringValue
                count = nil
                success = nil
                return
            }

            if let intValue = try? singleValue.decode(Int.self) {
                message = nil
                count = intValue
                success = nil
                return
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try? container.decode(String.self, forKey: .message)
        count =
            (try? container.decode(Int.self, forKey: .count)) ??
            (try? container.decode(Int.self, forKey: .deleted)) ??
            (try? container.decode(Int.self, forKey: .updated)) ??
            (try? container.decode(Int.self, forKey: .data)) ??
            (try? container.decode(Int.self, forKey: .rowsAffected))
        success = try? container.decode(Bool.self, forKey: .success)
    }
}
