//
//  ChatMembersView.swift
//  Exobook
//

import SwiftUI

struct ChatMembersView: View {
    let members: [ChatMember]
    let currentUserId: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(members) { member in
                    NavigationLink {
                        UserProfileView(userId: member.userId)
                    } label: {
                        HStack(spacing: 12) {
                            ProfileImageView(
                                imageURL: member.avatarURL,
                                userName: member.username,
                                size: 40
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(member.username)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if member.userId == currentUserId {
                                        Text("You")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemGray5))
                                            .clipShape(Capsule())
                                    }
                                }
                                if let bio = member.userBio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
