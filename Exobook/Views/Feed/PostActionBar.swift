//
//  PostActionBar.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct PostActionBar: View {
    let post: Post
    let isBookmarked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onBookmark: () -> Void

    @Environment(\.currentUser) private var currentUser
    
    init(
        post: Post,
        isBookmarked: Bool,
        onLike: @escaping () -> Void,
        onComment: @escaping () -> Void,
        onBookmark: @escaping () -> Void
    ) {
        self.post = post
        self.isBookmarked = isBookmarked
        self.onLike = onLike
        self.onComment = onComment
        self.onBookmark = onBookmark
    }

    private var likeCount: Int {
        post.likeCount
    }

    private var commentCount: Int {
        post.commentCount
    }
    
    private var isLiked: Bool {
        guard let userId = currentUser?.id else { return false }
        return post.likes?.contains(userId) ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 20) {
                // Like button with animation
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .red : .primary)
                            .font(.system(size: 18))
                            .symbolEffect(.bounce, value: isLiked)
                        Text("\(likeCount)")
                            .font(.caption)
                            .fontWeight(isLiked ? .semibold : .regular)
                            .foregroundStyle(isLiked ? .red : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isLiked)
                
                // Comment button
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 18))
                        Text("\(commentCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Bookmark button with animation
                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? .blue : .primary)
                        .font(.system(size: 18))
                        .symbolEffect(.bounce, value: isBookmarked)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isBookmarked)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    // Create a Post instance using a JSON decoder for preview
    // This works around the custom init(from:) requirement
    func createPreviewPost() -> Post {
        let jsonString = """
        {
            "id": "1",
            "user_id": "user1",
            "username": "johndoe",
            "user_name": "John Doe",
            "user_bio": "Student",
            "user_campus": "Main Campus",
            "user_programme": "Computer Science",
            "user_year": 2,
            "user_picture": "avatar.jpg",
            "title": "Test Post",
            "content": "This is a test",
            "subject": "CS101",
            "images": [],
            "likes": ["1", "2", "3"],
            "comments": ["c1", "c2"],
            "created_at": "2024-01-13T10:00:00Z",
            "updated_at": "2024-01-13T10:00:00Z"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try! decoder.decode(Post.self, from: jsonData)
    }
    
    return PostActionBar(
        post: createPreviewPost(),
        isBookmarked: false,
        onLike: {},
        onComment: {},
        onBookmark: {}
    )
}
