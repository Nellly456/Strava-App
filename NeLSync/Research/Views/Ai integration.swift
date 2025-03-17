import SwiftUI
import CoreML
import Foundation // For networking

// Add this extension for DeepSeek API calls
struct AIRecommendationEngine {
    // DeepSeek API configuration
    struct Recommendation {
            let trendType: TrendType
            let message: String
            let detailedAdvice: String
        }
        
        // TrendType enum definition
        enum TrendType {
            case improvement
            case decline
            case constant
            case insufficient
        }
    private struct DeepSeekConfig {
        static let apiKey = "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"
        static let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    }
    
    // Function to get AI-powered advice from DeepSeek
    func getDeepSeekRecommendation(performanceData: [PerformanceTrendData], dataType: String) async -> String {
        // Extract relevant metrics from data
        let metrics = prepareMetricsForAI(performanceData)
        
        // Check if we have data to analyze
        if metrics.isEmpty {
            return "Not enough performance data available to generate AI recommendations."
        }
        
        // Create prompt for DeepSeek
        let prompt = """
        As a fitness coach, analyze these recent performance metrics for \(dataType):
        
        \(metrics)
        
        Provide a personalized training recommendation based on these trends. Include:
        1. A brief assessment of current performance
        2. One specific workout suggestion
        3. One recovery tip
        Limit to 3-4 sentences total.
        """
        
        // Structure the request payload
        let requestBody: [String: Any] = [
            "model": "deepseek/deepseek-chat:free",
            "messages": [
                ["role": "system", "content": "You are an expert fitness coach specializing in personalized training recommendations."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 300
        ]
        
        // Convert request to JSON with better error handling
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            // Create URL request
            guard let url = URL(string: DeepSeekConfig.endpoint) else {
                print("Invalid API endpoint URL")
                return "Unable to connect to AI service. Using local recommendations instead."
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(DeepSeekConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            return await withCheckedContinuation { continuation in
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("DeepSeek API error: \(error)")
                        continuation.resume(returning: "Unable to connect to AI service. Using local recommendations instead.")
                        return
                    }
                    
                    guard let data = data else {
                        print("No data received from API")
                        continuation.resume(returning: "No data received from AI service.")
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
                            continuation.resume(returning: "Unable to parse AI response. Using local recommendations instead.")
                        }
                    } catch {
                        print("JSON parsing error: \(error)")
                        continuation.resume(returning: "Error processing AI response. Using local recommendations instead.")
                    }
                }
                task.resume()
            }
        } catch {
            print("JSON serialization error: \(error)")
            return "Unable to prepare AI request. Using local recommendations instead."
        }
    }
    
    // Helper to format performance data for AI consumption
    private func prepareMetricsForAI(_ data: [PerformanceTrendData]) -> String {
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
}
