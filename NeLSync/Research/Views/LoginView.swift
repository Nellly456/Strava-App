import SwiftUI

/// The main login view that handles authentication flow for the fitness app
struct LoginView: View {
    // MARK: - Properties
    
    /// Manages authentication state and methods
    @StateObject private var authManager = AuthenticationManager()
    /// Controls the loading indicator visibility
    @State private var isLoading = false
    /// Controls error alert visibility
    @State private var showError = false
    /// Stores the error message to display
    @State private var errorMessage = ""
    /// Manages navigation stack for authenticated view
    @State private var navigationPath = NavigationPath()
    /// Controls the background animation state
    @State private var appearAnimation = false
    /// Controls the bouncing animation for UI elements
    @State private var bounceEffect = false
    /// Environment variable to dismiss the view
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Animated gradient background with continuous hue rotation
            LinearGradient(
                gradient: Gradient(colors: [.purple.opacity(0.3), .blue.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            .hueRotation(.degrees(appearAnimation ? 360 : 0))
            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: appearAnimation)
            
            // Conditional rendering based on authentication state with transition animations
            if authManager.isAuthenticated {
                authenticatedView
                    .transition(.move(edge: .trailing))
            } else {
                unauthenticatedView
                    .transition(.move(edge: .leading))
            }
        }
        // Error alert configuration
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Start animations when view appears
            appearAnimation = true
            // Configure and start the bouncing animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever()) {
                bounceEffect = true
            }
        }
    }
    
    // MARK: - Authenticated View
    
    /// View displayed after successful authentication
    private var authenticatedView: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 25) {
                // Welcome header with animated icon
                VStack(spacing: 10) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                        .offset(y: bounceEffect ? -10 : 0) // Apply bounce animation
                    
                    Text("Welcome to NeLSync")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                    
                    Text("Your personal fitness companion")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 30)
                
                // Navigation options for authenticated users
                VStack(spacing: 16) {
                    // Dashboard navigation button
                    NavigationButton(
                        title: "Dashboard",
                        icon: "chart.bar.fill",
                        color: .blue,
                        destination: DashboardView()
                    )
                    
                    // Profile navigation button
                    NavigationButton(
                        title: "Profile",
                        icon: "person.fill",
                        color: .purple,
                        destination: ProfileView()
                    )
                    
                    // Logout button with animation
                    Button(action: {
                        withAnimation {
                            authManager.signOut()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                        }
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.orange.gradient)
                        }
                        .shadow(radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Motivational footer text
                Text("Track your progress, achieve your goals")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial) // Adds frosted glass effect
        }
    }
    
    // MARK: - Unauthenticated View
    
    /// View displayed when user is not authenticated
    private var unauthenticatedView: some View {
        VStack(spacing: 25) {
            // Animated app logo
            Image(systemName: "figure.run")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .offset(y: bounceEffect ? -10 : 0) // Apply bounce animation
                .padding(.bottom, 20)
            
            // Welcome text section
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Sign in to continue your fitness journey")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            // Conditional rendering of loading indicator or login button
            if isLoading {
                LoadingView()
            } else {
                // Strava authentication button
                Button(action: {
                    Task {
                        // Show loading indicator with animation
                        withAnimation {
                            isLoading = true
                        }
                        // Attempt authentication with error handling
                        do {
                            try await authManager.authenticateWithStrava()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                        // Hide loading indicator with animation
                        withAnimation {
                            isLoading = false
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.title2)
                        Text("Continue with Strava")
                            .font(.title2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.orange.gradient)
                    }
                    .shadow(radius: 8, y: 4)
                    .contentShape(Rectangle()) // Ensures the entire button is tappable
                }
                .buttonStyle(ScaleButtonStyle()) // Apply custom scale animation on press
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial) // Adds frosted glass effect
    }
}

// MARK: - Supporting Views and Styles

/// Custom button style that scales down slightly when pressed
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1) // Scale down when pressed
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Animated loading indicator using a rotating circle
struct LoadingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7) // Creates a partial circle
            .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // Start continuous rotation animation
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

/// Reusable navigation button component with consistent styling
struct NavigationButton<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.title2.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.gradient)
            }
            .shadow(radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle()) // Apply custom scale animation on press
    }
}

/// Preview provider for SwiftUI canvas
#Preview {
    LoginView()
}
