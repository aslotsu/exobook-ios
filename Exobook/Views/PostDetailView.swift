//
//  PostDetailView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct PostDetailView: View {
    let post: Post
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: PostDetailViewModel?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let viewModel = viewModel {
                    // Post Header
                    postHeader
                    
                    // Post Content
                    postContent
                    
                    // Post Images
                    if !post.images.isEmpty {
                        postImages
                    }
                    
                    // Action Buttons
                    actionButtons(viewModel: viewModel)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Comments Section
                    commentsSection(viewModel: viewModel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .background(adaptiveBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil, let user = currentUser {
                viewModel = PostDetailViewModel(post: post, currentUserId: user.id)
                await viewModel?.loadComments()
            }
        }
    }
    
    // MARK: - Post Header
    
    private var postHeader: some View {
        HStack(spacing: 12) {
            // User Avatar
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.userName ?? post.username)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text(post.subject)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Text("• \(post.createdAt.timeAgoDisplay())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Post Content
    
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !post.title.isEmpty {
                Text(post.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(stripHTML(from: post.content))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Post Images
    
    private var postImages: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(post.imageURLs, id: \.self) { imageURL in
                    WebImage(url: imageURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 200)
                        .clipped()
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private func actionButtons(viewModel: PostDetailViewModel) -> some View {
        HStack(spacing: 24) {
            // Like Button
            Button(action: {
                Task {
                    await viewModel.toggleLike()
                }
            }) {
                Label("\(viewModel.likeCount)", systemImage: viewModel.isLiked ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.isLiked ? .red : .primary)
            }
            
            // Comment Count
            Label("\(viewModel.commentCount)", systemImage: "bubble.right")
                .foregroundColor(.primary)
            
            Spacer()
        }
        .font(.subheadline)
    }
    
    // MARK: - Comments Section
    
    private func commentsSection(viewModel: PostDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comments")
                .font(.headline)
            
            if viewModel.isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet. Be the first to comment!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.comments) { comment in
                    CommentRow(comment: comment)
                }
            }
            
            // Comment Input
            CommentInputView { commentText in
                await viewModel.postComment(commentText)
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Reply
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("User") // TODO: Add user info to Reply model
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(comment.content)
                        .font(.body)
                    
                    Text(comment.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Comment Input

struct CommentInputView: View {
    @State private var commentText = ""
    @State private var isPosting = false
    let onPost: (String) async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a comment...", text: $commentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            
            Button(action: {
                guard !commentText.isEmpty else { return }
                Task {
                    isPosting = true
                    await onPost(commentText)
                    commentText = ""
                    isPosting = false
                }
            }) {
                if isPosting {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
            }
            .disabled(commentText.isEmpty || isPosting)
        }
        .padding(.top, 12)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
class PostDetailViewModel {
    let post: Post
    let currentUserId: String
    private let api = ExobookAPIService()
    private let likesAPI = LikesAPIService()
    
    var comments: [Reply] = []
    var isLoadingComments = false
    var isLiked = false
    var likeCount: Int
    var commentCount: Int
    
    init(post: Post, currentUserId: String) {
        self.post = post
        self.currentUserId = currentUserId
        self.likeCount = post.likeCount
        self.commentCount = post.commentCount
    }
    
    func loadComments() async {
        isLoadingComments = true
        do {
            comments = try await api.getReplies(postId: post.id)
            commentCount = comments.count
            
            // Check if user liked the post
            // TODO: Implement check like status API
            isLiked = false
        } catch {
            print("Failed to load comments: \(error)")
        }
        isLoadingComments = false
    }
    
    func postComment(_ content: String) async {
        do {
            let request = CreateReplyRequest(
                postId: post.id,
                userId: currentUserId,
                content: content
            )
            let newComment = try await api.createReply(request)
            comments.append(newComment)
            commentCount = comments.count
        } catch {
            print("Failed to post comment: \(error)")
        }
    }
    
    func toggleLike() async {
        let previousState = isLiked
        let previousCount = likeCount
        
        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        do {
            if isLiked {
                try await likesAPI.likePost(postId: post.id, userId: currentUserId)
            } else {
                try await likesAPI.unlikePost(postId: post.id, userId: currentUserId)
            }
        } catch {
            // Revert on error
            isLiked = previousState
            likeCount = previousCount
            print("Failed to toggle like: \(error)")
        }
    }
}

// MARK: - Helper Functions

private func stripHTML(from string: String) -> String {
    string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(
            post: Post(
                id: "1",
                userId: "user1",
                username: "johndoe",
                userName: "John Doe",
                userBio: "Student",
                userCampus: "Main Campus",
                userProgramme: "CS",
                userYear: 2,
                userPicture: "/dark-profile-photo.svg",
                title: "Sample Post",
                content: "<p>This is a sample post</p>",
                subject: "CS101",
                images: [],
                likes: [],
                comments: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
