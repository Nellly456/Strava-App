 //https://ai.google.dev/gemini-api/docs/openai
//https://ai.google.dev/gemini-api/docs
//https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/call-vertex-using-openai-library
//https://aistudio.google.com/apikey?_gl=1*1s0ldxm*_ga*NjU2OTY0ODczLjE3NDIyODcxOTE.*_ga_P1DBVKWT6V*MTc0MjQ4NzI0MS4zLjEuMTc0MjQ4NzI5NC43LjAuNDIxMzY3MzU3
//https://aider.chat/docs/llms/openai-compat.html



import Foundation
import CoreML

struct AIRecommendationEngine {
    // Data structures
    struct Recommendation {
        let trendType: TrendType
        let message: String
        let detailedAdvice: String
    }
    
    enum TrendType {
        case improvement
        case decline
        case constant
        case insufficient
    }
    
    enum RecommendationError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case jsonParsingError(Error)
        case invalidAPIKey
        case noDataAvailable
    }
    
    // DeepSeek API configuration
    private struct DeepSeekConfig {
        static let apiKey = "AIzaSyAhTqr1u7OOcv0L0Y6IwV6lY0ZF2OHDw5s"
        static let endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    }
    
    // Function to get AI-powered advice from DeepSeek with enhanced error handling
    func getDeepSeekRecommendation(performanceData: [PerformanceTrendData], dataType: String) async throws -> String {
        // Extract relevant metrics from data
        let metrics = prepareMetricsForAI(performanceData)
        
        // Check if we have data to analyze
        if metrics.isEmpty {
            throw RecommendationError.noDataAvailable
        }
        
        // Create prompt for DeepSeek
        let prompt = createPrompt(for: dataType, with: metrics)
        
        // Structure the request payload
        let requestBody = createRequestBody(with: prompt)
        
        // Convert request to JSON with better error handling
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            throw RecommendationError.jsonParsingError(error)
        }
        
        // Create URL request
        guard let url = URL(string: DeepSeekConfig.endpoint) else {
            throw RecommendationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(DeepSeekConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: RecommendationError.networkError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: RecommendationError.invalidResponse)
                    return
                }
                
                // Check for API key issues
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    continuation.resume(throwing: RecommendationError.invalidAPIKey)
                    return
                }
                
                // Check for other HTTP errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: RecommendationError.invalidResponse)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: RecommendationError.invalidResponse)
                    return
                }
                
                do {
                    if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = responseJSON["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        continuation.resume(returning: content)
                    } else {
                        // Try to print the actual response for debugging
                        if let responseStr = String(data: data, encoding: .utf8) {
                            print("Unexpected API response format: \(responseStr)")
                        }
                        continuation.resume(throwing: RecommendationError.invalidResponse)
                    }
                } catch {
                    continuation.resume(throwing: RecommendationError.jsonParsingError(error))
                }
            }
            task.resume()
        }
    }
    
    // Helper to create chart-specific prompts
    private func createPrompt(for dataType: String, with metrics: String) -> String {
        switch dataType {
        case "running speed":
            return """
            As a fitness coach, analyze these recent running speed metrics:
            
            \(metrics)
            
            Provide a personalized training recommendation based on these trends. Include:
            1. A brief summary of current performance
            2. Recommendations from the summary
            Limit to 3-4 sentences total.
            """
        case "running distance":
            return """
            As a fitness coach, analyze these recent running distance metrics:
            
            \(metrics)
            
            Provide a personalized training recommendation for distance improvement. Include:
            1. A brief summary of current distance capacity
            2. Recommendations from the summary
            Limit to 3-4 sentences total.
            """
        case "elevation gain":
            return """
            As a fitness coach, analyze these recent elevation gain metrics:
            
            \(metrics)
            
            Provide a personalized training recommendation for hill/elevation training. Include:
            1. A brief summary of current hill performance
            2. Recommendations from the summary
            Limit to 3-4 sentences total.
            """
        case "pace distribution":
            return """
            As a fitness coach, analyze this pace distribution data:
            
            \(metrics)
            
            Provide a personalized pace training recommendation. Include:
            1. An summary of current pace variability
            2. Recommendations from the summary
            Limit to 3-4 sentences total.
            """
        default:
            return """
            As a fitness coach, analyze these recent performance metrics for \(dataType):
            
            \(metrics)
            
            Provide a personalized training recommendation based on these trends. Include:
            1. A brief summary of current performance
            2. Recommendations from the summary
            Limit to 3-4 sentences total.
            """
        }
    }
    
    // Helper to create the API request body
    private func createRequestBody(with prompt: String) -> [String: Any] {
        return [
            "model": "gemini-2.0-flash",
            "messages": [
                ["role": "system", "content": "You are an expert fitness coach specializing in personalized training recommendations."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 300
        ]
    }
    
    // Helper to format performance data for AI consumption with better error handling
    private func prepareMetricsForAI(_ data: [PerformanceTrendData]) -> String {
        if data.isEmpty {
            return ""
        }
        
        let sortedData = data.sorted { $0.timestamp > $1.timestamp }
        let recentData = Array(sortedData.prefix(5)) // Last 5 data points
        
        return recentData.enumerated().map { index, entry -> String in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            return "Day \(index+1) (\(dateFormatter.string(from: entry.timestamp))): " +
                   "Speed: \(String(format: "%.2f", entry.speedValue)) km/h, " +
                   "Distance: \(String(format: "%.2f", entry.distanceValue)) km"
        }.joined(separator: "\n")
    }
    
    // Create fallback recommendations when AI fails
    func createFallbackRecommendation(for trendType: TrendType, dataType: String) -> Recommendation {
        let message: String
        let detailedAdvice: String
        
        switch (trendType, dataType) {
        case (.improvement, "running speed"):
            message = "Your speed is improving!"
            detailedAdvice = "Your recent speed gains show you're making progress. Try adding one sprint session per week, alternating between 30-second and 60-second efforts with full recovery. Focus on maintaining your form during speedwork."
            
        case (.improvement, "running distance"):
            message = "Your distance capacity is growing!"
            detailedAdvice = "Great progress on building distance. Continue with one longer run per week, increasing by no more than 10% each week. Make sure to take recovery days after your longer efforts."
            
        case (.improvement, "elevation gain"):
            message = "Your hill performance is improving!"
            detailedAdvice = "You're getting stronger on hills. Incorporate one dedicated hill session weekly, focusing on power on the uphills and recovery on the downhills. Add some calf raises and lunges to support continued improvement."
            
        case (.decline, "running speed"):
            message = "Your speed shows a temporary setback."
            detailedAdvice = "Recent speed metrics indicate you might need recovery. Focus on easy runs for the next week, then gradually reintroduce speedwork with 200m repeats at 5K pace. Ensure you're getting adequate protein and sleep."
            
        case (.decline, "running distance"):
            message = "Your distance capacity has decreased slightly."
            detailedAdvice = "Recent runs suggest you may need a recovery period. Scale back total weekly mileage by 20% for one week, then rebuild. Consider cross-training like cycling or swimming to maintain fitness while reducing impact."
            
        case (.decline, "elevation gain"):
            message = "Your hill performance has decreased."
            detailedAdvice = "Your hill metrics suggest possible fatigue. Take a week with flat routes only, then gradually reintroduce hills with a focus on form rather than speed. Consider adding glute strengthening exercises to your routine."
            
        case (.constant, _):
            message = "Your performance is stable."
            detailedAdvice = "Your metrics show consistency. To break through your current plateau, try adding variety with fartlek training (alternating fast and slow segments). Also consider mixing up your terrain and routes to challenge different muscle groups."
            
        case (.insufficient, _):
            message = "Not enough data available."
            detailedAdvice = "We need more activity data to provide personalized recommendations. Try to log at least 3-4 runs per week with your current device to receive tailored advice."
            
        default:
            message = "Performance analysis available."
            detailedAdvice = "Keep up with consistent training. Mix high and low intensity workouts throughout the week, with at least one rest or active recovery day. Stay hydrated and focus on quality sleep for optimal recovery."
        }
        
        return Recommendation(trendType: trendType, message: message, detailedAdvice: detailedAdvice)
    }
}
