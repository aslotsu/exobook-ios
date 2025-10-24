//
//  APIConfig.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import Foundation

enum APIConfig {
    // Base URLs for different services
    static let baseAPI = "https://api.exobook.ca"        // exo-be (Go backend with Postgres)
    static let likesAPI = "https://likes.exobook.ca"     // dynamodb-go-api (DynamoDB likes service)
    static let usersSearchAPI = "https://users2.exobook.ca"   // Typesense users collection
    static let postsSearchAPI = "https://posts2.exobook.ca"   // Typesense posts collection
    static let chatAPI = "https://chats.exobook.ca"      // DynamoDB Chat Service (was localhost:9100)
    
    // Add new APIs here as needed
    // static let newServiceAPI = "https://newservice.exobook.ca"
    
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
