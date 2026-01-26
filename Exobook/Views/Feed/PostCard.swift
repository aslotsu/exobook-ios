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
    let currentUserId: String
    let isBookmarked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onBookmark: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    @State private var showingReplySheet = false
    @State private var showingMenu = false
    @State private var showingReportAlert = false
    
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
                if !(post.images ?? []).isEmpty {
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
                isBookmarked: isBookmarked,
                onLike: onLike,
                onComment: { showingReplySheet = true },
                onBookmark: onBookmark
            )
        }
        .background(adaptiveCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingReplySheet) {
            QuickReplyView(post: post, onCommentPosted: {
                // Optional: refresh logic if needed
            })
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMenu) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                Text("Post Options")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                Button(action: {
                    showingMenu = false
                    // Delay slightly to allow sheet to dismiss before showing alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onReport()
                        showingReportAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                        Text("Report Post")
                        Spacer()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                if post.userId == currentUserId {
                    Button(action: {
                        showingMenu = false
                        onDelete()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Delete Post")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding()
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .alert("Report Received", isPresented: $showingReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thanks for reporting this post. We will review it shortly.")
        }
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
            ProfileImageView(imageURL: post.userAvatarURL, userName: post.userName ?? post.username, size: 40)
            
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
                    .padding(16) // Increased clickable area
                    .contentShape(Rectangle()) // Ensure the whole padded area is tappable
            }
            .buttonStyle(.plain)
            .offset(x: 10, y: -10) // Move up and right
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
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
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
        // Simple HTML tag removal using regex - safe for any thread
        var result = self
        
        // Remove HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        
        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}

// MARK: - Preview

#Preview {
    // Helper function to create a Post instance for preview using JSON decoding
    func createPreviewPost() -> Post {
        let jsonString = """
        {
            "id": "1",
            "user_id": "user1",
            "username": "johndoe",
            "user_name": "John Doe",
            "user_bio": "Computer Science Student",
            "user_campus": "Main Campus",
            "user_programme": "Computer Science",
            "user_year": 2,
            "user_picture": "",
            "title": "How do I solve this algorithm problem?",
            "content": "I've been stuck on this for hours. Anyone know how to approach dynamic programming problems? I understand the concept but struggle with implementation.",
            "subject": "CS101",
            "images": [],
            "likes": ["1", "2", "3"],
            "comments": ["c1", "c2"],
            "created_at": "2024-01-13T09:00:00Z",
            "updated_at": "2024-01-13T10:00:00Z"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try! decoder.decode(Post.self, from: jsonData)
    }
    
    return ScrollView {
        VStack(spacing: 16) {
            PostCard(
                post: createPreviewPost(),
                currentUserId: "user1",
                isBookmarked: false,
                onLike: {},
                onComment: {},
                onBookmark: {},
                onDelete: {},
                onReport: {}
            )
            .padding()
        }
    }
}
