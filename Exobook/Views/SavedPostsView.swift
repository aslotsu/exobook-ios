
//
//  SavedPostsView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct SavedPostsView: View {
    @Environment(\.currentUser) private var currentUser
    
    var body: some View {
        List {
            ForEach(createPlaceholderPosts()) { post in
                ZStack {
                    PostCard(
                        post: post,
                        currentUserId: currentUser?.id ?? "",
                        isBookmarked: true,
                        onLike: {},
                        onComment: {},
                        onBookmark: {},
                        onDelete: {},
                        onReport: {}
                    )
                    
                    NavigationLink(destination: PostDetailView(post: post)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func createPlaceholderPosts() -> [Post] {
        let jsonString = """
        [
            {
                "id": "saved1",
                "user_id": "u1",
                "username": "jane_doe",
                "user_name": "Jane Doe",
                "user_bio": "CS Student",
                "user_campus": "Main Campus",
                "user_programme": "Computer Science",
                "user_year": 3,
                "user_picture": "",
                "title": "Best study spots on campus?",
                "content": "I usually go to the library but it's been so crowded lately. Does anyone know of any quiet study spots with power outlets?",
                "subject": "General",
                "images": [],
                "likes": ["u2"],
                "comments": [],
                "created_at": "2025-10-20T10:00:00Z",
                "updated_at": "2025-10-20T10:00:00Z"
            },
            {
                "id": "saved2",
                "user_id": "u2",
                "username": "alex_smith",
                "user_name": "Alex Smith",
                "user_bio": "Engineering",
                "user_campus": "West Campus",
                "user_programme": "Mechanical Engineering",
                "user_year": 2,
                "user_picture": "",
                "title": "Notes for MECH 201",
                "content": "Here are my notes for the midterm. Hope they help!",
                "subject": "MECH201",
                "images": [],
                "likes": ["u1", "u3"],
                "comments": ["c1"],
                "created_at": "2025-10-18T14:30:00Z",
                "updated_at": "2025-10-18T14:30:00Z"
            },
            {
                "id": "saved3",
                "user_id": "u3",
                "username": "sarah_p",
                "user_name": "Sarah P",
                "user_bio": "Arts",
                "user_campus": "Downtown",
                "user_programme": "History",
                "user_year": 4,
                "user_picture": "",
                "title": "Reminder: Club Fair tomorrow!",
                "content": "Don't forget the club fair is happening tomorrow in the quad from 10am to 4pm. Come check out the History Club!",
                "subject": "Events",
                "images": [],
                "likes": ["u1", "u2", "u4", "u5"],
                "comments": [],
                "created_at": "2025-10-23T09:00:00Z",
                "updated_at": "2025-10-23T09:00:00Z"
            }
        ]
        """
        
        guard let data = jsonString.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode([Post].self, from: data)
        } catch {
            print("Failed to decode placeholder posts: \(error)")
            return []
        }
    }
}

#Preview {
    NavigationStack {
        SavedPostsView()
    }
}
