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
    let country: String?
    let campus: String?
    let program: String?  // Backend uses 'program' not 'programme'
    let year: Int?
    let infoUpdated: Bool?
    let courses: [UserCourse]?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Convenience accessor for programme
    var programme: String? { program }
    
    // Computed properties
    var avatarURL: URL? {
        resolveAvatarURL(picture)
    }
    
    var displayName: String {
        name.isEmpty ? email : name
    }
    
    
    var courseCodes: [String] {
        courses?.compactMap { course in
            let code = course.courseCode.isEmpty ? course.id : course.courseCode
            return code.isEmpty ? nil : code
        } ?? []
    }
    
    // Check if user needs to complete profile setup
    var needsProfileSetup: Bool {
        // country is NOT included — web never collects it during onboarding.
        let missingCoreFields =
            campus == nil || campus?.isEmpty == true ||
            program == nil || program?.isEmpty == true
        return infoUpdated != true || missingCoreFields
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case username
        case bio
        case picture
        case country
        case campus
        case program
        case year
        case infoUpdated = "info_updated"
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
        country = try container.decodeIfPresent(String.self, forKey: .country)
        campus = try container.decodeIfPresent(String.self, forKey: .campus)
        program = try container.decodeIfPresent(String.self, forKey: .program)
        infoUpdated = try container.decodeIfPresent(Bool.self, forKey: .infoUpdated)
        
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
        country: String?,
        campus: String?,
        program: String?,
        year: Int?,
        infoUpdated: Bool?,
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
        self.country = country
        self.campus = campus
        self.program = program
        self.year = year
        self.infoUpdated = infoUpdated
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

    private enum AltIDKeys: String, CodingKey {
        case courseIdSnake = "course_id"
        case courseIdCamel = "courseId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let altContainer = try decoder.container(keyedBy: AltIDKeys.self)

        // Mirror web's getCourseId: try id, course_id, courseId in order
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? altContainer.decode(String.self, forKey: .courseIdSnake))
            ?? (try? altContainer.decode(String.self, forKey: .courseIdCamel))
            ?? ""

        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName) ?? name

        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .year), let y = Int(yearString) {
            year = y
        } else {
            year = 0
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
        email: "test@linkio.ca",
        name: "Test User",
        username: "testuser",
        bio: "Test bio",
        picture: nil,
        country: "Canada",
        campus: "Main Campus",
        program: "Computer Science",
        year: 2,
        infoUpdated: true,
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
