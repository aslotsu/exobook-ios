//
//  User.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let username: String?
    let bio: String?
    let picture: String?
    let campus: String?
    let program: String?  // Backend uses 'program' not 'programme'
    let year: Int?
    let courses: [UserCourse]?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Convenience accessor for programme
    var programme: String? { program }
    
    // Computed properties
    var avatarURL: URL? {
        guard let picture = picture else { return nil }
        if picture.starts(with: "http") {
            return URL(string: picture)
        }
        // If path starts with /, it's a static asset from exobook.ca
        if picture.starts(with: "/") {
            return URL(string: "https://exobook.ca\(picture)")
        }
        // Otherwise it's from S3
        return URL(string: "https://exobook.s3.amazonaws.com/\(picture)")
    }
    
    var displayName: String {
        name.isEmpty ? email : name
    }
    
    var courseCodes: [String] {
        courses?.map { $0.courseCode } ?? []
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case username
        case bio
        case picture
        case campus
        case program
        case year
        case courses
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserCourse: Codable, Identifiable {
    let id: String
    let name: String
    let courseCode: String
    let courseName: String
    let year: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode = "course_code"
        case courseName = "course_name"
        case year
    }
}

// MARK: - Mock User for Development

extension User {
    static let mock = User(
        id: "test-user-id",
        email: "test@exobook.ca",
        name: "Test User",
        username: "testuser",
        bio: "Test bio",
        picture: nil,
        campus: "Main Campus",
        program: "Computer Science",
        year: 2,
        courses: [
            UserCourse(
                id: "1",
                name: "Intro to CS",
                courseCode: "CS101",
                courseName: "Introduction to Computer Science",
                year: 1
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
}
