//
//  PostDetailView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import SDWebImageSwiftUI
import PhotosUI

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
                    if !(post.images ?? []).isEmpty {
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
        .background(Color.appBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil, let user = currentUser {
                viewModel = PostDetailViewModel(post: post, currentUser: user)
                await viewModel?.loadComments()
            }
        }
    }
    
    // MARK: - Post Header
    
    private var postHeader: some View {
        HStack(spacing: 12) {
            // User Avatar
            ProfileImageView(imageURL: post.userAvatarURL, userName: post.userName ?? post.username, size: 44)
            
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
            
            Text(post.content.htmlAttributedString(fontSize: 17))
                .foregroundStyle(.primary)
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
            // Like Button with animation
            Button(action: {
                Task {
                    await viewModel.toggleLike()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.isLiked ? .red : .primary)
                        .font(.system(size: 20))
                        .symbolEffect(.bounce, value: viewModel.isLiked)
                    Text("\(viewModel.likeCount)")
                        .font(.subheadline)
                        .fontWeight(viewModel.isLiked ? .semibold : .regular)
                        .foregroundStyle(viewModel.isLiked ? .red : .secondary)
                }
            }
            .sensoryFeedback(.success, trigger: viewModel.isLiked)
            
            // Comment Count
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 20))
                Text("\(viewModel.commentCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
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
                    CommentRow(
                        comment: comment,
                        initialLikeCount: viewModel.replyLikeCounts[comment.id] ?? 0,
                        replyCount: viewModel.subReplyCounts[comment.id] ?? 0,
                        onReply: { reply in
                            viewModel.replyingTo = reply
                        }
                    )
                }
            }
            
            // Comment Input
            VStack(spacing: 0) {
                if let replyingTo = viewModel.replyingTo {
                    HStack {
                        Text("Replying to \(replyingTo.userName ?? "User")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.replyingTo = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                CommentInputView { commentText, images in
                    await viewModel.postComment(commentText, images: images)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
    
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Reply
    let initialLikeCount: Int
    let replyCount: Int
    let onReply: (Reply) -> Void
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var showReplies = false
    private let likesAPI = LikesAPIService()
    
    init(comment: Reply, initialLikeCount: Int = 0, replyCount: Int = 0, onReply: @escaping (Reply) -> Void = { _ in }) {
        self.comment = comment
        self.initialLikeCount = initialLikeCount
        self.replyCount = replyCount
        self.onReply = onReply
    }
    
    @Environment(\.currentUser) private var currentUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // User Avatar
                if let userImage = comment.userImage, let url = avatarURL(from: userImage) {
                    ProfileImageView(imageURL: url, userName: comment.userName ?? "User", size: 32)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(comment.userName ?? "User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(comment.content)
                        .font(.body)
                    
                    if let images = comment.images, !images.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(Array(images), id: \.self) { (imageId: String) in
                                let imageURL = resolveMediaURL(imageId)
                                WebImage(url: imageURL)
                                    .onSuccess { _, _, _ in
                                        print("✅ DEBUG: Loaded image: \(imageURL?.absoluteString ?? imageId)")
                                    }
                                    .onFailure { error in
                                        print("❌ DEBUG: Failed to load image: \(imageURL?.absoluteString ?? imageId), Error: \(error)")
                                    }
                                    .resizable()
                                    .indicator(.activity)
                                    .scaledToFill()
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.top, 4)
                        .onAppear {
                             print("📸 DEBUG: Comment \(comment.id) images: \(images)")
                        }
                    }
                    
                    HStack(spacing: 16) {
                        // Comment like button (Moved to start)
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 3) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(isLiked ? .red : .secondary)
                                    .font(.system(size: 12))
                                    .symbolEffect(.bounce, value: isLiked)
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.caption2)
                                        .fontWeight(isLiked ? .semibold : .regular)
                                        .foregroundStyle(isLiked ? .red : .secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: isLiked)
                        
                        // Reply button
                        Button(action: {
                            onReply(comment)
                        }) {
                            Text("Reply")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // Toggle Replies Button
                        Button(action: {
                            withAnimation {
                                showReplies.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .font(.caption2)
                                Text("\(replyCount) Replies")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // Time display (Moved to end)
                        Text(comment.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if showReplies {
                NestedCommentSection(parentCommentId: comment.id, onReply: onReply)
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            // Initialize like count from Redis data if available, otherwise fall back to comment data
            likeCount = initialLikeCount > 0 ? initialLikeCount : (comment.likes?.count ?? 0)
            
            // Initialize isLiked status
            if let user = currentUser, let likes = comment.likes {
                isLiked = likes.contains(user.id)
            }
        }
    }
    
    // Helper to convert user image string to URL
    private func avatarURL(from imageString: String) -> URL? {
        resolveAvatarURL(imageString)
    }

    private func toggleLike() {
        guard let userId = currentUser?.id else { return }

        let previousLiked = isLiked
        let previousCount = likeCount

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }

        Task {
            do {
                if previousLiked {
                    _ = try await likesAPI.unlikeComment(commentId: comment.id, userId: userId)
                } else {
                    _ = try await likesAPI.likeComment(
                        commentId: comment.id, userId: userId,
                        owner: comment.userId ?? userId,
                        username: currentUser?.name ?? "",
                        userPicture: currentUser?.picture ?? "",
                        userBio: currentUser?.bio ?? ""
                    )
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isLiked = previousLiked
                        likeCount = previousCount
                    }
                }
                print("[CommentRow] ❌ Failed to toggle reply like: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Comment Input

struct CommentInputView: View {
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    let onPost: (String, [UIImage]) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image Previews
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(2)
                            }
                        }
                    }
                }
                .frame(height: 70)
            }
            
            HStack(spacing: 12) {
                // Photo Picker
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: {
                    Task {
                        isPosting = true
                        await onPost(commentText, selectedImages)
                        commentText = ""
                        selectedImages = []
                        selectedItems = []
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
                .disabled((commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty) || isPosting)
            }
        }
        .padding(.top, 12)
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                selectedImages = images
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
class PostDetailViewModel {
    let post: Post
    let currentUser: User
    var currentUserId: String { currentUser.id }
    private let api = LinkioAPIService()
    private let likesAPI = LikesAPIService()
    private let cacheManager = StatsCacheManager.shared
    
    var comments: [Reply] = []
    var replyLikeCounts: [String: Int] = [:] // Store real-time like counts from Redis
    var subReplyCounts: [String: Int] = [:]  // Store real-time nested reply counts
    var replyingTo: Reply? // Track which comment is being replied to
    var isLoadingComments = false
    var isLiked = false
    var likeCount: Int
    var commentCount: Int
    
    init(post: Post, currentUser: User) {
        self.post = post
        self.currentUser = currentUser
        
        // Initialize from Cache if available
        if let stats = StatsCacheManager.shared.getPostStats(postId: post.id) {
            self.likeCount = stats.likeCount
            self.commentCount = stats.commentCount
            self.isLiked = stats.isLikedByCurrentUser
        } else {
            self.likeCount = post.likeCount
            self.commentCount = post.commentCount
            self.isLiked = post.likes?.contains(currentUser.id) ?? false
        }
    }
    
    func loadComments() async {
        isLoadingComments = true
        do {
            comments = try await api.getReplies(postId: post.id)
            commentCount = comments.count
            
            // Load real-time like counts and reply counts for these comments from Redis
            if !comments.isEmpty {
                let ids = comments.map { $0.id }
                async let likes = api.getBatchReplyLikeCounts(postId: post.id, replyIds: ids)
                async let replies = api.getBatchSubReplyCounts(postId: post.id, replyIds: ids)
                
                let (likesResult, repliesResult) = try await (likes, replies)
                replyLikeCounts = likesResult
                subReplyCounts = repliesResult
            }
            
            // Update cache with new comment count
            if let stats = cacheManager.getPostStats(postId: post.id) {
                cacheManager.cachePostStats(
                    postId: post.id,
                    likeCount: stats.likeCount,
                    commentCount: commentCount,
                    isLiked: stats.isLikedByCurrentUser
                )
            }
        } catch {
            print("Failed to load comments: \(error)")
        }
        isLoadingComments = false
    }
    
    func postComment(_ content: String, images: [UIImage] = []) async {
        do {
            // Determine parent info
            let originalId: String
            let ownerId: String
            let level: Int
            
            if let replyTo = replyingTo {
                originalId = replyTo.id
                ownerId = replyTo.userId
                level = (replyTo.level ?? 0) + 1
            } else {
                originalId = post.id
                ownerId = post.userId
                level = 0
            }
            
            // Construct request matching the web frontend format
            let request = CreateReplyRequest(
                userId: currentUser.id,
                userName: currentUser.name,
                userBio: currentUser.bio ?? "",
                userImage: currentUser.picture ?? "",
                owner: ownerId,
                original: originalId,
                postId: post.id,
                title: "",
                content: content,
                images: [],
                likes: [],
                level: level
            )
            
            // Create the comment
            var newComment = try await api.createReply(request)
            
            // Upload images and attach if any
            if !images.isEmpty {
                 let imagesData = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                 if !imagesData.isEmpty {
                     let fileIds = try await api.uploadImages(imagesData)
                     try await api.attachImagesToReply(replyId: newComment.id, imageIds: fileIds)
                     // Update local object to reflect images by creating a new instance (Reply props are immutable)
                     newComment = Reply(
                        id: newComment.id,
                        userId: newComment.userId,
                        userName: newComment.userName,
                        userBio: newComment.userBio,
                        owner: newComment.owner,
                        userImage: newComment.userImage,
                        postId: newComment.postId,
                        original: newComment.original,
                        title: newComment.title,
                        content: newComment.content,
                        images: fileIds,
                        likes: newComment.likes,
                        level: newComment.level,
                        createdAt: newComment.createdAt,
                        updatedAt: newComment.updatedAt
                     )
                 }
            }
            
            // Only append to local list if it's a top-level comment
            // Nested comments won't be visible until we implement nested UI or re-fetch
            if replyingTo == nil {
                // Ideally should fetch the real object or append a local version
                // For now, appending the newComment (with images attached)
                comments.append(newComment)
                commentCount = comments.count
            } else if let parent = replyingTo {
                 // Bump the parent's sub-reply counter in Redis (matches web behaviour).
                 await api.incrementSubReplyCount(parentReplyId: parent.id)
                 // Reload so the new nested reply becomes visible
                 await loadComments()
            }
            
            // Clear reply state
            replyingTo = nil
            
            // Update Redis comment count (matches web frontend behavior)
            try? await api.updateCommentCount(postId: post.id)
            
            // Update local cache
            cacheManager.updatePostCommentCount(postId: post.id, increment: true)
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
        
        // Sync to Cache immediately for Feed consistency
        cacheManager.updatePostLikeCount(postId: post.id, increment: isLiked, isLiked: isLiked)
        
        do {
            if isLiked {
                try await likesAPI.likePost(
                    postId: post.id, userId: currentUserId,
                    owner: post.userId, username: currentUser.name,
                    userPicture: currentUser.picture ?? "", userBio: currentUser.bio ?? ""
                )
            } else {
                try await likesAPI.unlikePost(postId: post.id, userId: currentUserId)
            }
        } catch {
            // Revert on error
            isLiked = previousState
            likeCount = previousCount
            // Revert Cache
            cacheManager.updatePostLikeCount(postId: post.id, increment: isLiked, isLiked: isLiked)
            print("Failed to toggle like: \(error)")
        }
    }
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
        } else if interval < 2419200 { // 4 weeks
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        } else if interval < 31536000 { // 1 year
            let months = Int(interval / 2628000)
            return "\(months)mo ago"
        } else {
            let years = Int(interval / 31536000)
            return "\(years)y ago"
        }
    }
}

#Preview {
    // Helper function to create a Post instance for preview using JSON decoding
    func createPreviewPost() -> Post {
        let jsonString = """
        {
            "id": "1",
            "user_id": "user1",
            "username": "johndoe",
            "user_name": "John Doe",
            "user_bio": "Student",
            "user_campus": "Main Campus",
            "user_programme": "CS",
            "user_year": 2,
            "user_picture": "",
            "title": "Sample Post",
            "content": "<p>This is a sample post</p>",
            "subject": "CS101",
            "images": [],
            "likes": [],
            "comments": [],
            "created_at": "2024-01-13T10:00:00Z",
            "updated_at": "2024-01-13T10:00:00Z"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try! decoder.decode(Post.self, from: jsonData)
    }
    
    return NavigationStack {
        PostDetailView(
            post: createPreviewPost()
        )
    }
}
