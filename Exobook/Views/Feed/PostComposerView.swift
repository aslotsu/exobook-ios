//
//  PostComposerView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import PhotosUI

struct PostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    @State private var title = ""
    @State private var content = ""
    @State private var isPosting = false
    @State private var error: String?
    
    // Photo Picker State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    
    // Course Selection State
    @State private var selectedCourse: String?
    
    let viewModel: FeedViewModel
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                        
                        TextField("Descriptive title for your question", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    
                    // Content input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                            .font(.body)
                    }
                    
                    // Photo Picker
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 4, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Add Images (up to 4)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedItems) { oldItems, newItems in
                        Task {
                            await loadImages(from: newItems)
                        }
                    }
                    
                    // Selected images preview
                    if !selectedImages.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                                    .overlay(alignment: .topTrailing) {
                                        Button(action: {
                                            removeSelectedImage(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Course Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Course")
                            .font(.headline)
                        
                        if let userCourses = currentUser?.courseCodes, !userCourses.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(userCourses, id: \.self) { course in
                                    CourseChip(
                                        title: course,
                                        isSelected: selectedCourse == course,
                                        action: {
                                            selectedCourse = course
                                        }
                                    )
                                }
                            }
                        } else {
                            Text("No courses available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Error message
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(adaptiveBackground)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: postQuestion) {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isPosting || currentUser == nil)
                }
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
    
    private func postQuestion() {
        guard isValid, let user = currentUser else {
            print("❌ Post validation failed: isValid=\(isValid), currentUser=\(currentUser != nil)")
            return
        }
        
        print("📝 Creating post for user: id='\(user.id)', name='\(user.name)'")
        
        isPosting = true
        error = nil
        
        // Convert images to Data
        let imageData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        Task {
            do {
                try await viewModel.createPost(
                    user: user,
                    title: title,
                    content: content,
                    subject: selectedCourse,
                    images: imageData
                )
                
                print("✅ Post created successfully")
                
                // Dismiss the sheet on success (201 Created or 200 OK)
                dismiss()
            } catch {
                print("❌ Failed to create post: \(error)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    isPosting = false
                }
            }
        }
    }
    
    // MARK: - Image Picker Methods
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
        
        for item in items {
            do {
                // Try to load the image data
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    continue
                }
                
                // Create UIImage from the data
                guard let uiImage = UIImage(data: data) else {
                    continue
                }
                
                loadedImages.append(uiImage)
            } catch {
                print("Error loading image: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            selectedImages = loadedImages
        }
    }
    
    private func removeSelectedImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        
        // Also remove the corresponding PhotosPickerItem if possible
        if index < selectedItems.count {
            selectedItems.remove(at: index)
        }
    }
}

// MARK: - Course Chip Component

struct CourseChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.blue
                    : Color(uiColor: .secondarySystemBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

#Preview {
    PostComposerView(
        viewModel: FeedViewModel(
            userId: "test-user",
            year: 2,
            courses: ["CS101"],
            campus: "Main Campus"
        )
    )
}
