//
//  MeetingsViewModel.swift
//  Exobook
//
//  Created by OpenAI Codex on 27/05/2026.
//

import Foundation

@MainActor
@Observable
final class MeetingsViewModel {
    private let api = LinkioAPIService()

    let user: User
    var scope: MeetingScope = .all {
        didSet {
            Task { await loadMeetings() }
        }
    }

    var meetings: [Meeting] = []
    var isLoading = false
    var errorMessage: String?

    init(user: User) {
        self.user = user
    }

    var availableCourses: [String] {
        user.courseCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !Self.isGeneralCourse($0) }
    }

    var hasCourseContext: Bool {
        !availableCourses.isEmpty
    }

    func loadMeetings() async {
        guard hasCourseContext else {
            print("[Meetings] no course context — raw courses: \(user.courses?.map { "id=\($0.id) code=\($0.courseCode)" } ?? [])")
            meetings = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            print("[Meetings] fetching scope=\(scope.rawValue) courses=\(availableCourses)")
            let result = try await api.getMeetings(courses: availableCourses, scope: scope)
            print("[Meetings] loaded \(result.count) meeting(s): \(result.map { "\($0.id) course=\($0.courseId)" })")
            meetings = result
            sortMeetings()
        } catch {
            print("[Meetings] load failed: \(error)")
            errorMessage = "Failed to load meetings."
        }
    }

    func refresh() async {
        await loadMeetings()
    }

    func upsert(_ meeting: Meeting) {
        guard matchesScope(meeting) else {
            remove(meetingId: meeting.id)
            return
        }

        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.append(meeting)
        }
        sortMeetings()
    }

    func remove(meetingId: String) {
        meetings.removeAll { $0.id == meetingId }
    }

    private func sortMeetings() {
        switch scope {
        case .past:
            meetings.sort { $0.startTime > $1.startTime }
        case .upcoming, .all:
            meetings.sort { $0.startTime < $1.startTime }
        }
    }

    private func matchesScope(_ meeting: Meeting) -> Bool {
        switch scope {
        case .upcoming:
            return meeting.isUpcoming
        case .past:
            return !meeting.isUpcoming
        case .all:
            return true
        }
    }

    private static func isGeneralCourse(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("General")
    }
}
