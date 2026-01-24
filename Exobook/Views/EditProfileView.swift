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
    @State private var campus: String
    @State private var program: String
    @State private var year: Int
    @State private var courses: [EditableCourse]
    
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var errorMessage = ""
    @State private var showingAddCourse = false
    
    init(user: User) {
        _name = State(initialValue: user.name)
        _bio = State(initialValue: user.bio ?? "")
        _campus = State(initialValue: user.campus ?? "")
        _program = State(initialValue: user.program ?? "")
        _year = State(initialValue: user.year ?? 1)
        _courses = State(initialValue: user.courses?.map { EditableCourse(from: $0) } ?? [])
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
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
                } header: {
                    Text("Basic Information")
                }
                
                // Academic Information Section
                Section {
                    Picker("Campus", selection: $campus) {
                        Text("Not set").tag("")
                        Text("Main Campus").tag("Main Campus")
                        Text("Downtown Campus").tag("Downtown Campus")
                        Text("Online").tag("Online")
                    }
                    
                    TextField("Program", text: $program)
                        .textContentType(.none)
                    
                    Stepper("Year: \(year)", value: $year, in: 1...6)
                } header: {
                    Text("Academic Information")
                }
                
                // Courses Section
                Section {
                    ForEach(courses) { course in
                        courseRow(course: course)
                    }
                    .onDelete(perform: deleteCourses)
                    
                    Button(action: { showingAddCourse = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Course")
                        }
                    }
                } header: {
                    HStack {
                        Text("Enrolled Courses")
                        Spacer()
                        if !courses.isEmpty {
                            Text("\(courses.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Your courses help personalize your feed and connect you with classmates.")
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
                    .disabled(isSaving || !hasChanges)
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
            .sheet(isPresented: $showingAddCourse) {
                AddCourseView { course in
                    courses.append(course)
                }
            }
        }
    }
    
    // MARK: - Profile Picture Row
    
    private var profilePictureRow: some View {
        HStack {
            if let avatarURL = currentUser?.avatarURL {
                // Use our improved ProfileImageView with SVG detection
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
    
    // MARK: - Course Row
    
    private func courseRow(course: EditableCourse) -> some View {
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
    
    private func deleteCourses(at offsets: IndexSet) {
        courses.remove(atOffsets: offsets)
    }
    
    // MARK: - Save Logic
    
    private var hasChanges: Bool {
        guard let user = currentUser else { return false }
        
        return name != user.name ||
               bio != (user.bio ?? "") ||
               campus != (user.campus ?? "") ||
               program != (user.program ?? "") ||
               year != (user.year ?? 1) ||
               courses.map { $0.courseCode } != user.courseCodes
    }
    
    private func saveProfile() async {
        guard let user = currentUser else { return }
        
        await MainActor.run {
            isSaving = true
        }
        
        do {
            let api = ExobookAPIService()
            
            // Update basic profile info
            let updateRequest = UpdateUserRequest(
                id: user.id,
                name: name.isEmpty ? nil : name,
                bio: bio.isEmpty ? nil : bio,
                campus: campus.isEmpty ? nil : campus,
                programme: program.isEmpty ? nil : program,
                year: year,
                picture: nil,
                country: nil
            )
            
            _ = try await api.updateUser(updateRequest)
            
            // Update courses if changed
            if courses.map({ $0.courseCode }) != user.courseCodes {
                let courseItems = courses.map { course in
                    CourseUpdateItem(
                        courseCode: course.courseCode,
                        courseName: course.courseName,
                        programName: program,
                        year: String(year)
                    )
                }
                _ = try await api.updateUserCourses(userId: user.id, courses: courseItems)
            }
            
            // Refresh user data
            await AuthenticationManager.shared.refreshUserData()
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
            
            print("✅ Profile updated successfully")
            
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingSaveError = true
            }
            print("❌ Failed to update profile: \(error)")
        }
    }
}

// MARK: - Editable Course Model

struct EditableCourse: Identifiable, Equatable {
    let id: String
    let courseCode: String
    let courseName: String
    
    init(from userCourse: UserCourse) {
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

// MARK: - Add Course View

struct AddCourseView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (EditableCourse) -> Void
    
    @State private var courseCode = ""
    @State private var courseName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Course Code", text: $courseCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    TextField("Course Name", text: $courseName)
                } header: {
                    Text("Course Details")
                } footer: {
                    Text("Example: CS101 - Introduction to Computer Science")
                        .font(.caption)
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let course = EditableCourse(
                            courseCode: courseCode,
                            courseName: courseName
                        )
                        onAdd(course)
                        dismiss()
                    }
                    .disabled(courseCode.isEmpty || courseName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
