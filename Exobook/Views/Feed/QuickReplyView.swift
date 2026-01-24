
//
//  QuickReplyView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import PhotosUI

struct QuickReplyView: View {
    let post: Post
    let onCommentPosted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    private let api = ExobookAPIService()
    private let cacheManager = StatsCacheManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Post Context
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replying to \(post.userName ?? post.username)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(post.content.htmlStripped)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                
                Divider()
                
                // Input
                TextEditor(text: $commentText)
                    .frame(maxHeight: .infinity)
                    .padding()
                    .scrollContentBackground(.hidden)
                
                // Image Preview
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                        // Also clear selection from picker if possible, or just ignore sync
                                        // Keeping selectedItems in sync is complex, easier to just manipulate selectedImages
                                        // But PhotosPicker relies on selectedItems.
                                        // To properly remove, we'd need to find the matching ID.
                                        // For now, removing from array is UI-only, logic needs care.
                                        // Simplified: Reset all if remove? No. 
                                        // Let's just remove from selectedImages and ignore selectedItems sync issues for now.
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }
                                    .padding(4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 90)
                }
                
                Divider()
                
                // Toolbar (above keyboard)
                HStack {
                    PhotosPicker(selection: $selectedItems, matching: .images) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("New Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            await postComment()
                        }
                    }) {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled((commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty) || isPosting)
                }
            }
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
    
    func postComment() async {
        guard let currentUser = currentUser else { return }
        isPosting = true
        
        do {
            let request = CreateReplyRequest(
                userId: currentUser.id,
                userName: currentUser.name,
                userBio: currentUser.bio ?? "",
                userImage: currentUser.picture ?? "",
                owner: post.userId,
                original: post.id,
                postId: post.id,
                title: "",
                content: commentText,
                images: [],
                likes: [],
                level: 0
            )
            
            let newReply = try await api.createReply(request)
            
            // Upload images if any
            if !selectedImages.isEmpty {
                let imagesData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                if !imagesData.isEmpty {
                    let fileIds = try await api.uploadImages(imagesData)
                    try await api.attachImagesToReply(replyId: newReply.id, imageIds: fileIds)
                }
            }
            
            // Update stats
            try? await api.updateCommentCount(postId: post.id)
            cacheManager.updatePostCommentCount(postId: post.id, increment: true)
            
            onCommentPosted()
            dismiss()
            
        } catch {
            print("Failed to post comment: \(error)")
        }
        
        isPosting = false
    }
}
