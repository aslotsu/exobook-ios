import SwiftUI
// MARK: - Nested Comments

// MARK: - Nested Comments

struct NestedCommentSection: View {
    let parentCommentId: String
    let onReply: (Reply) -> Void
    
    @State private var replies: [Reply] = []
    @State private var replyLikeCounts: [String: Int] = [:]
    @State private var subReplyCounts: [String: Int] = [:]
    @State private var isLoading = false
    @State private var hasLoaded = false
    private let api = LinkioAPIService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else if hasLoaded && replies.isEmpty {
                Text("No replies yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 4)
            } else {
                ForEach(replies) { reply in
                    // Recursive usage: CommentRow handles displaying this reply
                    // and will instantiate its own NestedCommentSection if expanded
                    CommentRow(
                        comment: reply,
                        initialLikeCount: replyLikeCounts[reply.id] ?? 0,
                        replyCount: subReplyCounts[reply.id] ?? 0,
                        onReply: onReply
                    )
                }
            }
        }
        .task {
            if !hasLoaded {
                await loadReplies()
            }
        }
    }
    
    func loadReplies() async {
        isLoading = true
        do {
            // 1. Fetch the replies
            // Using /api/replies/:id which correctly returns full user info
            replies = try await api.getNestedReplies(replyId: parentCommentId)
            
            // 2. Fetch stats for these replies if any exist
            if !replies.isEmpty {
                let ids = replies.map { $0.id }
                async let likes = api.getBatchReplyLikeCounts(postId: parentCommentId, replyIds: ids) // PostID param is just for namespacing in Redis if needed, or pass parentID
                async let replyCounts = api.getBatchSubReplyCounts(postId: parentCommentId, replyIds: ids)
                
                let (likesResult, replyCountsResult) = try await (likes, replyCounts)
                replyLikeCounts = likesResult
                subReplyCounts = replyCountsResult
            }
            
        } catch {
            print("Failed to load nested replies: \(error)")
        }
        isLoading = false
        hasLoaded = true
    }
}

