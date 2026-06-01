//
//  LinkioAPIService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
class LinkioAPIService {
    private let network = NetworkService.shared
    private let baseURL = APIConfig.baseAPI
    
    // MARK: - Posts
    
    func createPost(_ post: CreatePostRequest) async throws -> Post {
        let response: CreatePostResponse = try await network.post("\(baseURL)/api/post", body: post)
        return response.created
    }
    
    func uploadImages(_ images: [Data]) async throws -> [String] {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        for (index, imageData) in images.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"fileName\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let response: ImageUploadResponse = try await network.upload(
            "\(baseURL)/api/buckets/upload",
            data: body,
            boundary: boundary
        )
        return response.files
    }
    
    func updatePostImages(postId: String, images: [String]) async throws -> Post {
        let request = UpdatePostImagesRequest(images: images)
        let response: UpdatePostImagesResponse = try await network.post("\(baseURL)/api/post-image/\(postId)", body: request)
        return response.updatedImageArray
    }
    
    func getAllPosts(
        request: AllPostsRequest,
        page: Int = 1,
        limit: Int = 10
    ) async throws -> PostsResponse {
        // Append pagination query parameters
        let endpoint = "\(baseURL)/api/post/all?page=\(page)&limit=\(limit)"
        let response: PostsResponse = try await network.post(endpoint, body: request)
        return response
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
    
    // NOTE: Post like/unlike now lives in LikesAPIService (DynamoDB likes service)
    // and the legacy main-API patch endpoints have been removed to avoid drift.

    // MARK: - Redis Stats (Batch Fetching)

    func getBatchLikeCounts(userId: String, postIds: [String]) async throws -> [String: Int] {
        let request = BatchStatsRequest(postIds: postIds)
        let response: [String: Int] = try await network.post("\(baseURL)/api/redis/likes/mine/\(userId)", body: request)
        return response
    }

    func getBatchCommentCounts(userId: String, postIds: [String]) async throws -> [String: Int] {
        let request = BatchCommentStatsRequest(commentIds: postIds)
        let response: [String: Int] = try await network.post("\(baseURL)/api/redis/likes/mine/comment/\(userId)", body: request)
        return response
    }
    
    func getPostStats(postId: String) async throws -> PostStats {
        let response: PostStatsResponse = try await network.get("\(baseURL)/api/redis/stats/\(postId)")
        return response.stats
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
        // Use /api/replies for nested (sub-thread) replies too, as it returns full user info (avatar/name)
        // unlike /api/nested-replies which is legacy/broken
        try await network.get("\(baseURL)/api/replies/\(replyId)")
    }
    
    func deleteReply(id: String) async throws -> EmptyResponse {
        try await network.delete("\(baseURL)/api/replies/\(id)")
    }
    
    func updateReply(id: String, reply: UpdateReplyRequest) async throws -> Reply {
        try await network.put("\(baseURL)/api/replies/\(id)", body: reply)
    }
    
    func updateCommentCount(postId: String) async throws {
        // Update Redis comment count - matches web frontend call to /api/redis/likes/comment/{postId}
        let _: EmptyResponse? = try? await network.post("\(baseURL)/api/redis/likes/comment/\(postId)", body: EmptyBody())
    }
    
    func getBatchReplyLikeCounts(postId: String, replyIds: [String]) async throws -> [String: Int] {
        // Matches web frontend call to /api/redis/my-reply-likes/:postId
        let request = BatchReplyLikesRequest(replyIds: replyIds)
        let response: [String: Int] = try await network.post("\(baseURL)/api/redis/my-reply-likes/\(postId)", body: request)
        return response
    }

    func getBatchSubReplyCounts(postId: String, replyIds: [String]) async throws -> [String: Int] {
        // Matches web frontend call to /api/redis/my-reply-count/d/:postId
        // Reusing BatchReplyLikesRequest as the JSON structure (reply_ids) is identical
        let request = BatchReplyLikesRequest(replyIds: replyIds)
        let response: [String: Int] = try await network.post("\(baseURL)/api/redis/my-reply-count/d/\(postId)", body: request)
        return response
    }

    /// Bump the parent reply's sub-reply counter in Redis. Mirrors web behaviour on nested-reply create.
    func incrementSubReplyCount(parentReplyId: String) async {
        let _: EmptyResponse? = try? await network.post(
            "\(baseURL)/api/redis/reply-count/\(parentReplyId)",
            body: EmptyBody()
        )
    }

    
    // MARK: - Images
    
    func attachImagesToReply(replyId: String, imageIds: [String]) async throws {
        let request = AttachImagesRequest(images: imageIds)
        // POST /api/reply-image/:id
        let _: EmptyResponse? = try? await network.post("\(baseURL)/api/reply-image/\(replyId)", body: request)
    }
    
    func uploadFiles(_ files: [(data: Data, filename: String, mimeType: String)]) async throws -> [String] {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        for (index, file) in files.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            // Key name is "fileName" per backend loop
            body.append("Content-Disposition: form-data; name=\"fileName\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Use ImageUploadResponse struct since backend returns {"files": [...]} for all uploads
        let response: ImageUploadResponse = try await network.upload(
            "\(baseURL)/api/buckets/upload",
            data: body,
            boundary: boundary
        )
        return response.files
    }

    // MARK: - Users
    
    func createUser(_ user: CreateUserRequest) async throws -> User {
        try await network.post("\(baseURL)/api/users", body: user)
    }
    
    func getUser(id: String) async throws -> User {
        try await network.get("\(baseURL)/api/users/\(id)")
    }
    
    func getUserWithCourses(id: String) async throws -> User {
        // This will fetch user with their enrolled courses
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
    
    func updateUserCourses(userId: String, courses: [CourseUpdateItem]) async throws -> EmptyResponse {
        let request = UpdateCoursesRequest(list: courses)
        return try await network.post("\(baseURL)/api/courses/set/\(userId)", body: request)
    }

    func setMyProgram(userId: String, program: Program) async throws -> EmptyResponse {
        let request = MyProgramRequest(userId: userId, program: program)
        return try await network.post("\(baseURL)/api/my-program", body: request)
    }

    func setMyCampus(userId: String, campus: CampusSelection) async throws -> EmptyResponse {
        let request = MyCampusRequest(userId: userId, campus: campus)
        return try await network.post("\(baseURL)/api/my-campus", body: request)
    }

    func getMyProgram(userId: String) async throws -> Program {
        let response: ProgramEnvelope = try await network.get("\(baseURL)/api/my-program/\(userId)")
        return response.data
    }

    func getMyCampus(userId: String) async throws -> CampusSelection {
        let response: CampusEnvelope = try await network.get("\(baseURL)/api/my-campus/\(userId)")
        return response.data
    }

    // MARK: - Device Tokens (FCM)

    func registerDeviceToken(
        userId: String,
        token: String,
        platform: String = "ios",
        deviceInfo: [String: Any]? = nil
    ) async throws -> DeviceTokenResponse {
        let request = RegisterDeviceTokenRequest(
            userId: userId,
            token: token,
            platform: platform,
            deviceInfo: deviceInfo
        )
        return try await network.post("\(baseURL)/api/device-token", body: request)
    }

    func deactivateDeviceToken(userId: String, token: String) async throws {
        struct Body: Encodable {
            let userId: String
            let token: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case token
            }
        }
        struct Resp: Decodable { let message: String? }
        let _: Resp = try await network.delete("\(baseURL)/api/device-token",
                                               body: Body(userId: userId, token: token))
    }

    func deleteUserAccount(id: String) async throws {
        struct Resp: Decodable { let message: String? }
        let _: Resp = try await network.delete("\(baseURL)/api/users/\(id)")
    }

    // MARK: - Universities & Courses
    
    func getAllUniversities() async throws -> [University] {
        let response: UniversitiesResponse = try await network.get("\(baseURL)/api/unis")
        return response.universities
    }

    func getPrograms(universityId: String) async throws -> [Program] {
        try await network.get("\(baseURL)/api/programs/\(universityId)")
    }
    
    func getCourses(universityId: String) async throws -> [Course] {
        try await network.get("\(baseURL)/api/courses/\(universityId)")
    }
    
    func getMyCourses(userId: String) async throws -> [UserCourseItem] {
        let response: UserCoursesResponse = try await network.get("\(baseURL)/api/courses/user/\(userId)")
        return response.list
    }

    // MARK: - Meetings

    func getMeetings(courses: [String], scope: MeetingScope = .upcoming) async throws -> [Meeting] {
        let normalizedCourses = courses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedCourses.isEmpty else {
            return []
        }

        let joinedCourses = normalizedCourses.joined(separator: ",")
        let encodedCourses = joinedCourses.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? joinedCourses
        let endpoint = "\(baseURL)/api/meetings/\(encodedCourses)?scope=\(scope.rawValue)"
        return try await network.get(endpoint)
    }

    func getMeeting(id: String) async throws -> Meeting {
        try await network.get("\(baseURL)/api/meetings/one/\(id)")
    }

    func createMeeting(_ request: CreateMeetingRequest) async throws -> Meeting {
        let response: MeetingEnvelope = try await network.post("\(baseURL)/api/meetings/", body: request)
        return response.meeting
    }

    func updateMeeting(id: String, request: UpdateMeetingRequest) async throws -> Meeting {
        let response: MeetingEnvelope = try await network.put("\(baseURL)/api/meetings/\(id)", body: request)
        return response.meeting
    }

    func rsvpMeeting(id: String, request: MeetingRSVPRequest) async throws -> MeetingRSVPResponse {
        try await network.patch("\(baseURL)/api/meetings/\(id)/rsvp", body: request)
    }

    func deleteMeeting(id: String) async throws {
        let _: String = try await network.delete("\(baseURL)/api/meetings/\(id)")
    }
    
    // MARK: - Bookmarks

    func createBookmark(postId: String, userId: String) async throws {
        struct Body: Encodable {
            let postId: String
            let userId: String
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case userId = "user_id"
            }
        }
        let _: EmptyResponse = try await network.post("\(baseURL)/api/bookmarks", body: Body(postId: postId, userId: userId))
    }

    func deleteBookmark(postId: String, userId: String) async throws {
        let _: EmptyResponse = try await network.delete("\(baseURL)/api/bookmarks/\(postId)?user_id=\(userId)")
    }

    func getUserBookmarks(userId: String) async throws -> [Post] {
        struct BookmarksEnvelope: Decodable {
            let bookmarks: [BookmarkItem]?
            let data: [BookmarkItem]?
            func posts() -> [Post] { (bookmarks ?? data ?? []).compactMap(\.post) }
        }
        struct BookmarkItem: Decodable {
            let post: Post?
        }
        let envelope: BookmarksEnvelope = try await network.get("\(baseURL)/api/bookmarks/user/\(userId)")
        return envelope.posts()
    }

    // MARK: - Likes

    func getMyLikes(userId: String) async throws -> [LikedPost] {
        // Note: Using APIConfig.likesAPI for DynamoDB likes service
        let response: LikesResponse = try await network.get("\(APIConfig.likesAPI)/api/likes/mine/\(userId)")
        return response.likes
    }
    
    // MARK: - Search (Typesense)
    
    func searchPosts(query: String, perPage: Int = 10) async throws -> TypesenseSearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Use main website URL for search proxy
        let endpoint = "https://linkio.ca/api/search?q=\(encodedQuery)&collection=posts&per_page=\(perPage)"
        
        let response: TypesenseMultiSearchResponse = try await network.get(endpoint)
        return response.posts ?? TypesenseSearchResponse(hits: [], found: 0, page: 1)
    }
    
    func searchUsers(query: String, perPage: Int = 10) async throws -> TypesenseUserSearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "https://linkio.ca/api/search?q=\(encodedQuery)&collection=users&per_page=\(perPage)"
        
        let response: TypesenseMultiSearchResponse = try await network.get(endpoint)
        return response.users ?? TypesenseUserSearchResponse(hits: [], found: 0, page: 1)
    }
    
    func searchAll(query: String, perPage: Int = 10) async throws -> TypesenseMultiSearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "https://linkio.ca/api/search?q=\(encodedQuery)&per_page=\(perPage)"
        
        return try await network.get(endpoint)
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
    let title: String
    let content: String
    let subject: String?
    let tags: [String]?
    let images: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case userPicture = "user_picture"
        case userBio = "user_bio"
        case userProgramme = "user_programme"
        case userYear = "user_year"
        case userCampus = "user_campus"
        case title
        case content
        case subject
        case tags
        case images
    }
}

struct CreatePostResponse: Decodable {
    let created: Post
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

struct UpdatePostImagesRequest: Encodable {
    let images: [String]
}

struct UpdatePostImagesResponse: Decodable {
    let updatedImageArray: Post
    
    enum CodingKeys: String, CodingKey {
        case updatedImageArray = "updated image array"
    }
}

struct ImageUploadResponse: Decodable {
    let files: [String]
}

struct PostsResponse: Codable {
    let posts: [Post]
    let hasMore: Bool
    let page: Int
    let limit: Int
}

struct Post: Codable, Identifiable, Hashable {
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
    let images: [String]?  // Can be null for deleted posts
    let likes: [String]?
    let comments: [String]?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case userName = "user_name"
        case userBio = "user_bio"
        case userCampus = "user_campus"
        case userProgramme = "user_programme"
        case userYear = "user_year"
        case userPicture = "user_picture"
        case title
        case content
        case subject
        case images
        case likes
        case comments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties
    var likeCount: Int { likes?.count ?? 0 }
    var commentCount: Int { comments?.count ?? 0 }
    var userAvatarURL: URL? {
        resolveAvatarURL(userPicture)
    }
    var imageURLs: [URL] {
        (images ?? []).compactMap(resolveMediaURL)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        
        // Robust decoding for strings that might be missing or null
        userBio = try container.decodeIfPresent(String.self, forKey: .userBio) ?? ""
        userCampus = try container.decodeIfPresent(String.self, forKey: .userCampus) ?? ""
        userProgramme = try container.decodeIfPresent(String.self, forKey: .userProgramme) ?? ""
        
        // Handle userYear as Int or String
        if let yearInt = try? container.decode(Int.self, forKey: .userYear) {
            userYear = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .userYear), let y = Int(yearString) {
            userYear = y
        } else {
            userYear = 1 // Default
        }
        
        userPicture = try container.decodeIfPresent(String.self, forKey: .userPicture) ?? ""
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        subject = try container.decode(String.self, forKey: .subject)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        likes = try container.decodeIfPresent([String].self, forKey: .likes)
        comments = try container.decodeIfPresent([String].self, forKey: .comments)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// Replies
struct CreateReplyRequest: Encodable {
    let userId: String
    let userName: String
    let userBio: String
    let userImage: String
    let owner: String  // Post owner's user ID
    let original: String  // Original post ID
    let postId: String
    let title: String
    let content: String
    let images: [String]
    let likes: [String]
    let level: Int?  // For nested replies
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
        case userBio = "user_bio"
        case userImage = "user_image"
        case owner
        case original
        case postId = "post_id"
        case title
        case content
        case images
        case likes
        case level
    }
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
    let userId: String
    let userName: String?
    let userBio: String?
    let owner: String?
    let userImage: String?
    let postId: String?
    let original: String?
    let title: String?
    let content: String
    let images: [String]?
    let likes: [String]?
    let level: Int?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userBio = "user_bio"
        case owner
        case userImage = "user_image"
        case postId = "post_id"
        case original
        case title
        case content
        case images
        case likes
        case level
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case bio
        case picture
        case school
        case country
        case campus
        case infoUpdated = "info_updated"
        case program
        case year
    }
}

struct UpdateUserRequest: Encodable {
    let id: String
    let name: String?
    let bio: String?
    let campus: String?
    let programme: String?  // Backend expects "programme" not "program"
    let year: Int?
    let picture: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bio
        case campus
        case programme
        case year
        case picture
        case country
    }
}

// Meetings

enum MeetingScope: String, CaseIterable, Identifiable {
    case upcoming
    case past
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .past: return "Past"
        case .all: return "All"
        }
    }
}

struct Meeting: Codable, Identifiable, Hashable {
    let id: String
    let creatorId: String
    let title: String
    let creatorName: String
    let creatorBio: String
    let courseId: String
    let createdAt: Date?
    let location: String
    let coordinates: String
    let startTime: Date
    let willAttend: [String]
    let chatId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator"
        case title
        case creatorName = "creator_name"
        case creatorBio = "creator_bio"
        case courseId = "course"
        case createdAt = "created_at"
        case location
        case coordinates
        case startTime = "start_time"
        case willAttend = "will_attend"
        case chatId = "chat_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        title = try container.decode(String.self, forKey: .title)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName) ?? ""
        creatorBio = try container.decodeIfPresent(String.self, forKey: .creatorBio) ?? ""
        courseId = try container.decodeIfPresent(String.self, forKey: .courseId) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        coordinates = try container.decodeIfPresent(String.self, forKey: .coordinates) ?? ""
        startTime = try container.decode(Date.self, forKey: .startTime)
        willAttend = try container.decodeIfPresent([String].self, forKey: .willAttend) ?? []
        chatId = try container.decodeIfPresent(String.self, forKey: .chatId)
    }

    init(
        id: String,
        creatorId: String,
        title: String,
        creatorName: String,
        creatorBio: String,
        courseId: String,
        createdAt: Date?,
        location: String,
        coordinates: String,
        startTime: Date,
        willAttend: [String],
        chatId: String? = nil
    ) {
        self.id = id
        self.creatorId = creatorId
        self.title = title
        self.creatorName = creatorName
        self.creatorBio = creatorBio
        self.courseId = courseId
        self.createdAt = createdAt
        self.location = location
        self.coordinates = coordinates
        self.startTime = startTime
        self.willAttend = willAttend
        self.chatId = chatId
    }

    var attendees: [MeetingAttendee] {
        willAttend.compactMap(MeetingAttendee.init(encoded:))
    }

    var attendeeCount: Int {
        attendees.count
    }

    var isUpcoming: Bool {
        startTime >= Date()
    }

    func isHosted(by userId: String) -> Bool {
        creatorId == userId
    }

    func isAttending(userId: String) -> Bool {
        attendees.contains(where: { $0.id == userId })
    }
}

struct MeetingAttendee: Identifiable, Hashable {
    let id: String
    let name: String
    let picture: String

    init?(encoded: String) {
        let pieces = encoded.components(separatedBy: "||")
        guard let id = pieces.first?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }

        self.id = id
        self.name = pieces.count > 1 ? pieces[1] : "Unknown attendee"
        self.picture = pieces.count > 2 ? pieces[2] : ""
    }

    var pictureURL: URL? {
        resolveAvatarURL(picture)
    }
}

struct CreateMeetingRequest: Encodable {
    let creatorId: String
    let title: String
    let creatorName: String
    let creatorBio: String
    let courseId: String
    let location: String
    let coordinates: String
    let startTime: Date

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator"
        case title
        case creatorName = "creator_name"
        case creatorBio = "creator_bio"
        case courseId = "course"
        case location
        case coordinates
        case startTime = "start_time"
    }
}

struct UpdateMeetingRequest: Encodable {
    let title: String?
    let courseId: String?
    let location: String?
    let startTime: Date?

    enum CodingKeys: String, CodingKey {
        case title
        case courseId = "course"
        case location
        case startTime = "start_time"
    }
}

struct MeetingRSVPRequest: Encodable {
    let userId: String
    let userName: String
    let userPicture: String
    let attending: Bool
}

struct MeetingRSVPResponse: Decodable {
    let meeting: Meeting
    let attending: Bool
    let attendeeCount: Int
}

private struct MeetingEnvelope: Decodable {
    let meeting: Meeting
}

// Universities & Courses
struct University: Codable, Identifiable {
    let id: String
    let name: String
    let active: Bool?
    let code: String?
    let country: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case active
        case code
        case country
        case createdAt = "created_at"
    }
}

private struct UniversitiesResponse: Decodable {
    let universities: [University]

    init(from decoder: Decoder) throws {
        if let raw = try? [University](from: decoder) {
            universities = raw
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try? container.decode([University].self, forKey: .data) {
            universities = data
        } else if let unis = try? container.decode([University].self, forKey: .universities) {
            universities = unis
        } else {
            universities = try container.decode([University].self, forKey: .items)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case universities
        case items
    }
}

struct Program: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let university: String
}

struct CampusSelection: Codable, Hashable {
    let id: String
    let name: String
}

struct Course: Codable, Identifiable {
    let id: String
    let name: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case id
        case name = "course_name"
        case code = "course_code"
    }
}

struct UserCoursesResponse: Codable {
    let id: String
    let list: [UserCourseItem]
}

private struct ProgramEnvelope: Decodable {
    let data: Program
}

private struct CampusEnvelope: Decodable {
    let data: CampusSelection
}

private struct MyProgramRequest: Encodable {
    let userId: String
    let program: Program

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case program
    }
}

private struct MyCampusRequest: Encodable {
    let userId: String
    let campus: CampusSelection

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case campus
    }
}

struct UserCourseItem: Codable {
    let courseCode: String
    let courseName: String
    let programName: String
    let year: Int
    
    enum CodingKeys: String, CodingKey {
        case courseCode = "course_code"
        case courseName = "course_name"
        case programName = "program_name"
        case year
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courseCode = try container.decode(String.self, forKey: .courseCode)
        courseName = try container.decode(String.self, forKey: .courseName)
        programName = try container.decodeIfPresent(String.self, forKey: .programName) ?? ""

        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .year),
                  let parsedYear = Int(yearString) {
            year = parsedYear
        } else {
            year = 1
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

struct BatchReplyLikesRequest: Encodable {
    let replyIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case replyIds = "reply_ids"
    }
}



struct AttachImagesRequest: Encodable {
    let images: [String]
}


struct PostStatsResponse: Codable {
    let stats: PostStats
}

struct PostStats: Codable {
    let likes: Int
    let replies: Int
}

// Device Tokens (FCM)
struct RegisterDeviceTokenRequest: Encodable {
    let userId: String
    let token: String
    let platform: String
    let deviceInfo: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
        case deviceInfo = "device_info"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(token, forKey: .token)
        try container.encode(platform, forKey: .platform)

        if let deviceInfo = deviceInfo {
            // Encode deviceInfo as a nested dictionary manually
            var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .deviceInfo)
            for (key, value) in deviceInfo {
                let codingKey = AnyCodingKey(stringValue: key)

                if let stringValue = value as? String {
                    try nestedContainer.encode(stringValue, forKey: codingKey)
                } else if let intValue = value as? Int {
                    try nestedContainer.encode(intValue, forKey: codingKey)
                } else if let doubleValue = value as? Double {
                    try nestedContainer.encode(doubleValue, forKey: codingKey)
                } else if let boolValue = value as? Bool {
                    try nestedContainer.encode(boolValue, forKey: codingKey)
                }
            }
        }
    }
}

// Helper for dynamic coding keys
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct DeviceTokenResponse: Codable {
    let success: Bool
    let message: String
    let id: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case id
        case createdAt = "created_at"
    }
}

// Likes
struct LikedPost: Codable, Identifiable {
    let id: String
    let up: Bool
    let excerpt: String?
    let postId: String
    let owner: String
    let userId: String
    let username: String
    let userPicture: String?
    let userBio: String?
    let targetType: Bool  // Backend uses 'target_type' not 'is_reply'
    let createdAt: Int64
    
    // Convenience accessor
    var isReply: Bool { targetType }
    
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case up
        case excerpt
        case postId = "post_id"
        case owner
        case userId = "user_id"
        case username
        case userPicture = "user_picture"
        case userBio = "user_bio"
        case targetType = "target_type"
        case createdAt = "created_at"
    }
}

struct LikesResponse: Codable {
    let likes: [LikedPost]
}

// Course Updates
struct UpdateCoursesRequest: Encodable {
    let list: [CourseUpdateItem]
}

struct CourseUpdateItem: Codable {
    let courseCode: String
    let courseName: String
    let programName: String
    let year: String
    
    enum CodingKeys: String, CodingKey {
        case courseCode = "course_code"
        case courseName = "course_name"
        case programName = "program_name"
        case year
    }
}


// MARK: - Typesense Search Models

struct TypesenseMultiSearchResponse: Codable {
    let posts: TypesenseSearchResponse?
    let users: TypesenseUserSearchResponse?
}

struct TypesenseSearchResponse: Codable {
    let hits: [TypesensePostHit]
    let found: Int
    let page: Int
}

struct TypesensePostHit: Codable, Identifiable {
    var id: String { document.id }
    let document: TypesensePostDocument
    let highlights: [TypesenseHighlight]?
    
    enum CodingKeys: String, CodingKey {
        case document
        case highlights
    }
}

struct TypesensePostDocument: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let subject: String
    let userId: String
    let username: String
    let userName: String?
    let userPicture: String
    let userBio: String
    let userCampus: String
    let userProgramme: String
    let userYear: Int
    let createdAt: Int64?
    let updatedAt: Int64?
    let images: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, subject, username, images
        case userId = "user_id"
        case userName = "user_name"
        case userPicture = "user_picture"
        case userBio = "user_bio"
        case userCampus = "user_campus"
        case userProgramme = "user_programme"
        case userYear = "user_year"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TypesenseHighlight: Codable {
    let field: String
    let snippet: String?
    let matchedTokens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case field, snippet
        case matchedTokens = "matched_tokens"
    }
}

struct TypesenseUserSearchResponse: Codable {
    let hits: [TypesenseUserHit]
    let found: Int
    let page: Int
}

struct TypesenseUserHit: Codable, Identifiable {
    var id: String { document.id }
    let document: TypesenseUserDocument
    let highlights: [TypesenseHighlight]?
}

struct TypesenseUserDocument: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let username: String?
    let bio: String?
    let picture: String?
    let campus: String?
    let program: String?
}
