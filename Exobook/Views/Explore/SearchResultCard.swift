//
//  SearchResultCard.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct SearchResultCard: View {
    let hit: SearchHit
    
    var body: some View {
        if hit.document.isUserResult {
            UserSearchResult(hit: hit)
        } else {
            PostSearchResult(hit: hit)
        }
    }
}

// MARK: - User Search Result

struct UserSearchResult: View {
    let hit: SearchHit
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = hit.document.avatarURL {
                WebImage(url: avatarURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.document.userName)
                    .font(.headline)
                
                if let bio = hit.document.userBio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    if let campus = hit.document.userCampus {
                        Text(campus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let programme = hit.document.userProgramme {
                        if hit.document.userCampus != nil {
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        Text(programme)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Post Search Result

struct PostSearchResult: View {
    let hit: SearchHit
    
    var highlightSnippet: String? {
        hit.highlights?.values.first?.snippet
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 8) {
                if let avatarURL = hit.document.avatarURL {
                    WebImage(url: avatarURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.document.userName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let subject = hit.document.subject {
                        Text(subject)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Post content
            if let title = hit.document.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }
            
            // Highlight snippet
            if let snippet = highlightSnippet {
                Text(attributedSnippet(snippet))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else if let content = hit.document.content {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func attributedSnippet(_ snippet: String) -> AttributedString {
        // Remove HTML tags and return as AttributedString
        let cleanSnippet = snippet.replacingOccurrences(of: "<mark>", with: "")
            .replacingOccurrences(of: "</mark>", with: "")
        
        return AttributedString(cleanSnippet)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SearchResultCard(
            hit: SearchHit(
                document: SearchDocument(
                    id: "1",
                    userId: "user1",
                    userName: "John Doe",
                    userBio: "Computer Science Student",
                    userPicture: "https://via.placeholder.com/150",
                    userCampus: "Main Campus",
                    userProgramme: "CS",
                    title: nil,
                    content: nil,
                    subject: nil
                ),
                highlights: nil,
                textMatch: nil
            )
        )
        
        SearchResultCard(
            hit: SearchHit(
                document: SearchDocument(
                    id: "2",
                    userId: "user2",
                    userName: "Jane Smith",
                    userBio: "Engineering Student",
                    userPicture: "https://via.placeholder.com/150",
                    userCampus: "Main Campus",
                    userProgramme: "Engineering",
                    title: "How to solve algorithm problems?",
                    content: "I need help with dynamic programming",
                    subject: "CS101"
                ),
                highlights: nil,
                textMatch: nil
            )
        )
    }
    .padding()
}
