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
    private let searchURL = APIConfig.searchAPI
    
    func search(query: String) async throws -> SearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await network.get("\(searchURL)/api/search?q=\(encodedQuery)")
    }
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
    let highlights: [String: Highlight]?
    let textMatch: Int?
    
    var id: String { document.id }
    
    enum CodingKeys: String, CodingKey {
        case document
        case highlights
        case textMatch = "text_match"
    }
}

struct SearchDocument: Codable {
    let id: String
    let userId: String
    let userName: String
    let userBio: String?
    let userPicture: String
    let userCampus: String?
    let userProgramme: String?
    let title: String?
    let content: String?
    let subject: String?
    
    // Computed properties
    var isUserResult: Bool {
        title == nil && content == nil
    }
    
    var avatarURL: URL? {
        if userPicture.starts(with: "http") {
            return URL(string: userPicture)
        }
        return URL(string: "https://exobook.s3.amazonaws.com/\(userPicture)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
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
    let snippet: String
    let matchedTokens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case snippet
        case matchedTokens = "matched_tokens"
    }
}
