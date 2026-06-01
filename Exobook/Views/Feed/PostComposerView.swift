//
//  PostComposerView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI
import PhotosUI

struct PostComposerView: View {
    private enum ComposerMode: String, CaseIterable, Identifiable {
        case write = "Write"
        case preview = "Preview"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    @State private var title = ""
    @State private var content = ""
    @State private var isAnonymous = false
    @State private var isPosting = false
    @State private var error: String?
    
    // Photo Picker State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    // Course Selection State
    @State private var selectedCourse: String?
    @State private var mode: ComposerMode = .write
    
    let viewModel: FeedViewModel
    
    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCourse != nil
    }

    private var availableCourses: [String] {
        viewModel.userCourses.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Post")
                            .font(.title2.weight(.bold))
                        Text("Share a question, update, or resource with your course feed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Title input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                        
                        TextField("Descriptive title for your question (optional)", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }

                    Toggle(isOn: $isAnonymous) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Post anonymously")
                                .font(.headline)
                            Text("Your name and bio will not show on the post.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    // Content input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)

                        Picker("Composer Mode", selection: $mode) {
                            ForEach(ComposerMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        formattingToolbar

                        Group {
                            switch mode {
                            case .write:
                                TextEditor(text: $content)
                                    .frame(minHeight: 220)
                                    .padding(8)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(8)
                                    .font(.body)
                            case .preview:
                                ScrollView {
                                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Start writing to preview your formatted post.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(content.bridgedComposerHTML.htmlAttributedString(fontSize: 17))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .frame(minHeight: 220)
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }

                        Text("Supports headings, lists, quotes, bold, italic, inline code, and links.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Photo Picker
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 4, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Add images")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(selectedImages.count)/4")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        HStack {
                            Text("Course")
                                .font(.headline)

                            Spacer()

                            if let selectedCourse {
                                Text(selectedCourse)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if !availableCourses.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableCourses, id: \.self) { course in
                                        CourseChip(
                                            title: course,
                                            isSelected: selectedCourse == course,
                                            action: {
                                                selectedCourse = course
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 1)
                                .padding(.vertical, 2)
                            }
                        } else {
                            Text("No courses available yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if selectedCourse == nil {
                            Text("Please select a course to categorize your post.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
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
            .background(Color.appBackground)
            .navigationTitle("")
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

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                formatButton("H1") { insertSnippet("# ") }
                formatButton("H2") { insertSnippet("## ") }
                formatButton("Bold") { insertSnippet("**bold**") }
                formatButton("Italic") { insertSnippet("*italic*") }
                formatButton("List") { insertSnippet("- ") }
                formatButton("Quote") { insertSnippet("> ") }
                formatButton("Code") { insertSnippet("`code`") }
                formatButton("Link") { insertSnippet("[title](https://)") }
            }
            .padding(.vertical, 4)
        }
    }

    private func formatButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(Capsule())
    }

    private func insertSnippet(_ snippet: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            content = snippet
            return
        }

        if content.hasSuffix("\n") {
            content += snippet
        } else {
            content += "\n\(snippet)"
        }
    }
    
    private func postQuestion() {
        guard isValid, let user = currentUser, let selectedCourse else {
            print("❌ Post validation failed: isValid=\(isValid), currentUser=\(currentUser != nil)")
            if self.selectedCourse == nil {
                error = "Select a course before posting."
            } else if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                error = "Content is required."
            }
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
                    isAnonymous: isAnonymous,
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
                    .lineLimit(1)
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
            userId: User.mock.id,
            userName: User.mock.name,
            userPicture: User.mock.picture ?? "",
            userBio: User.mock.bio ?? "",
            year: User.mock.year ?? 1,
            courses: User.mock.courseCodes,
            campus: User.mock.campus ?? "Main Campus"
        )
    )
}
