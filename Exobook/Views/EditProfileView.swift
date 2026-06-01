//
//  EditProfileView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 03/01/2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser

    @State private var name: String
    @State private var bio: String
    @State private var country: String
    @State private var year: Int
    @State private var courses: [EditableCourse]

    @State private var universities: [University] = []
    @State private var selectedUniversity: University?
    @State private var universitySearch = ""

    @State private var programs: [Program] = []
    @State private var selectedProgram: Program?
    @State private var programSearch = ""

    @State private var availableCourses: [Course] = []
    @State private var courseSearch = ""

    @State private var isLoadingReferenceData = false
    @State private var isLoadingPrograms = false
    @State private var isLoadingCourses = false
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var errorMessage = ""

    private let api = LinkioAPIService()

    init(user: User) {
        _name = State(initialValue: user.name)
        _bio = State(initialValue: user.bio ?? "")
        _country = State(initialValue: user.country ?? "")
        _year = State(initialValue: user.year ?? 1)
        _courses = State(initialValue: user.courses?.map { EditableCourse(from: $0) } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    profilePictureRow

                    TextField("Name", text: $name)
                        .textContentType(.name)

                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("Bio")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $bio)
                            .frame(minHeight: 80)
                    }

                    TextField("Country", text: $country)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } header: {
                    Text("Basic Information")
                }

                Section {
                    TextField("Search Universities", text: $universitySearch)
                        .textInputAutocapitalization(.words)

                    if isLoadingReferenceData {
                        ProgressView("Loading universities...")
                    } else {
                        selectionList(
                            items: filteredUniversities,
                            selectedID: selectedUniversity?.id,
                            id: \.id
                        ) { university in
                            Text(university.name)
                                .font(.subheadline)
                        } onSelect: { university in
                            selectedUniversity = university
                        }
                    }
                } header: {
                    Text("University")
                } footer: {
                    Text("This mirrors the web campus selection flow and persists the same campus object.")
                        .font(.caption)
                }

                Section {
                    TextField("Search Programs", text: $programSearch)
                        .disabled(selectedUniversity == nil)

                    if selectedUniversity == nil {
                        Text("Select a university first.")
                            .foregroundColor(.secondary)
                    } else if isLoadingPrograms {
                        ProgressView("Loading programs...")
                    } else {
                        selectionList(
                            items: filteredPrograms,
                            selectedID: selectedProgram?.id,
                            id: \.id
                        ) { program in
                            Text(program.name)
                                .font(.subheadline)
                        } onSelect: { program in
                            selectedProgram = program
                        }
                    }
                } header: {
                    Text("Program")
                }

                Section {
                    Stepper("Year: \(year)", value: $year, in: 1...6)
                } header: {
                    Text("Year of Study")
                }

                Section {
                    TextField("Search Courses", text: $courseSearch)
                        .disabled(selectedUniversity == nil)

                    if selectedUniversity == nil {
                        Text("Select a university first.")
                            .foregroundColor(.secondary)
                    } else if isLoadingCourses {
                        ProgressView("Loading courses...")
                    } else {
                        selectionList(
                            items: filteredAvailableCourses,
                            selectedID: nil,
                            id: \.id
                        ) { course in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.code)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(course.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } onSelect: { course in
                            toggleCourse(course)
                        }
                    }
                } header: {
                    Text("Add Courses")
                } footer: {
                    Text("Tap a course to add it to your enrolled list.")
                        .font(.caption)
                }

                Section {
                    if courses.isEmpty {
                        Text("No courses selected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(courses) { course in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.courseCode)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(course.courseName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteCourses)
                    }
                } header: {
                    HStack {
                        Text("Enrolled Courses")
                        Spacer()
                        Text("\(courses.count)")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Your courses personalize your feed and social graph.")
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isSaving || !hasChanges || selectedUniversity == nil || selectedProgram == nil)
                    .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView("Saving...")
                            .padding()
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(10)
                    }
                }
            }
            .alert("Error Saving Profile", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await loadReferenceData()
        }
        .onChange(of: selectedUniversity?.id) { _, newValue in
            guard let newValue else {
                programs = []
                availableCourses = []
                selectedProgram = nil
                return
            }

            Task {
                await loadProgramsAndCourses(for: newValue)
            }
        }
    }

    private var profilePictureRow: some View {
        HStack {
            if let avatarURL = currentUser?.avatarURL {
                ProfileImageView(imageURL: avatarURL, userName: currentUser?.name, size: 60)
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(name.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Picture")
                    .font(.subheadline)
                Text("Tap to change")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private var filteredUniversities: [University] {
        let query = universitySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return universities }
        return universities.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredPrograms: [Program] {
        let query = programSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return programs }
        return programs.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredAvailableCourses: [Course] {
        let remaining = availableCourses.filter { course in
            !courses.contains(where: { $0.courseCode == course.code })
        }
        let query = courseSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return remaining }
        return remaining.filter {
            $0.code.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var hasChanges: Bool {
        guard let user = currentUser else { return false }

        let normalizedProgram = normalizeProgramName(user.program)
        let universityChanged = selectedUniversity?.name != user.campus
        let programChanged = selectedProgram?.name != normalizedProgram

        return name != user.name ||
            bio != (user.bio ?? "") ||
            country != (user.country ?? "") ||
            year != (user.year ?? 1) ||
            universityChanged ||
            programChanged ||
            courses.map(\.courseCode) != user.courseCodes
    }

    private func deleteCourses(at offsets: IndexSet) {
        courses.remove(atOffsets: offsets)
    }

    private func toggleCourse(_ course: Course) {
        if let index = courses.firstIndex(where: { $0.courseCode == course.code }) {
            courses.remove(at: index)
        } else {
            courses.append(EditableCourse(courseCode: course.code, courseName: course.name))
        }
    }

    private func loadReferenceData() async {
        guard universities.isEmpty else { return }

        isLoadingReferenceData = true
        defer { isLoadingReferenceData = false }

        do {
            universities = try await api.getAllUniversities().sorted { $0.name < $1.name }

            if let user = currentUser,
               let campusName = user.campus,
               let matchedUniversity = universities.first(where: { $0.name == campusName }) {
                selectedUniversity = matchedUniversity
            }
        } catch {
            print("[EditProfile] ❌ loadUniversities failed: \(error)")
            errorMessage = "Failed to load universities."
            showingSaveError = true
        }
    }

    private func loadProgramsAndCourses(for universityId: String) async {
        isLoadingPrograms = true
        isLoadingCourses = true
        defer {
            isLoadingPrograms = false
            isLoadingCourses = false
        }

        do {
            async let programsTask = api.getPrograms(universityId: universityId)
            async let coursesTask = api.getCourses(universityId: universityId)
            let (loadedPrograms, loadedCourses) = try await (programsTask, coursesTask)

            programs = loadedPrograms.sorted { $0.name < $1.name }
            availableCourses = loadedCourses.sorted { $0.code < $1.code }

            if let currentUser,
               selectedProgram == nil {
                let normalizedProgram = normalizeProgramName(currentUser.program)
                selectedProgram = programs.first(where: { $0.name == normalizedProgram })
            }
        } catch {
            errorMessage = "Failed to load programs and courses."
            showingSaveError = true
        }
    }

    private func normalizeProgramName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return raw.split(separator: "|").first.map(String.init) ?? raw
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func saveProfile() async {
        guard let user = currentUser,
              let selectedUniversity,
              let selectedProgram else { return }

        await MainActor.run {
            isSaving = true
        }

        do {
            let encodedProgram = "\(selectedProgram.name)|\(selectedProgram.id)"
            let updateRequest = UpdateUserRequest(
                id: user.id,
                name: trimmedOrNil(name),
                bio: trimmedOrNil(bio),
                campus: selectedUniversity.name,
                programme: encodedProgram,
                year: year,
                picture: nil,
                country: trimmedOrNil(country)
            )

            _ = try await api.updateUser(updateRequest)
            _ = try await api.setMyCampus(
                userId: user.id,
                campus: CampusSelection(id: selectedUniversity.id, name: selectedUniversity.name)
            )
            _ = try await api.setMyProgram(userId: user.id, program: selectedProgram)

            let courseItems = courses.map { course in
                CourseUpdateItem(
                    courseCode: course.courseCode,
                    courseName: course.courseName,
                    programName: selectedProgram.name,
                    year: String(year)
                )
            }
            _ = try await api.updateUserCourses(userId: user.id, courses: courseItems)

            await AuthenticationManager.shared.refreshUserData()

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingSaveError = true
            }
        }
    }

    private func selectionList<Item: Identifiable, RowContent: View>(
        items: [Item],
        selectedID: Item.ID?,
        id: KeyPath<Item, Item.ID>,
        maxHeight: CGFloat = 180,
        @ViewBuilder row: @escaping (Item) -> RowContent,
        onSelect: @escaping (Item) -> Void
    ) -> some View where Item.ID: Hashable {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    Button(action: { onSelect(item) }) {
                        HStack {
                            row(item)
                            Spacer()
                            if selectedID == item[keyPath: id] {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: maxHeight)
    }
}

// MARK: - Editable Course Model

struct EditableCourse: Identifiable, Equatable {
    let id: String
    let courseCode: String
    let courseName: String

    nonisolated init(from userCourse: UserCourse) {
        self.id = userCourse.id
        self.courseCode = userCourse.courseCode
        self.courseName = userCourse.courseName
    }

    init(courseCode: String, courseName: String) {
        self.id = UUID().uuidString
        self.courseCode = courseCode
        self.courseName = courseName
    }
}
