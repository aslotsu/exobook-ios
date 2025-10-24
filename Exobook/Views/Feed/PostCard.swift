//
//  PostCard.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct PostCard: View {
    let post: Post
    let isLiked: Bool
    let isBookmarked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onBookmark: () -> Void
    @State private var showingComments = false
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            PostHeader(post: post, showingMenu: $showingMenu)
            
            // Post content
            VStack(alignment: .leading, spacing: 10) {
                // Title (only show if not empty)
                if !post.title.isEmpty {
                    Text(post.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // Content - strip HTML and show plain text
                Text(post.content.htmlStripped)
                    .font(.body)
                    .lineLimit(8)
                
                // Images grid
                if !post.images.isEmpty {
                    PostImagesGrid(imageURLs: post.imageURLs)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Action bar
            PostActionBar(
                post: post,
                isLiked: isLiked,
                isBookmarked: isBookmarked,
                onLike: onLike,
                onComment: onComment,
                onBookmark: onBookmark,
                onShowComments: { showingComments.toggle() },
                showingComments: showingComments
            )
        }
        .background(adaptiveCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
}

// MARK: - PostHeader

struct PostHeader: View {
    let post: Post
    @Binding var showingMenu: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            if let avatarURL = post.userAvatarURL {
                WebImage(url: avatarURL)
                    .resizable()
                    .indicator(.activity)
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text((post.userName ?? post.username).prefix(1).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    )
            }
            
            // User info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(post.userName ?? post.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(post.subject)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Menu button
            Button(action: { showingMenu.toggle() }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - PostImagesGrid

struct PostImagesGrid: View {
    let imageURLs: [URL]
    
    var columns: [GridItem] {
        switch imageURLs.count {
        case 1:
            return [GridItem(.flexible())]
        case 2:
            return [GridItem(.flexible()), GridItem(.flexible())]
        default:
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(imageURLs, id: \.self) { url in
                WebImage(url: url)
                    .resizable()
                    .scaledToFill()
                    .frame(height: imageURLs.count == 1 ? 300 : 150)
                    .clipped()
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview

// MARK: - String Extension

extension String {
    var htmlStripped: String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }
        
        return attributedString.string
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            PostCard(
                post: Post(
                    id: "1",
                    userId: "user1",
                    username: "johndoe",
                    userName: "John Doe",
                    userBio: "Computer Science Student",
                    userCampus: "Main Campus",
                    userProgramme: "Computer Science",
                    userYear: 2,
                    userPicture: "https://via.placeholder.com/150",
                    title: "How do I solve this algorithm problem?",
                    content: "I've been stuck on this for hours. Anyone know how to approach dynamic programming problems? I understand the concept but struggle with implementation.",
                    subject: "CS101",
                    images: [],
                    likes: ["1", "2", "3"],
                    comments: ["c1", "c2"],
                    createdAt: Date().addingTimeInterval(-3600),
                    updatedAt: Date()
                ),
                isLiked: false,
                isBookmarked: false,
                onLike: {},
                onComment: {},
                onBookmark: {}
            )
            .padding()
        }
    }
}
