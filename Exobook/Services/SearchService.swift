//
//  SearchService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

@MainActor
class SearchService {
    private let network = NetworkService.shared
    private let usersSearchURL = APIConfig.usersSearchAPI
    private let postsSearchURL = APIConfig.postsSearchAPI
    
    private var typesenseAPIKey: String {
        let key = ProcessInfo.processInfo.environment["TYPESENSE_API_KEY"] ?? ""
        if key.isEmpty {
            print("⚠️ TYPESENSE_API_KEY not set - search functionality will be limited")
        }
        return key
    }
    
    private var isSearchAvailable: Bool {
        !typesenseAPIKey.isEmpty
    }
    
    func search(query: String) async throws -> SearchResponse {
        // If API key is not available, return empty results instead of crashing
        guard isSearchAvailable else {
            print("⚠️ Search unavailable: TYPESENSE_API_KEY not configured")
            return SearchResponse(
                facetCounts: [],
                found: 0,
                outOf: 0,
                page: 1,
                requestParams: RequestParams(collectionName: "combined", perPage: 0, q: query),
                searchTimeMs: 0,
                hits: []
            )
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        let headers = ["x-typesense-api-key": typesenseAPIKey]
        
        // Query both endpoints concurrently using Typesense REST API
        async let usersTask: UsersSearchResponse? = {
            do {
                let result: UsersSearchResponse = try await network.get(
                    "\(usersSearchURL)/collections/users/documents/search?q=\(encodedQuery)&query_by=username,name,bio,email&per_page=10",
                    headers: headers
                )
                print("✅ Users search successful: \(result.found) results")
                return result
            } catch {
                print("❌ Users search failed: \(error)")
                return nil
            }
        }()
        
        async let postsTask: PostsSearchResponse? = {
            do {
                let result: PostsSearchResponse = try await network.get(
                    "\(postsSearchURL)/collections/posts/documents/search?q=\(encodedQuery)&query_by=title,content,subject&per_page=10",
                    headers: headers
                )
                print("✅ Posts search successful: \(result.found) results")
                return result
            } catch {
                print("❌ Posts search failed: \(error)")
                return nil
            }
        }()
        
        let (usersResponse, postsResponse) = await (usersTask, postsTask)
        
        // Combine results
        var allHits: [SearchHit] = []
        
        // Add user results
        if let usersResponse = usersResponse {
            allHits.append(contentsOf: usersResponse.hits)
        }
        
        // Add post results
        if let postsResponse = postsResponse {
            allHits.append(contentsOf: postsResponse.hits)
        }
        
        // Sort by text_match score (higher is better)
        allHits.sort { ($0.textMatch ?? 0) > ($1.textMatch ?? 0) }
        
        let totalFound = (usersResponse?.found ?? 0) + (postsResponse?.found ?? 0)
        let totalOutOf = (usersResponse?.outOf ?? 0) + (postsResponse?.outOf ?? 0)
        
        return SearchResponse(
            facetCounts: [],
            found: totalFound,
            outOf: totalOutOf,
            page: 1,
            requestParams: RequestParams(collectionName: "combined", perPage: allHits.count, q: query),
            searchTimeMs: 0,
            hits: allHits
        )
    }
}

// Separate response types for each collection
private struct UsersSearchResponse: Codable {
    let found: Int
    let outOf: Int
    let hits: [SearchHit]
}

private struct PostsSearchResponse: Codable {
    let found: Int
    let outOf: Int
    let hits: [SearchHit]
}

// MARK: - Models

struct SearchResponse: Codable {
    let facetCounts: [FacetCount]
    let found: Int
    let outOf: Int
    let page: Int
    let requestParams: RequestParams
    let searchTimeMs: Int
    let hits: [SearchHit]
    
    enum CodingKeys: String, CodingKey {
        case facetCounts = "facet_counts"
        case found
        case outOf = "out_of"
        case page
        case requestParams = "request_params"
        case searchTimeMs = "search_time_ms"
        case hits
    }
}

struct FacetCount: Codable {
    // Add fields as needed
}

struct RequestParams: Codable {
    let collectionName: String
    let perPage: Int
    let q: String
    
    enum CodingKeys: String, CodingKey {
        case collectionName = "collection_name"
        case perPage = "per_page"
        case q
    }
}

struct SearchHit: Codable, Identifiable {
    let document: SearchDocument
    let highlights: [Highlight]?  // Array, not dictionary
    let textMatch: Int?
    
    var id: String { document.id }
    
    // Helper to get first highlight snippet
    var highlightSnippet: String? {
        highlights?.first?.snippet
    }
    
    enum CodingKeys: String, CodingKey {
        case document
        case highlights
        case textMatch = "text_match"
    }
}

struct SearchDocument: Codable {
    let id: String
    // User document fields
    let name: String?
    let username: String?
    let bio: String?
    let picture: String?
    let campus: String?
    let program: String?
    // Post document fields
    let userId: String?
    let userName: String?
    let userBio: String?
    let userPicture: String?
    let userCampus: String?
    let userProgramme: String?
    let title: String?
    let content: String?
    let subject: String?
    
    // Computed properties that work for both user and post documents
    var isUserResult: Bool {
        // If it has name field (user doc) OR missing post-specific fields
        name != nil || (title == nil && content == nil && userName == nil)
    }
    
    var displayName: String {
        // For user documents, use name or username
        if let name = name, !name.isEmpty {
            return name
        }
        if let username = username, !username.isEmpty {
            return username
        }
        // For post documents, use userName
        return userName ?? "Unknown"
    }
    
    var displayBio: String? {
        bio ?? userBio
    }
    
    var displayCampus: String? {
        campus ?? userCampus
    }
    
    var displayProgramme: String? {
        program ?? userProgramme
    }
    
    var avatarURL: URL? {
        let pictureString = picture ?? userPicture ?? ""
        if pictureString.starts(with: "http") {
            return URL(string: pictureString)
        }
        if pictureString.starts(with: "/") {
            return URL(string: "https://exobook.ca\(pictureString)")
        }
        if !pictureString.isEmpty {
            return URL(string: "https://exobook.amazonaws.com/\(pictureString)")
        }
        return nil
    }
    
    // Convert search document to Post for navigation
    func toPost() -> Post? {
        guard let userId = userId,
              let userName = userName,
              let userPicture = userPicture,
              let content = content ?? title,
              let subject = subject
        else { return nil }
        
        // Create a Post instance using JSON decoding to work around custom init(from:)
        let postDict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "username": userName,
            "user_name": userName,
            "user_bio": userBio ?? "",
            "user_campus": userCampus ?? "",
            "user_programme": userProgramme ?? "",
            "user_year": 0,
            "user_picture": userPicture,
            "title": title ?? "",
            "content": content,
            "subject": subject,
            "images": [],
            "likes": [],
            "comments": [],
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postDict) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Post.self, from: jsonData)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        // User fields
        case name
        case username
        case bio
        case picture
        case campus
        case program
        // Post fields
        case userId = "user_id"
        case userName = "user_name"
        case userBio = "user_bio"
        case userPicture = "user_picture"
        case userCampus = "user_campus"
        case userProgramme = "user_programme"
        case title
        case content
        case subject
    }
}

struct Highlight: Codable {
    let field: String
    let snippet: String
    let matchedTokens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case field
        case snippet
        case matchedTokens = "matched_tokens"
    }
}
