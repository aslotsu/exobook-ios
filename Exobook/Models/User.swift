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
        
        // If picture is an SVG file, return nil to trigger CloudFront fallback
        if picture.lowercased().hasSuffix(".svg") {
            return nil
        }
        
        if picture.starts(with: "http") {
            return URL(string: picture)
        }
        // If path starts with /, it's a static asset from exobook.ca
        // But since we've already filtered out SVGs, this shouldn't happen anymore
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        picture = try container.decodeIfPresent(String.self, forKey: .picture)
        campus = try container.decodeIfPresent(String.self, forKey: .campus)
        program = try container.decodeIfPresent(String.self, forKey: .program)
        
        // Handle year as Int or String
        if let yearInt = try? container.decodeIfPresent(Int.self, forKey: .year) {
            year = yearInt
        } else if let yearString = try? container.decodeIfPresent(String.self, forKey: .year) {
            year = Int(yearString)
        } else {
            year = nil
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        // Safely decode courses
        if let coursesList = try? container.decodeIfPresent([UserCourse].self, forKey: .courses) {
            courses = coursesList
        } else {
            courses = nil
        }
    }
    
    // Memberwise initializer for manual creation
    init(
        id: String,
        email: String,
        name: String,
        username: String?,
        bio: String?,
        picture: String?,
        campus: String?,
        program: String?,
        year: Int?,
        courses: [UserCourse]?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.username = username
        self.bio = bio
        self.picture = picture
        self.campus = campus
        self.program = program
        self.year = year
        self.courses = courses
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        courseCode = try container.decode(String.self, forKey: .courseCode)
        courseName = try container.decode(String.self, forKey: .courseName)
        
        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .year), let y = Int(yearString) {
            year = y
        } else {
            // Default to 1 if missing or invalid, to prevent crash
            year = 1
        }
    }
    
    // Memberwise init
    init(id: String, name: String, courseCode: String, courseName: String, year: Int) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
        self.courseName = courseName
        self.year = year
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
