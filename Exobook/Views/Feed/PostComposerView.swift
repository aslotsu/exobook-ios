//
//  PostComposerView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct PostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var isPosting = false
    @State private var error: String?
    
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
                    
                    // Image picker placeholder
                    Button(action: {
                        // TODO: Implement image picker
                        print("Open image picker")
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Add Images")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
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
                    .disabled(!isValid || isPosting)
                }
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color(uiColor: .systemBackground)
    }
    
    private func postQuestion() {
        guard isValid else { return }
        
        isPosting = true
        error = nil
        
        Task {
            do {
                try await viewModel.createPost(
                    title: title,
                    content: content,
                    images: []
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isPosting = false
                }
            }
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
