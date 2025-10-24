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
            // Header with user info and timestamp
            PostHeader(post: post, showingMenu: $showingMenu)
            
            // Post content
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(post.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Content
                Text(post.content)
                    .font(.body)
                    .lineLimit(nil)
                
                // Images grid
                if !post.images.isEmpty {
                    PostImagesGrid(imageURLs: post.imageURLs)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
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
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(post.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Text(post.userCampus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(post.userProgramme)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Year \(post.userYear)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Timestamp and menu
            VStack(alignment: .trailing, spacing: 4) {
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(action: { showingMenu.toggle() }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
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
