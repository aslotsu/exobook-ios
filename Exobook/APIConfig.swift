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
    static let searchAPI = "https://search.exobook.ca"   // Search service
    static let search2API = "https://search2.exobook.ca" // Alternative search service
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
        case .search:
            baseURL = searchAPI
        case .search2:
            baseURL = search2API
        case .chat:
            baseURL = chatAPI
        }
        
        return URL(string: "\(baseURL)\(endpoint)")
    }
}

enum APIService {
    case main
    case likes
    case search
    case search2
    case chat
    // Add new services here
}
