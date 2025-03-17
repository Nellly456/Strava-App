import SwiftUI

/**
 * ContentView: The main view of the application
 * - Manages authentication state transitions
 * - Displays either the Welcome view or Login view based on authentication state
 * - Handles animated transitions between views
 */
struct ContentView: View {
    // MARK: - Properties
    
    /// Authentication manager to handle user login state
    @StateObject private var authManager = AuthenticationManager()
    
    /// Namespace for coordinating animations between views
    @Namespace private var animation
    
    /// Tracks loading state for button animations
    @State private var isLoading: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient covering the entire screen
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Conditional view display based on authentication state
                if authManager.isAuthenticated {
                    // Show login view with slide-in animation from right
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    // Show welcome view with slide-in animation from left
                    WelcomeView(authManager: authManager, isLoading: $isLoading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .navigationBarHidden(true) // Hide the navigation bar
        }
    }
}

/**
 * WelcomeView: The initial onboarding screen
 * - Displays app logo, title, and description
 * - Provides a "Get Started" button to begin authentication flow
 * - Features animated entrance for all elements
 */
struct WelcomeView: View {
    // MARK: - Properties
    
    /// Authentication manager passed from parent view
    @ObservedObject var authManager: AuthenticationManager
    
    /// Binding to loading state controlled by parent
    @Binding var isLoading: Bool
    
    /// Controls visibility of UI elements during animation
    @State private var showGetStarted: Bool = false
    
    /// Controls vertical offset animation for title
    @State private var titleOffset: CGFloat = 30
    
    /// Controls vertical offset animation for description
    @State private var descriptionOffset: CGFloat = 60
    
    /// Controls scale animation for the button
    @State private var buttonScale: CGFloat = 0.8
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Logo and Title section
            VStack(spacing: 15) {
                // App icon using SF Symbols
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
//                    .symbolEffect(.bounce, options: .repeating)
                
                // App name with gradient styling
                Text("NeLSync")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .offset(y: titleOffset) // Animated vertical position
            .opacity(showGetStarted ? 1 : 0) // Animated opacity
            
            // App description text
            Text("Track your workouts, analyze your progress, and achieve your fitness goals")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .offset(y: descriptionOffset) // Animated vertical position
                .opacity(showGetStarted ? 1 : 0) // Animated opacity
            
            Spacer()
            
            // Get Started Button with loading state
            Button {
                // Start loading animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isLoading = true
                }
                
                // Simulate API call delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Complete transition to authenticated state
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        authManager.isAuthenticated = true
                        isLoading = false
                    }
                }
            } label: {
                HStack(spacing: 15) {
                    // Show spinner during loading
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        // Normal button state
                        Text("Get Started")
                            .fontWeight(.bold)
                        
                        Image(systemName: "arrow.right")
                            .font(.title3)
                    }
                }
                .foregroundColor(.white)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(
                    // Gradient background for button
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 10)
            }
            .padding(.horizontal, 30)
            .scaleEffect(buttonScale) // Animated scale
            .opacity(showGetStarted ? 1 : 0) // Animated opacity
            .disabled(isLoading) // Prevent multiple taps during loading
        }
        .padding(.bottom, 50)
        // Start entrance animations when view appears
        .onAppear {
            // Animate title with slight delay
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                titleOffset = 0
                showGetStarted = true
            }
            
            // Animate description with longer delay
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) {
                descriptionOffset = 0
            }
            
            // Animate button with longest delay
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.7)) {
                buttonScale = 1
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    ContentView()
}
