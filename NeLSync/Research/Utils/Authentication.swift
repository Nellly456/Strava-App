//https://developers.strava.com/docs/reference/#api-Athletes
//https://developers.strava.com/playground/
//https://supabase.com/docs/reference/swift/start
//https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
//https://developer.apple.com/documentation/authenticationservices/authenticating-a-user-through-a-web-service
//https://stackoverflow.com/questions/60145310/using-aswebauthentication-in-swiftui

//https://github.com/auth0/Auth0.swift/blob/master/Auth0/WebAuth.swift




import Foundation
import Network
import AuthenticationServices
import SwiftUI
import Combine
import Supabase

/**
 * AuthenticationManager: Handles Strava authentication and user data management
 * - Manages OAuth 2.0 authentication with Strava
 * - Stores user data and access tokens
 * - Syncs user activities between Strava and Supabase
 */
@MainActor
class AuthenticationManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Published Properties
    
    /// Indicates if the user is currently authenticated
    @Published var isAuthenticated: Bool = false
    
    /// The current Strava access token
    @Published var accessToken: String? = nil
    @Published var refreshToken: String? = nil
    
    /// The authenticated user's information
    @Published var user: User? = nil
    
    /// Collection of user's activities from Strava
    @Published var activities: [[String: Any]] = []
    
    // MARK: - Private Constants
    
    /// Strava OAuth client ID
    private let clientID = "147295"
    
    /// Strava OAuth client secret
    private let clientSecret = "94886c1fcad9333d1e7383c1d02fcb42d26dfbb0"
    
    /// OAuth redirect URI for callback handling
    private let redirectURI = "att://att.com/oauth/mobile/callback/strava"
    
    /// Supabase backend URL
    private let supabaseURL = "https://giuzfwdleogsfpsnphgs.supabase.co"
    
    /// Supabase API key
    private let supabaseAPIKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpdXpmd2RsZW9nc2Zwc25waGdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg5Mzc3MzMsImV4cCI6MjA1NDUxMzczM30.EIAv7aIeILgv-9AVGA1jff_aM4stJ8nYCTwOghvfv_M"
    
    // MARK: - Private Properties
    
    /// Store for Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Supabase client for database operations
    private var client: SupabaseClient!
    
    // MARK: - Initialization
    
    /**
     * Initialize the AuthenticationManager
     * Sets up the Supabase client and checks for existing authentication
     */
    override init() {
        super.init()
        // Initialize Supabase client with URL and API key
        client = SupabaseClient(supabaseURL: URL(string: supabaseURL)!,
                              supabaseKey: supabaseAPIKey)
        
        // Check if we have a saved token from previous sessions
        if let savedToken = UserDefaults.standard.string(forKey: "accessToken") {
            self.accessToken = savedToken
            self.isAuthenticated = true
            
//            print("Access token found in UserDefaults")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /**
     * Provides the anchor for presenting the authentication session
     * Required by ASWebAuthenticationPresentationContextProviding protocol
     */
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    // MARK: - Authentication Methods
    
    /**
     * Initiates the Strava authentication flow
     * Uses ASWebAuthenticationSession to present the Strava login page
     */
    func authenticateWithStrava() async throws {
        // Define the required scope for Strava API access
        let scope = "activity:read_all"
        // Construct the Strava authorization URL
        let stravaAuthURL = "https://www.strava.com/oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&scope=\(scope)"
        
        // Open web authentication and await the authorization code
        let code = try await authenticateInWebView(url: stravaAuthURL)
        UserDefaults.standard.set(code, forKey: "refresh")
        // Exchange the code for an access token
        await exchangeCodeForAccessToken(code: code)
    }
    
    /**
     * Handles redirect callbacks from the Strava OAuth flow
     * Extracts the authorization code from the URL and exchanges it for a token
     */
    func handleRedirect(url: URL) async throws {
        print("DEBUG: Handling redirect in AuthManager: \(url)")
        
        // Extract the authorization code from the callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"])
        }
        
        // Exchange the code for an access token
        await exchangeCodeForAccessToken(code: code)
    }
    
    /**
     * Presents a web authentication session to the user
     * Returns the authorization code from the callback
     */
    private func authenticateInWebView(url: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let authURL = URL(string: url) else {
                continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                return
            }
            
            // Create and configure the web authentication session
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "att"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Extract the authorization code from the callback URL
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"]))
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            // Set the presentation context provider and start the session
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = true
            
            if !authSession.start() {
                continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start auth session"]))
            }
        }
    }
    
    /**
     * Exchanges an authorization code for an access token
     * Sends a POST request to Strava's token endpoint
     */
    private func exchangeCodeForAccessToken(code: String) async {
        print("Starting token exchange") // Debug log
        
        // Prepare the token exchange request
        guard let url = URL(string: "https://www.strava.com/oauth/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the required parameters for the token request
        let parameters: [String: Any] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        do {
            // Send the request and process the response
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let token = json["access_token"] as? String,
               let freshToken = json["refresh_token"] as? String  {
                // Update authentication state on the main actor
                await MainActor.run {
                    self.accessToken = token
                    self.refreshToken = freshToken
                    print(token)
                    self.isAuthenticated = true
                    print("Set access token and authenticated state") // Debug log
                }
                // Save the token for future sessions
                UserDefaults.standard.set(token, forKey: "accessToken")
                print("Saved token to UserDefaults") // Debug log
                UserDefaults.standard.set(freshToken, forKey: "refreshToken")
                print("Saved token to UserDefaults")
                // Fetch user details with the new token
                await fetchUserDetails(token: token)
            }
        } catch {
            print("Error exchanging code for token: \(error)")
        }
    }

    /**
     * Fetches user details from Strava API
     * Uses the access token to retrieve the authenticated user's profile
     */
    private func fetchUserDetails(token: String) async {
        print("Starting fetchUserDetails with token") // Debug log
        
        guard let url = URL(string: "https://www.strava.com/api/v3/athlete") else { return }

        // Prepare the user details request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            // Send the request and process the response
            let (data, _) = try await URLSession.shared.data(for: request)
            if let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Received user data from Strava: \(userData)") // Debug log
                
                // Extract the Strava ID and save it
                let stravaID = String(describing: userData["id"] ?? "")
                UserDefaults.standard.set(stravaID, forKey: "stravaID")
                
                // Create a User object from the response data
                let user = User(
                    username: userData["username"] as? String ?? "No Username",
                    stravaID: stravaID,
                    name: "\(userData["firstname"] as? String ?? "") \(userData["lastname"] as? String ?? "")",
                    email: userData["email"] as? String ?? "Email not available",
                    profileURL: userData["profile"] as? String ?? "No profile URL"
                )
                
                // Update the user property on the main actor
                await MainActor.run {
                    self.user = user
                    print("Set self.user to: \(user)") // Debug log
                }
                
                // Save the user data to Supabase
                print("About to save user to Supabase") // Debug log
                await saveUserDataToSupabase(user: user)
            }
        } catch {
            print("Error fetching user details: \(error)")
        }
    }

    /**
     * Saves or updates user data in Supabase
     * Checks if the user exists and updates or creates accordingly
     */
    func saveUserDataToSupabase(user: User) async {
        do {
            // Define UserData struct for Supabase operations
            struct UserData: Codable {
                let id: Int?  // Make id optional since it won't be present for new users
                let username: String
                let strava_id: String
                let name: String
                let email: String
                let profile_url: String
                let access_token: String
            }
            
            // Check if the user already exists in Supabase
            let existingUsers: [UserData] = try await client
                .from("users")
                .select()
                .eq("strava_id", value: user.stravaID)
                .execute()
                .value
            
            // Prepare the user data for Supabase
            let userData = UserData(
                id: nil,  // Will be set by Supabase for new users
                username: user.username,
                strava_id: user.stravaID,
                name: user.name,
                email: user.email,
                profile_url: user.profileURL,
                access_token: accessToken ?? ""
            )
            
            if let existingUser = existingUsers.first {
                // Update existing user
                let response = try await client
                    .from("users")
                    .update(userData)
                    .eq("id", value: existingUser.id ?? 0)
                    .execute()
                print("Updated user in Supabase: \(response)")
                await MainActor.run {
                    self.user = user
                    print("Set self.user to: \(user)") // Debug log
                }
            } else {
                // Create new user
                let response = try await client
                    .from("users")
                    .insert(userData)
                    .execute()
                print("Created new user in Supabase: \(response)")
                Task {
                    self.user = user
                    print("Set self.user to: \(user)") // Debug log
                }
            }
        } catch {
            print("Error saving user data to Supabase: \(error.localizedDescription)")
        }
    }
   
    /**
     * Fetches user data from Supabase using Strava ID
     * Updates the local user object with data from Supabase
     */
    func fetchUserFromSupabase(stravaId: String) async {
        print("Starting fetch with Strava ID: \(stravaId)")
        print(self.user) // Check input
        
        do {
            // Define the structure for user data from Supabase
            struct UserData: Decodable {
                let id: Int
                let username: String
                let strava_id: String
                let name: String
                let email: String
                let profile_url: String
                let access_token: String
            }
            
            // Query Supabase for the user with the given Strava ID
            let response: [UserData] = try await client
                .from("users")
                .select()
                .eq("strava_id", value: stravaId)
                .execute()
                .value
            
            print("Response received: \(response)") // Check the response
            print("Self.user after assignment: \(String(describing: self.user))") //
            if response.isEmpty {
                print("Response array is empty - no user found")
                return
            }
            
            // Create a User object from the first matching result
            if let userData = response.first {
                print("UserData found: \(userData)") // Check the user data
                
                let user = User(
                    username: userData.username,
                    stravaID: userData.strava_id,
                    name: userData.name,
                    email: userData.email,
                    profileURL: userData.profile_url
                )
                
                print("User created: \(user)") // Check the created user
                self.user = user
                print("Self.user after assignment: \(String(describing: self.user))") // Check final assignment
            } else {
                print("Failed to get first item from response")
            }
        } catch {
            print("Error fetching user data from Supabase:")
            print("Error description: \(error.localizedDescription)")
            print("Full error: \(error)")
        }
    }
    
    /**
     * Signs out the current user
     * Clears authentication state and user data
     */
    func signOut() {
        accessToken = nil
        isAuthenticated = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "accessToken")
    }
    
    // MARK: - Activity Management
    
    /**
     * Structure for activity data in Supabase
     * Maps Strava activity fields to Supabase columns
     */
    struct SupabaseActivity: Codable {
        let strava_id: String
        let user_strava_id: String
        let name: String
        let type: String
        let distance: Double
        let moving_time: Int
        let elapsed_time: Int
        let start_date: String
        let average_speed: Double
        let max_speed: Double
        let total_elevation_gain: Double
    }

    
    
    
    
    
    func refreshStravaToken() async -> Bool {
        guard let token = UserDefaults.standard.string(forKey: "refreshToken") else {
                print("No authorization code found in UserDefaults")
                return false
            }
        
        guard let url = URL(string: "https://www.strava.com/oauth/token") else {
            print("Missing configuration values")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": token
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                print("Token refresh failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            if let tokenData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccessToken = tokenData["access_token"] as? String,
               let newRefreshToken = tokenData["refresh_token"] as? String {
                print("successful")
                // Update tokens
                await MainActor.run {
                    UserDefaults.standard.set(newAccessToken, forKey: "accessToken")
                    UserDefaults.standard.set(newRefreshToken, forKey: "refreshToken")
                }
                return true
            }
        } catch {
            print("Error refreshing token: \(error)")
        }
        
        return false
    }
    /**
     *
     *
     *
     * Fetches activities from the Strava API
     * Retrieves the user's activity data and updates the local state
     */
    func fetchActivitiesFromStrava() async {
        guard let token = UserDefaults.standard.string(forKey: "accessToken")else{
                print("No access token available")
            return
        }
        guard let url = URL(string: "https://www.strava.com/api/v3/athlete/activities") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 401 {
                print("Token expired, attempting to refresh...")
                let refreshed = await refreshStravaToken()
                if refreshed {
                    await fetchActivitiesFromStrava()  // Retry with new token
                } else {
                    print("Token refresh failed, user needs to re-authenticate")
                }
                return
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                print("Error: HTTP status code \(httpResponse.statusCode)")
                return
            }
            
            if let activitiesData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("Received \(activitiesData.count) activities from Strava")
                await MainActor.run {
                    self.activities = activitiesData
                }
                await saveActivitiesToSupabase(activities: activitiesData)
            } else {
                print("Invalid JSON structure")
            }
        } catch {
            print("Unexpected error: \(error)")
        }
    }

    /**
     * Saves activities to Supabase
     * Checks for existing activities and updates or creates accordingly
     */
    func saveActivitiesToSupabase(activities: [[String: Any]]) async {
        guard let stravaID = UserDefaults.standard.string(forKey: "stravaID")else {
            print("No Strava ID available")
            return
        }
        
        do {
            // Process each activity
            for activity in activities {
                // Convert to a string for the Strava ID to handle different possible types
                let stravaActivityId = "\(activity["id"] ?? "")"
                
                // Create a Supabase activity object from the Strava data
                let activityData = SupabaseActivity(
                    strava_id: stravaActivityId,
                    user_strava_id: stravaID,
                    name: activity["name"] as? String ?? "Unknown Activity",
                    type: activity["type"] as? String ?? "Unknown",
                    distance: activity["distance"] as? Double ?? 0.0,
                    moving_time: activity["moving_time"] as? Int ?? 0,
                    elapsed_time: activity["elapsed_time"] as? Int ?? 0,
                    start_date: activity["start_date"] as? String ?? "",
                    average_speed: activity["average_speed"] as? Double ?? 0.0,
                    max_speed: activity["max_speed"] as? Double ?? 0.0,
                    total_elevation_gain: activity["total_elevation_gain"] as? Double ?? 0.0
                )
                
                // Structure for checking existing activities
                struct ActivityCheck: Codable {
                    let id: Int
                    let strava_id: String
                }
                
                // Check if the activity already exists in Supabase
                let existingActivities: [ActivityCheck] = try await client
                    .from("activities")
                    .select("id, strava_id")
                    .eq("strava_id", value: stravaActivityId)
                    .execute()
                    .value
                
                if existingActivities.isEmpty {
                    // Insert new activity if it doesn't exist
                    let insertResponse = try await client
                        .from("activities")
                        .insert(activityData)
                        .execute()
                    print("Inserted activity: \(activity["name"] ?? "")")
                } else {
                    // Update existing activity if it already exists
                    let updateResponse = try await client
                        .from("activities")
                        .update(activityData)
                        .eq("strava_id", value: stravaActivityId)
                        .execute()
                    print("Updated activity: \(activity["name"] ?? "")")
                }
            }
        } catch {
            print("Error saving activities to Supabase: \(error.localizedDescription)")
        }
    }

    /**
     * Fetches activities from Supabase
     * Retrieves all activities for the current user
     */
    func fetchActivitiesFromSupabase() async {
        guard let stravaID = UserDefaults.standard.string(forKey: "stravaID")else {
            print("No Strava ID available")
            return
        }
        
        do {
            // Define the structure for activity data from Supabase
            struct ActivityData: Codable {
                let id: Int
                let strava_id: String
                let user_strava_id: String
                let name: String
                let type: String
                let distance: Double
                let moving_time: Int
                let elapsed_time: Int
                let start_date: String
                let average_speed: Double
                let max_speed: Double
                let total_elevation_gain: Double
            }
            
            // Query Supabase for activities matching the user's Strava ID
            let response: [ActivityData] = try await client
                .from("activities")
                .select()
                .eq("user_strava_id", value: stravaID)
                .order("start_date", ascending: false)
                .execute()
                .value
            
            // Convert ActivityData to dictionary format for consistency
            var activitiesArray: [[String: Any]] = []
            
            for activity in response {
                let activityDict: [String: Any] = [
                    "id": activity.id,
                    "strava_id": activity.strava_id,
                    "name": activity.name,
                    "type": activity.type,
                    "distance": activity.distance,
                    "moving_time": activity.moving_time,
                    "elapsed_time": activity.elapsed_time,
                    "start_date": activity.start_date,
                    "average_speed": activity.average_speed,
                    "max_speed": activity.max_speed,
                    "total_elevation_gain": activity.total_elevation_gain
                ]
                activitiesArray.append(activityDict)
            }
            
            // Update the activities property on the main actor
            await MainActor.run {
                self.activities = activitiesArray
                print("Fetched \(activitiesArray.count) activities from Supabase")
            }
        } catch {
            print("Error fetching activities from Supabase: \(error.localizedDescription)")
        }
    }

    /**
     * Synchronizes activities between Strava and Supabase
     * Fetches the latest activities from Strava and updates Supabase
     */
    func syncActivities() async {
        print("Starting activity sync")
        await fetchActivitiesFromStrava()
        await fetchActivitiesFromSupabase()
        print("Activity sync completed")
    }
}
