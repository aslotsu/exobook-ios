//
//  APIConfig.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import Foundation

enum APIConfig {
    // Base URLs for different services
    static let baseAPI = "https://api.linkio.ca"        // exo-be (Go backend with Postgres)
    static let likesAPI = "https://likes.linkio.ca"     // dynamodb-go-api (DynamoDB likes service)
    static let usersSearchAPI = "https://users2.linkio.ca"   // Typesense users collection
    static let postsSearchAPI = "https://posts2.linkio.ca"   // Typesense posts collection
    static let chatAPI = "https://chats.linkio.ca"      // DynamoDB Chat Service (prod)
    
    // Add new APIs here as needed
    // static let newServiceAPI = "https://newservice.linkio.ca"
    
    // Helper method to construct full URLs
    static func url(for service: APIService, endpoint: String) -> URL? {
        let baseURL: String
        
        switch service {
        case .main:
            baseURL = baseAPI
        case .likes:
            baseURL = likesAPI
        case .usersSearch:
            baseURL = usersSearchAPI
        case .postsSearch:
            baseURL = postsSearchAPI
        case .chat:
            baseURL = chatAPI
        }
        
        return URL(string: "\(baseURL)\(endpoint)")
    }
}

enum APIService {
    case main
    case likes
    case usersSearch
    case postsSearch
    case chat
    // Add new services here
}
