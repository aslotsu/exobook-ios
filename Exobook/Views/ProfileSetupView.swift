//
//  ProfileSetupView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 25/01/2026.
//

import SwiftUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentUser) private var currentUser
    
    @State private var name: String
    @State private var bio: String = ""
    @State private var campus: String = ""
    @State private var program: String = ""
    @State private var year: Int = 1
    @State private var courses: [EditableCourse] = []
    
    @State private var currentStep = 0
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingAddCourse = false
    
    let isRequired: Bool
    
    init(user: User, isRequired: Bool = false) {
        _name = State(initialValue: user.name)
        self.isRequired = isRequired
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep) / 3.0)
                    .tint(.blue)
                    .padding()
                
                // Content based on current step
                TabView(selection: $currentStep) {
                    // Step 1: Basic Info
                    basicInfoStep
                        .tag(0)
                    
                    // Step 2: Academic Info
                    academicInfoStep
                        .tag(1)
                    
                    // Step 3: Courses
                    coursesStep
                        .tag(2)
                    
                    // Step 4: Review
                    reviewStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: previousStep) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: nextStep) {
                        HStack {
                            Text(currentStep == 3 ? "Complete Setup" : "Continue")
                            if currentStep < 3 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canProceed || isSaving)
                }
                .padding()
            }
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRequired {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") {
                            dismiss()
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Setting up your profile...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(16)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
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
        .interactiveDismissDisabled(isRequired)
    }
    
    // MARK: - Steps
    
    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to Exobook! 👋")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Let's start by setting up your basic information")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name *")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter your full name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $bio)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Text("Tell others a bit about yourself")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var academicInfoStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Academic Details 📚")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Help us personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Campus *")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Picker("Select Campus", selection: $campus) {
                        Text("Select...").tag("")
                        Text("Main Campus").tag("Main Campus")
                        Text("Downtown Campus").tag("Downtown Campus")
                        Text("Online").tag("Online")
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Program *")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("e.g., Computer Science", text: $program)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Year of Study *")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        ForEach(1...6, id: \.self) { yearNum in
                            Button(action: {
                                year = yearNum
                            }) {
                                Text("\(yearNum)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(year == yearNum ? Color.blue : Color(uiColor: .systemGray6))
                                    .foregroundColor(year == yearNum ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var coursesStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Courses 📖")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add courses to connect with classmates")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            if courses.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.5))
                    
                    Text("No courses added yet")
                        .font(.headline)
                    
                    Text("Add your courses to see relevant posts and connect with classmates")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: { showingAddCourse = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Your First Course")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(courses) { course in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.courseCode)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(course.courseName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    courses.removeAll { $0.id == course.id }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Button(action: { showingAddCourse = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Another Course")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review & Confirm ✅")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Make sure everything looks good")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Info
                    reviewSection(title: "Basic Information") {
                        reviewRow(label: "Name", value: name)
                        if !bio.isEmpty {
                            reviewRow(label: "Bio", value: bio)
                        }
                    }
                    
                    // Academic Info
                    reviewSection(title: "Academic Details") {
                        reviewRow(label: "Campus", value: campus.isEmpty ? "Not set" : campus)
                        reviewRow(label: "Program", value: program.isEmpty ? "Not set" : program)
                        reviewRow(label: "Year", value: "Year \(year)")
                    }
                    
                    // Courses
                    if !courses.isEmpty {
                        reviewSection(title: "Courses (\(courses.count))") {
                            ForEach(courses) { course in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.courseCode)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(course.courseName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func reviewSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                content()
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func reviewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
    
    // MARK: - Navigation
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !name.isEmpty
        case 1:
            return !campus.isEmpty && !program.isEmpty
        case 2:
            return true // Courses are optional
        case 3:
            return true
        default:
            return false
        }
    }
    
    private func nextStep() {
        if currentStep == 3 {
            Task {
                await saveProfile()
            }
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep -= 1
        }
    }
    
    // MARK: - Save
    
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
            
            // Update courses if any were added
            if !courses.isEmpty {
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
            
            print("✅ Profile setup completed successfully")
            
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
            }
            print("❌ Failed to save profile: \(error)")
        }
    }
}

#Preview {
    ProfileSetupView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            username: nil,
            bio: nil,
            picture: nil,
            campus: nil,
            program: nil,
            year: nil,
            courses: nil,
            createdAt: nil,
            updatedAt: nil
        ),
        isRequired: false
    )
}
