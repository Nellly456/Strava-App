//https://supabase.com/docs/reference/swift/start
//https://developer.apple.com/documentation/swiftui/

import SwiftUI

/// Main view for displaying and editing user profile information
struct ProfileView: View {
    // MARK: - Properties
    
    /// Manages user authentication and profile data
    @StateObject private var authManager = AuthenticationManager()
    /// Temporary copy of user data that can be edited
    @State private var editedUser: EditableUser
    /// Controls visibility of the save confirmation alert
    @State private var showingSaveAlert = false
    /// Message to display in the alert
    @State private var alertMessage = ""
    /// Tracks whether the profile is in edit mode
    @State private var isEditMode = false
    /// Controls visibility of the image picker
    @State private var showImagePicker = false
    /// Indicates if a save operation is in progress
    @State private var isLoading = false
    
    /// Initializes the view with an empty editable user
    init() {
        _editedUser = State(initialValue: EditableUser(
            name: "",
            email: "",
            username: "",
            profileURL: ""
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack {
                if let user = authManager.user {
                    profileContent(user: user)
                } else {
                    loadingView
                }
            }
        }
        .onAppear {
            // Load user data when the view appears
            loadUserData()
        }
        .alert("Profile Update", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - UI Components
    
    /// Loading indicator shown while fetching user data
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            
            Text("Loading profile...")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
    
    /// Main profile content when user data is available
    private func profileContent(user: User) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Edit Toggle
            HStack {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Toggle for enabling edit mode
                Toggle("Edit Mode", isOn: $isEditMode)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .labelsHidden()
                
                Text("Edit")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }
            .padding(.top)
            
            Text("View and manage your account")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Profile Image Section with edit capability
            profileImageSection(user: user)
            
            // Editable profile fields
            profileFields
                .disabled(!isEditMode) // Only allow editing in edit mode
                .animation(.easeInOut, value: isEditMode)
            
            // Show validation messages only in edit mode
            if isEditMode {
                validationMessages
            }
            
            // Show save button only in edit mode
            if isEditMode {
                saveButton
                    .disabled(!isValidForm) // Disable if form is invalid
            }
            
            Spacer()
        }
        .padding()
        .background(
            // Card-style background with shadow
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding()
    }
    
    /// Profile image section with edit overlay when in edit mode
    private func profileImageSection(user: User) -> some View {
        VStack {
            ZStack {
                // Display the profile image
                profileImage(user: user)
                
                // Show camera overlay in edit mode
                if isEditMode {
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                        }
                    }
                    .opacity(0.8)
                }
            }
            
            // Show username below image when not editing
            if !isEditMode {
                Text("@\(user.username)")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Displays the profile image from URL or a placeholder
    private func profileImage(user: User) -> some View {
        VStack {
            if let url = URL(string: user.profileURL), !user.profileURL.isEmpty {
                // Load image asynchronously from URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView() // Loading indicator
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.scale.combined(with: .opacity))
                    case .failure:
                        // Fallback for failed image load
                        Image(systemName: "person.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.purple, lineWidth: 2)
                )
            } else {
                // Default placeholder when no image URL exists
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.purple)
            }
        }
    }
    
    /// Profile form fields for viewing/editing user information
    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                // Name field
                ProfileField(
                    title: "Name",
                    text: $editedUser.name,
                    icon: "person.fill",
                    isEditing: isEditMode
                )
                
                // Email field
                ProfileField(
                    title: "Email",
                    text: $editedUser.email,
                    icon: "envelope.fill",
                    isEditing: isEditMode
                )
                
                // Username field
                ProfileField(
                    title: "Username",
                    text: $editedUser.username,
                    icon: "at",
                    isEditing: isEditMode
                )
                
                // Profile URL field
                ProfileField(
                    title: "Profile URL",
                    text: $editedUser.profileURL,
                    icon: "link",
                    isEditing: isEditMode
                )
            }
            .transition(.slide) // Animate field changes
        }
    }
    
    /// Validation error messages for form fields
    private var validationMessages: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Email validation message
            if !isValidEmail {
                Text("Please enter a valid email address")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Username validation message
            if !isValidUsername {
                Text("Username must be at least 3 characters")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.top, 5)
    }
    
    /// Save button with loading indicator
    private var saveButton: some View {
        Button(action: {
            isLoading = true
            saveChanges()
        }) {
            HStack {
                // Show loading indicator during save operation
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 5)
                }
                Text("Save Changes")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isValidForm ? Color.purple : Color.gray) // Visual feedback for form validity
            .cornerRadius(10)
            .shadow(radius: 5)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Validation Properties
    
    /// Validates email format using regex
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: editedUser.email)
    }
    
    /// Validates username length
    private var isValidUsername: Bool {
        return editedUser.username.count >= 3
    }
    
    /// Combines all validation checks to determine if form can be saved
    private var isValidForm: Bool {
        return isValidEmail && isValidUsername && !editedUser.name.isEmpty
    }
    
    // MARK: - Helper Methods
    
    /// Loads user data from authentication manager or fetches from database
    private func loadUserData() {
        guard let user = authManager.user else {
            // If user is not available, attempt to fetch from Supabase
            Task {
                if let stID = UserDefaults.standard.string(forKey: "stravaID") {
                    await authManager.fetchUserFromSupabase(stravaId: stID)
                    if let updatedUser = authManager.user {
                        updateEditableUser(from: updatedUser)
                    }
                }
            }
            return
        }
        updateEditableUser(from: user)
    }
    
    /// Updates the editable user model from the authenticated user
    private func updateEditableUser(from user: User) {
        editedUser = EditableUser(
            name: user.name,
            email: user.email,
            username: user.username,
            profileURL: user.profileURL
        )
    }
    
    /// Saves changes to the user profile in the database
    private func saveChanges() {
        Task {
            do {
                // Create updated user object from edited fields
                let updatedUser = User(
                    username: editedUser.username,
                    stravaID: authManager.user?.stravaID ?? "",
                    name: editedUser.name,
                    email: editedUser.email,
                    profileURL: editedUser.profileURL
                )
                
                // Save to Supabase database
                await authManager.saveUserDataToSupabase(user: updatedUser)
                
                // Update UI on success
                await MainActor.run {
                    isLoading = false
                    isEditMode = false
                    alertMessage = "Profile updated successfully"
                    showingSaveAlert = true
                }
            } catch {
                // Handle errors
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

/// Reusable component for profile form fields
struct ProfileField: View {
    /// Field label text
    let title: String
    /// Binding to the field value
    @Binding var text: String
    /// SF Symbol name for the field icon
    let icon: String
    /// Whether editing is enabled
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Field label
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack {
                // Field icon
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                // Show editable text field or static text based on edit mode
                if isEditing {
                    TextField(title, text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(text.isEmpty ? "Not set" : text)
                        .foregroundColor(text.isEmpty ? .gray : .primary)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Models

/// Model for storing editable user data
struct EditableUser {
    var name: String
    var email: String
    var username: String
    var profileURL: String
}

// MARK: - Preview

#Preview {
    ProfileView()
}
