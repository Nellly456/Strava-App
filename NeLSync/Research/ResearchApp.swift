// ResearchApp.swift
import SwiftUI

@main
struct ResearchApp: App {
    // Authentication manager for handling user authentication state
    @StateObject private var authManager = AuthenticationManager()
    
    // AppDelegate instance for handling application lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
//            ScreenTimeView()
            ContentView()
                .onOpenURL { url in
                    Task {
                        // Handle URL redirection for authentication
                        try? await authManager.handleRedirect(url: url)
                    }
                }
                .onAppear {
                    // Share the authManager instance with AppDelegate
                    appDelegate.setAuthManager(authManager)
                }
        }
    }
}

// AppDelegate.swift
class AppDelegate: NSObject, UIApplicationDelegate {
    // Authentication manager instance for handling authentication-related tasks
    private var authManager: AuthenticationManager?
    
    /// Sets the authentication manager instance
    func setAuthManager(_ manager: AuthenticationManager) {
        self.authManager = manager
    }
    
    /// Called when the app finishes launching
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("DEBUG: App did finish launching")
        return true
    }
    
    /// Called when the app is opened via a URL scheme
    func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("DEBUG: AppDelegate received URL: \(url)")
        return handleIncomingURL(url)
    }
    
    /// Handles incoming authentication-related URLs
    private func handleIncomingURL(_ url: URL) -> Bool {
        print("DEBUG: Handling URL: \(url)")
        print("DEBUG: URL components: \(url.absoluteString)")
        print("DEBUG: URL scheme: \(url.scheme ?? "nil")")
        print("DEBUG: URL host: \(url.host ?? "nil")")
        print("DEBUG: URL path: \(url.path)")
        print("DEBUG: URL query: \(url.query ?? "nil")")
        
        // Ensure the URL scheme matches the expected value
        guard url.scheme?.lowercased() == "att" else {
            print("DEBUG: Invalid URL scheme")
            return false
        }
        
        // Asynchronously handle the authentication redirect
        Task {
            try? await authManager?.handleRedirect(url: url)
        }
        return true
    }
}
