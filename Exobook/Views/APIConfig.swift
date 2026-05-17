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
    static let notificationsAPI = likesAPI               // dynamodb-go-api also serves /api/notifs/*
    static let friendsAPI = "https://friends.exobook.ca/api" // friends service (matches web friendsUrl)
    static let usersSearchAPI = "https://users2.exobook.ca"   // Typesense users collection
    static let postsSearchAPI = "https://posts2.exobook.ca"   // Typesense posts collection
    static let chatAPI = "https://mchats.exobook.ca/api"      // Mongo Chat Service (matches web chatUrl)

    // Pusher credentials are sourced from PusherConfig (env-driven).
    // Re-exported here for sites that already imported APIConfig.
    static var pusherKey: String { PusherConfig.key }
    static var pusherCluster: String { PusherConfig.cluster }

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
        case .friends:
            baseURL = friendsAPI
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
    case friends
    // Add new services here
}
