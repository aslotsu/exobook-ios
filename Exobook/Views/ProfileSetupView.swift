//
//  ProfileSetupView.swift
//

import SwiftUI
import PhotosUI

// MARK: - Container

struct ProfileSetupView: View {
    @Environment(\.currentUser) private var currentUser
    @Environment(\.dismiss) private var dismiss

    // Step state
    @State private var step: SetupStep = .basicInfo

    // Basic info
    @State private var name: String
    @State private var bio: String
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?

    // Academic
    @State private var universities: [University] = []
    @State private var selectedUniversity: University?
    @State private var programs: [Program] = []
    @State private var selectedProgram: Program?
    @State private var year: Int

    // Courses
    @State private var availableCourses: [Course] = []
    @State private var selectedCourses: [Course] = []

    // Courses search
    @State private var courseSearch = ""

    // Loading & errors
    @State private var isLoadingUniversities = false
    @State private var isLoadingPrograms = false
    @State private var isLoadingCourses = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    let isRequired: Bool
    private let api = LinkioAPIService()

    enum SetupStep: Int, CaseIterable {
        case basicInfo, academic, courses, review
        var title: String {
            switch self {
            case .basicInfo: return "Your Profile"
            case .academic:  return "Academic Info"
            case .courses:   return "Your Courses"
            case .review:    return "All Set?"
            }
        }
        var next: SetupStep? {
            SetupStep(rawValue: rawValue + 1)
        }
        var previous: SetupStep? {
            SetupStep(rawValue: rawValue - 1)
        }
    }

    init(user: User, isRequired: Bool = false) {
        _name = State(initialValue: user.name)
        _bio  = State(initialValue: user.bio ?? "")
        _year = State(initialValue: user.year ?? 1)
        _selectedCourses = State(initialValue: user.courses?.compactMap { uc in
            Course(id: uc.courseCode, name: uc.courseName, code: uc.courseCode)
        } ?? [])
        self.isRequired = isRequired
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Step content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: step)

                // Navigation buttons
                navBar
                    .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRequired, step == .basicInfo {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") { dismiss() }
                    }
                }
            }
            .overlay { savingOverlay }
            .task { await loadUniversities() }
            .onChange(of: selectedUniversity?.id) { _, id in
                guard let id else { programs = []; availableCourses = []; selectedProgram = nil; return }
                Task { await loadProgramsAndCourses(universityId: id) }
            }
            .onChange(of: avatarItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await MainActor.run { avatarImage = image }
                }
            }
        }
        .interactiveDismissDisabled(isRequired)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
            }
            .frame(height: 4)
        }
        .frame(height: 4)
        .padding(.bottom, 8)
    }

    private var progress: Double {
        Double(step.rawValue + 1) / Double(SetupStep.allCases.count)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basicInfo:  basicInfoStep
        case .academic:   academicStep
        case .courses:    coursesStep
        case .review:     reviewStep
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 12) {
            if let prev = step.previous {
                Button {
                    withAnimation { step = prev }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button {
                if step == .review {
                    Task { await saveProfile() }
                } else if let next = step.next {
                    withAnimation { step = next }
                }
            } label: {
                HStack {
                    Text(step == .review ? "Complete Setup" : "Continue")
                        .fontWeight(.semibold)
                    if step != .review {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canProceed ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(canProceed ? Color.white : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceed || isSaving)
        }
    }

    private var canProceed: Bool {
        switch step {
        case .basicInfo:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   bio.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
        case .academic:
            return selectedUniversity != nil && selectedProgram != nil
        case .courses:
            return !selectedCourses.isEmpty
        case .review:
            return true
        }
    }

    // MARK: - Saving overlay

    @ViewBuilder
    private var savingOverlay: some View {
        if isSaving {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.4)
                    Text("Setting up your profile…")
                        .font(.subheadline).fontWeight(.medium)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        } else if let err = errorMessage {
            VStack {
                Spacer()
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .onTapGesture { errorMessage = nil }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: errorMessage)
        }
    }
}

// MARK: - Step: Basic Info

extension ProfileSetupView {
    private var basicInfoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(
                    title: "Let's set up your profile",
                    subtitle: "This is how other students will find and recognise you."
                )

                // Avatar picker
                VStack(spacing: 12) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        ZStack {
                            if let img = avatarImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 96, height: 96)
                                    .overlay {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.blue)
                                    }
                            }
                            Circle()
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 2)
                                .frame(width: 96, height: 96)
                        }
                    }
                    Text("Add a photo")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Name
                field(label: "Full Name", required: true) {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Bio
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bio")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("required")
                            .font(.caption).foregroundStyle(.red)
                        Spacer()
                        Text("\(bio.count) / 10 min")
                            .font(.caption2)
                            .foregroundStyle(bio.count >= 10 ? Color.green : Color.secondary)
                    }
                    TextEditor(text: $bio)
                        .frame(height: 120)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    bio.count >= 10 ? Color.green.opacity(0.4) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    if bio.count < 10 && !bio.isEmpty {
                        Text("At least 10 characters — tell others what you're studying or interested in.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Step: Academic

extension ProfileSetupView {
    private var academicStep: some View {
        List {
            Section {
                stepHeader(
                    title: "Academic details",
                    subtitle: "Used to personalise your feed and meetings."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            // University
            Section("University / Campus") {
                if isLoadingUniversities {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    NavigationLink {
                        PickerList(
                            title: "University",
                            items: universities,
                            selectedId: selectedUniversity?.id,
                            display: \.name,
                            onSelect: { selectedUniversity = $0 }
                        )
                    } label: {
                        HStack {
                            Text(selectedUniversity?.name ?? "Select university")
                                .foregroundStyle(selectedUniversity == nil ? .secondary : .primary)
                            Spacer()
                            if selectedUniversity != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            // Program
            Section("Program") {
                if selectedUniversity == nil {
                    Text("Select a university first").foregroundStyle(.secondary).font(.subheadline)
                } else if isLoadingPrograms {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    NavigationLink {
                        PickerList(
                            title: "Program",
                            items: programs,
                            selectedId: selectedProgram?.id,
                            display: \.name,
                            onSelect: { selectedProgram = $0 }
                        )
                    } label: {
                        HStack {
                            Text(selectedProgram?.name ?? "Select program")
                                .foregroundStyle(selectedProgram == nil ? .secondary : .primary)
                            Spacer()
                            if selectedProgram != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            // Year
            Section("Year of Study") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(1...6, id: \.self) { y in
                        Button {
                            year = y
                        } label: {
                            Text("\(y)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(year == y ? Color.blue : Color(.secondarySystemBackground))
                                .foregroundStyle(year == y ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(.init(top: 12, leading: 8, bottom: 12, trailing: 8))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }
}

// MARK: - Step: Courses

extension ProfileSetupView {
    private var coursesStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Your courses",
                subtitle: "Pick at least one — these drive what shows up in your feed."
            )
            .padding()

            // Selected chips
            if !selectedCourses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedCourses, id: \.id) { course in
                            HStack(spacing: 4) {
                                Text(course.code).font(.caption).fontWeight(.semibold)
                                Button { selectedCourses.removeAll { $0.id == course.id } } label: {
                                    Image(systemName: "xmark").font(.caption2)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by code or name", text: $courseSearch)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 4)

            if isLoadingCourses {
                Spacer()
                ProgressView("Loading courses…")
                Spacer()
            } else if selectedUniversity == nil {
                Spacer()
                ContentUnavailableView(
                    "Choose a university first",
                    systemImage: "building.columns",
                    description: Text("Go back and select your university and program.")
                )
                Spacer()
            } else {
                List {
                    ForEach(filteredCourses, id: \.id) { course in
                        let isSelected = selectedCourses.contains(where: { $0.id == course.id })
                        Button {
                            if isSelected { selectedCourses.removeAll { $0.id == course.id } }
                            else { selectedCourses.append(course) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.code).font(.subheadline).fontWeight(.semibold)
                                    Text(course.name).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredCourses: [Course] {
        let q = courseSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let remaining = availableCourses.filter { c in !selectedCourses.contains(where: { $0.id == c.id }) }
        guard !q.isEmpty else { return remaining }
        return remaining.filter {
            $0.code.localizedCaseInsensitiveContains(q) || $0.name.localizedCaseInsensitiveContains(q)
        }
    }
}

// MARK: - Step: Review

extension ProfileSetupView {
    private var reviewStep: some View {
        List {
            Section {
                stepHeader(
                    title: "Looking good!",
                    subtitle: "Review your details before we set everything up."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            Section("Profile") {
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56).clipShape(Circle())
                }
                reviewRow("Name", name)
                reviewRow("Bio", bio)
            }

            Section("Academic") {
                reviewRow("University", selectedUniversity?.name ?? "—")
                reviewRow("Program", selectedProgram?.name ?? "—")
                reviewRow("Year", "Year \(year)")
            }

            Section("Courses (\(selectedCourses.count))") {
                ForEach(selectedCourses, id: \.id) { course in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.code).font(.subheadline).fontWeight(.semibold)
                        Text(course.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Data loading + save

extension ProfileSetupView {
    private func loadUniversities() async {
        guard universities.isEmpty else { return }
        isLoadingUniversities = true
        defer { isLoadingUniversities = false }
        do {
            let loaded = try await api.getAllUniversities()
            universities = loaded.sorted { $0.name < $1.name }

            // Pre-select if user already has a campus
            if let campusName = currentUser?.campus,
               let match = universities.first(where: { $0.name == campusName }) {
                selectedUniversity = match
            }
        } catch {
            print("[ProfileSetup] ❌ loadUniversities failed: \(error)")
            errorMessage = "Couldn't load universities."
        }
    }

    private func loadProgramsAndCourses(universityId: String) async {
        isLoadingPrograms = true
        isLoadingCourses = true
        defer { isLoadingPrograms = false; isLoadingCourses = false }
        do {
            async let p = api.getPrograms(universityId: universityId)
            async let c = api.getCourses(universityId: universityId)
            let (loadedPrograms, loadedCourses) = try await (p, c)
            programs = loadedPrograms.sorted { $0.name < $1.name }
            availableCourses = loadedCourses.sorted { $0.code < $1.code }

            // Pre-select program if user already has one
            if let rawProgram = currentUser?.program, selectedProgram == nil {
                let normalised = rawProgram.split(separator: "|").first.map(String.init) ?? rawProgram
                selectedProgram = programs.first { $0.name == normalised }
            }
        } catch {
            errorMessage = "Couldn't load programs or courses."
        }
    }

    private func saveProfile() async {
        guard let user = currentUser,
              let university = selectedUniversity,
              let program = selectedProgram else { return }

        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            // 1. Upload avatar if changed
            var pictureURL: String? = nil
            if let img = avatarImage, let data = img.jpegData(compressionQuality: 0.8) {
                let filenames = try await api.uploadImages([data])
                pictureURL = filenames.first
            }

            // 2. Update user profile
            let encodedProgram = "\(program.name)|\(program.id)"
            let req = UpdateUserRequest(
                id: user.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                campus: university.name,
                programme: encodedProgram,
                year: year,
                picture: pictureURL,
                country: nil
            )
            _ = try await api.updateUser(req)

            // 3. Campus + program Redis caches
            async let campusSet = api.setMyCampus(userId: user.id,
                                                   campus: CampusSelection(id: university.id, name: university.name))
            async let programSet = api.setMyProgram(userId: user.id, program: program)
            _ = try await (campusSet, programSet)

            // 4. Courses
            let courseItems = selectedCourses.map { c in
                CourseUpdateItem(courseCode: c.code, courseName: c.name,
                                 programName: program.name, year: String(year))
            }
            _ = try await api.updateUserCourses(userId: user.id, courses: courseItems)

            // 5. Refresh local user state
            await AuthenticationManager.shared.refreshUserData()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared helpers

extension ProfileSetupView {
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2).fontWeight(.bold)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func field<C: View>(label: String, required: Bool = false, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(label).font(.subheadline).fontWeight(.semibold)
                if required { Text("*").foregroundStyle(.red) }
            }
            content()
        }
    }
}

// MARK: - Generic picker list (used for university and program)

private struct PickerList<Item: Identifiable>: View where Item.ID == String {
    let title: String
    let items: [Item]
    let selectedId: String?
    let display: KeyPath<Item, String>
    let onSelect: (Item) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [Item] {
        query.isEmpty ? items : items.filter { $0[keyPath: display].localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack {
                        Text(item[keyPath: display])
                        Spacer()
                        if item.id == selectedId {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Search \(title.lowercased())")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
