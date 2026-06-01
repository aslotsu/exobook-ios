//
//  MeetingsView.swift
//  Exobook
//
//  Created by OpenAI Codex on 27/05/2026.
//

import SwiftUI

struct MeetingsView: View {
    @Environment(\.currentUser) private var currentUser
    @State private var viewModel: MeetingsViewModel?
    @State private var showingComposer = false

    var body: some View {
        Group {
            if let currentUser {
                if let viewModel {
                    meetingsContent(viewModel: viewModel, currentUser: currentUser)
                } else {
                    ProgressView("Loading meetings...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            guard viewModel == nil else { return }
                            let newViewModel = MeetingsViewModel(user: currentUser)
                            self.viewModel = newViewModel
                            await newViewModel.loadMeetings()
                        }
                }
            } else {
                ContentUnavailableView("User Not Found", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .navigationTitle("Meetings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func meetingsContent(viewModel: MeetingsViewModel, currentUser: User) -> some View {
        @Bindable var vm = viewModel

        List {
            Section {
                Picker("Meeting scope", selection: $vm.scope) {
                    ForEach(MeetingScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
            }

            if vm.availableCourses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Courses Available",
                        systemImage: "books.vertical",
                        description: Text("Add courses to your profile before using meetings.")
                    )
                }
            } else if vm.isLoading && vm.meetings.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading meetings...")
                        Spacer()
                    }
                }
            } else if let errorMessage = vm.errorMessage, vm.meetings.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await vm.loadMeetings() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
            } else if vm.meetings.isEmpty {
                Section {
                    ContentUnavailableView(
                        emptyTitle(for: vm.scope),
                        systemImage: vm.scope == .past ? "clock.arrow.circlepath" : "calendar.badge.plus",
                        description: Text(emptyDescription(for: vm.scope))
                    )
                }
            } else {
                Section {
                    ForEach(vm.meetings) { meeting in
                        NavigationLink {
                            MeetingDetailView(
                                meetingID: meeting.id,
                                onChanged: { updatedMeeting in
                                    vm.upsert(updatedMeeting)
                                },
                                onDeleted: { meetingId in
                                    vm.remove(meetingId: meetingId)
                                }
                            )
                        } label: {
                            MeetingRow(meeting: meeting, currentUserId: currentUser.id)
                        }
                    }
                } header: {
                    Text("\(vm.meetings.count) meeting\(vm.meetings.count == 1 ? "" : "s")")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .refreshable {
            await vm.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingComposer = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.availableCourses.isEmpty)
            }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                MeetingEditorView(
                    user: currentUser,
                    availableCourses: vm.availableCourses
                ) { createdMeeting in
                    vm.upsert(createdMeeting)
                }
            }
        }
    }

    private func emptyTitle(for scope: MeetingScope) -> String {
        switch scope {
        case .upcoming: return "No Upcoming Meetings"
        case .past: return "No Past Meetings"
        case .all: return "No Meetings Yet"
        }
    }

    private func emptyDescription(for scope: MeetingScope) -> String {
        switch scope {
        case .upcoming:
            return "Create a study session for one of your courses."
        case .past:
            return "Past meetings will appear here once sessions have happened."
        case .all:
            return "Meetings created for your courses will appear here."
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let currentUserId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(meeting.courseId)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                Spacer()

                meetingStatusBadge
            }

            Label(meeting.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !meeting.location.isEmpty {
                Label(meeting.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label("\(meeting.attendeeCount)", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if meeting.isHosted(by: currentUserId) {
                    badge(title: "Hosting", tint: .orange)
                } else if meeting.isAttending(userId: currentUserId) {
                    badge(title: "RSVP'd", tint: .green)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var meetingStatusBadge: some View {
        Text(meeting.isUpcoming ? "Upcoming" : "Past")
            .font(.caption.weight(.semibold))
            .foregroundColor(meeting.isUpcoming ? .green : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((meeting.isUpcoming ? Color.green : Color.gray).opacity(0.14))
            .clipShape(Capsule())
    }

    private func badge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct MeetingDetailView: View {
    let meetingID: String
    let onChanged: (Meeting) -> Void
    let onDeleted: (String) -> Void

    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss

    @State private var meeting: Meeting?
    @State private var isLoading = true
    @State private var isRSVPLoading = false
    @State private var isChatRepairLoading = false
    @State private var isDeleteLoading = false
    @State private var errorMessage: String?
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading meeting...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let meeting {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleSection(meeting: meeting)
                        metadataSection(meeting: meeting)
                        hostSection(meeting: meeting)
                        attendeesSection(meeting: meeting)
                    }
                    .padding()
                }
                .background(Color.appBackground)
            } else {
                ContentUnavailableView(
                    "Meeting Unavailable",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(errorMessage ?? "This meeting could not be loaded.")
                )
            }
        }
        .navigationTitle("Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard meeting == nil else { return }
            await loadMeeting()
        }
        .toolbar {
            if let currentUser, let meeting, meeting.isHosted(by: currentUser.id) {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditor = true
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleteLoading)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let currentUser, let meeting {
                NavigationStack {
                    MeetingEditorView(
                        user: currentUser,
                        availableCourses: Self.meetingCourseCodes(for: currentUser, fallback: meeting.courseId),
                        meeting: meeting
                    ) { updatedMeeting in
                        self.meeting = updatedMeeting
                        onChanged(updatedMeeting)
                    }
                }
            }
        }
        .alert("Delete this meeting?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteMeeting() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the meeting for all attendees.")
        }
    }

    private func loadMeeting(showFullScreenLoading: Bool = true) async {
        if showFullScreenLoading {
            isLoading = true
        }
        errorMessage = nil
        defer {
            if showFullScreenLoading {
                isLoading = false
            }
        }

        do {
            let loadedMeeting = try await LinkioAPIService().getMeeting(id: meetingID)
            meeting = loadedMeeting
            onChanged(loadedMeeting)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func meetingCourseCodes(for user: User, fallback: String) -> [String] {
        let courses = user.courseCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != "general" }
        return courses.isEmpty ? [fallback] : courses
    }

    @ViewBuilder
    private func titleSection(meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meeting.title)
                        .font(.title2.weight(.bold))
                    Text(meeting.courseId)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Spacer()

                Text(meeting.isUpcoming ? "Upcoming" : "Past")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(meeting.isUpcoming ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((meeting.isUpcoming ? Color.green : Color.gray).opacity(0.14))
                    .clipShape(Capsule())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if let currentUser {
                Button {
                    Task { await toggleRSVP(for: currentUser, meeting: meeting) }
                } label: {
                    HStack {
                        if isRSVPLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(rsvpButtonTitle(for: currentUser, meeting: meeting))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRSVPLoading || meeting.isHosted(by: currentUser.id) || !meeting.isUpcoming)

                if meeting.isHosted(by: currentUser.id) {
                    Text("You are hosting this meeting.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let chatId = meeting.chatId,
                   meeting.isHosted(by: currentUser.id) || meeting.isAttending(userId: currentUser.id) {
                    NavigationLink {
                        ChatThreadView(
                            chat: ChatSummary(
                                id: chatId,
                                title: meeting.title,
                                avatarURL: nil,
                                lastMessage: "",
                                lastTimestamp: nil,
                                unreadCount: 0,
                                members: []
                            ),
                            service: LinkioChatService(currentUserId: currentUser.id),
                            currentUserId: currentUser.id
                        )
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Join Chat")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                } else if canAccessMeetingChat(meeting: meeting, user: currentUser) {
                    Button {
                        Task { await retryMeetingChatRepair() }
                    } label: {
                        HStack {
                            if isChatRepairLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(isChatRepairLoading ? "Preparing Chat..." : "Retry Chat Setup")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isChatRepairLoading)

                    Text("The meeting was created, but its chat is still being attached.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func canAccessMeetingChat(meeting: Meeting, user: User) -> Bool {
        meeting.isHosted(by: user.id) || meeting.isAttending(userId: user.id)
    }

    private func retryMeetingChatRepair() async {
        isChatRepairLoading = true
        errorMessage = nil
        defer { isChatRepairLoading = false }

        await loadMeeting(showFullScreenLoading: false)
    }

    private func metadataSection(meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            MeetingDetailRow(icon: "calendar", title: "Starts", value: meeting.startTime.formatted(date: .complete, time: .shortened))
            MeetingDetailRow(icon: "mappin.and.ellipse", title: "Location", value: meeting.location.isEmpty ? "Location not set" : meeting.location)
            MeetingDetailRow(icon: "person.2.fill", title: "Attendees", value: "\(meeting.attendeeCount)")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func hostSection(meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Host")
                .font(.headline)

            NavigationLink {
                UserProfileView(userId: meeting.creatorId)
            } label: {
                HStack(spacing: 12) {
                    ProfileImageView(imageURL: nil, userName: meeting.creatorName, size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(meeting.creatorName.isEmpty ? "Host" : meeting.creatorName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)

                        if !meeting.creatorBio.isEmpty {
                            Text(meeting.creatorBio)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("View profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }

    private func attendeesSection(meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendees")
                .font(.headline)

            if meeting.attendees.isEmpty {
                Text("No one has RSVP'd yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(meeting.attendees) { attendee in
                        HStack(spacing: 12) {
                            ProfileImageView(imageURL: attendee.pictureURL, userName: attendee.name, size: 38)

                            Text(attendee.name)
                                .font(.subheadline)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private func toggleRSVP(for user: User, meeting: Meeting) async {
        guard !meeting.isHosted(by: user.id) else { return }

        isRSVPLoading = true
        errorMessage = nil
        defer { isRSVPLoading = false }

        do {
            let response = try await LinkioAPIService().rsvpMeeting(
                id: meeting.id,
                request: MeetingRSVPRequest(
                    userId: user.id,
                    userName: user.displayName,
                    userPicture: user.picture ?? "",
                    attending: !meeting.isAttending(userId: user.id)
                )
            )

            self.meeting = response.meeting
            onChanged(response.meeting)
        } catch {
            errorMessage = "Failed to update RSVP."
        }
    }

    private func deleteMeeting() async {
        guard let meeting else { return }

        isDeleteLoading = true
        errorMessage = nil
        defer { isDeleteLoading = false }

        do {
            try await LinkioAPIService().deleteMeeting(id: meeting.id)
            onDeleted(meeting.id)
            dismiss()
        } catch {
            errorMessage = "Failed to delete meeting."
        }
    }

    private func rsvpButtonTitle(for user: User, meeting: Meeting) -> String {
        if !meeting.isUpcoming {
            return "Meeting completed"
        }
        return meeting.isAttending(userId: user.id) ? "Cancel RSVP" : "RSVP"
    }
}

private struct MeetingDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }
}

private struct MeetingEditorView: View {
    let user: User
    let availableCourses: [String]
    var meeting: Meeting? = nil
    let onSaved: (Meeting) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedCourse = ""
    @State private var location = ""
    @State private var startTime = MeetingEditorView.defaultStartTime()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        meeting != nil
    }

    private static func defaultStartTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        components.hour = (components.hour ?? 0) + 1
        let nextWholeHour = Calendar.current.date(from: components) ?? Date().addingTimeInterval(3600)
        return Calendar.current.date(byAdding: .day, value: 1, to: nextWholeHour) ?? nextWholeHour.addingTimeInterval(86_400)
    }

    private var resolvedCourses: [String] {
        let merged = availableCourses + (meeting.map { [$0.courseId] } ?? [])
        var seen = Set<String>()
        return merged.filter { seen.insert($0).inserted }
    }

    var body: some View {
        Form {
            Section("Meeting") {
                TextField("Title", text: $title)

                Picker("Course", selection: $selectedCourse) {
                    ForEach(resolvedCourses, id: \.self) { course in
                        Text(course).tag(course)
                    }
                }

                TextField("Location", text: $location)

                DatePicker("Start time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                Text("Meetings are scoped to your courses and use the existing Exobook backend contract.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Meeting" : "New Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Create") {
                    Task { await saveMeeting() }
                }
                .disabled(isSaving || trimmedTitle.isEmpty || selectedCourse.isEmpty)
            }
        }
        .task {
            configureInitialState()
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureInitialState() {
        guard selectedCourse.isEmpty else { return }

        if let meeting {
            title = meeting.title
            selectedCourse = meeting.courseId
            location = meeting.location
            startTime = meeting.startTime
        } else {
            selectedCourse = resolvedCourses.first ?? ""
        }
    }

    private func saveMeeting() async {
        if !isEditing && startTime <= Date() {
            errorMessage = "Pick a start time in the future."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let savedMeeting: Meeting

            if let meeting {
                savedMeeting = try await LinkioAPIService().updateMeeting(
                    id: meeting.id,
                    request: UpdateMeetingRequest(
                        title: trimmedTitle,
                        courseId: selectedCourse,
                        location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                        startTime: startTime
                    )
                )
            } else {
                savedMeeting = try await LinkioAPIService().createMeeting(
                    CreateMeetingRequest(
                        creatorId: user.id,
                        title: trimmedTitle,
                        creatorName: user.displayName,
                        creatorBio: user.bio ?? "",
                        courseId: selectedCourse,
                        location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                        coordinates: "",
                        startTime: startTime
                    )
                )
            }

            onSaved(savedMeeting)
            dismiss()
        } catch {
            print("[Meetings] ❌ saveMeeting failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MeetingsView()
            .environment(\.currentUser, User.mock)
    }
}
