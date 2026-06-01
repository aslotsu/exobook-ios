//
//  GroupDetailView.swift
//

import SwiftUI

struct GroupDetailView: View {
    let group: CommunityGroup
    @Bindable var viewModel: GroupsViewModel
    @Environment(\.currentUser) private var currentUser

    var isMember: Bool { viewModel.isMember(of: group) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                    }
                    Text(group.name).font(.title2.bold())
                    Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let desc = group.description {
                        Text(desc)
                            .font(.body).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                if let currentUser {
                    if isMember {
                        Button(role: .destructive) {
                            Task { await viewModel.leaveGroup(group, userId: currentUser.id) }
                        } label: {
                            Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).padding(.horizontal)
                    } else {
                        Button {
                            Task { await viewModel.joinGroup(group, userId: currentUser.id) }
                        } label: {
                            Label("Join Group", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).padding(.horizontal)
                    }
                }

                if let err = viewModel.error {
                    Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
