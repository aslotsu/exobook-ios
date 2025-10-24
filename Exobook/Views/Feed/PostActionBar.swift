//
//  PostActionBar.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct PostActionBar: View {
    let post: Post
    let isLiked: Bool
    let isBookmarked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onBookmark: () -> Void
    let onShowComments: () -> Void
    let showingComments: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 20) {
                // Like button
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .primary)
                        Text("\(post.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Comment button
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(post.commentCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Show/Hide comments button
                Button(action: onShowComments) {
                    Text(showingComments ? "Hide Comments" : "Show Comments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Bookmark button
                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .blue : .primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    PostActionBar(
        post: Post(
            id: "1",
            userId: "user1",
            username: "johndoe",
            userName: "John Doe",
            userBio: "Student",
            userCampus: "Main Campus",
            userProgramme: "Computer Science",
            userYear: 2,
            userPicture: "avatar.jpg",
            title: "Test Post",
            content: "This is a test",
            subject: "CS101",
            images: [],
            likes: ["1", "2", "3"],
            comments: ["c1", "c2"],
            createdAt: Date(),
            updatedAt: Date()
        ),
        isLiked: false,
        isBookmarked: false,
        onLike: {},
        onComment: {},
        onBookmark: {},
        onShowComments: {},
        showingComments: false
    )
}
