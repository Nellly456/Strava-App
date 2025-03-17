import SwiftUI
import Charts
import FamilyControls
import ManagedSettings
import DeviceActivity

// Data structure for app usage information
struct AppUsageData: Identifiable {
    let id = UUID()
    let appName: String      // Name of the application
    let timeInHours: Double  // Time spent in hours
    var color: Color         // Color for visualization
}

// Data structure for time series data points
struct TimeSeriesData: Identifiable {
    let id = UUID()
    let timestamp: Date      // When the data point was recorded
    let value: Double
    let distance: Double
}

// Data structure for combined performance metrics
struct PerformanceTrendData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let speedValue: Double       // Speed metric
    let distanceValue: Double    // Distance metric
    let performanceIndex: Double // Combined performance calculation
}




// Display mode options for trend visualization
enum TrendDisplayMode: String, CaseIterable {
    case speed = "Speed"
    case distance = "Distance"
}

// Main view model class for the dashboard
@MainActor
class DashboardViewModel: ObservableObject {
    
    let aiEngine = AIRecommendationEngine()
    @Published var screenTimeData: [AppUsageData] = []
    @Published var revenueData: [TimeSeriesData]
    @Published var performanceData: [TimeSeriesData]
    @Published var selectedTimeRange: TimeRange = .week  // Default to weekly view
    @Published var selectedChart: String? = nil
    @Published var showingDetail = false
    @Published var speedData: [TimeSeriesData] = []
    @Published var distanceData: [TimeSeriesData] = []
    @Published var elevationData: [TimeSeriesData] = []
    @Published var activityData: [TimeSeriesData] = []
    @Published var runData: [TimeSeriesData] = []
    @Published var trendData: [PerformanceTrendData] = []
    @Published var trendDisplayMode: TrendDisplayMode = .speed // Default display mode
    
    private var authManager = AuthenticationManager()
    
    
    func getHeatmapColor(for value: Double) -> Color {
          let normalizedValue = min(1.0, max(0.2, value / (maxElevationValue() > 0 ? maxElevationValue() : 1)))
          return Color.blue.opacity(normalizedValue)
      }
      
      // Add these functions if they don't exist
      func maxElevationValue() -> Double {
          let maxValue = filteredElevationData().map { $0.value }.max() ?? 1.0
          return maxValue
      }
      
      func averageElevationValue() -> Double {
          let values = filteredElevationData().map { $0.value }
          return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
      }
    func averageDistanceValue() -> Double {
        let values = filteredDistanceData().map { $0.value }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    // Time range options for filtering data
    enum TimeRange: String, CaseIterable {
//        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week:  return 7
            case .month: return 30
            case .year:  return 365
            }
        }
    }
    
    init() {
        self.revenueData = []
        self.performanceData = []
        self.speedData = []
        self.distanceData = []
    }
    
    func requestAuthorization() {
        print("Requesting authorization")
        Task {
            await authManager.syncActivities()
            let activities = authManager.activities
           
            await prepareChartData(activities: activities)
        }
    }
    
    private func prepareChartData(activities: [[String: Any]]) {
        let speedData: [TimeSeriesData] = activities.compactMap { activity in
            guard let startDateStr = activity["start_date"] as? String,
                  let averageSpeed = activity["average_speed"] as? Double,
                  let distance = activity["distance"] as? Double,
                  let startDate = ISO8601DateFormatter().date(from: startDateStr)
            else { return nil }
            return TimeSeriesData(timestamp: startDate, value: averageSpeed, distance: distance)
        }
        
        let distanceData: [TimeSeriesData] = activities.compactMap { activity in
            guard let startDateStr = activity["start_date"] as? String,
                  let averageSpeed = activity["average_speed"] as? Double,
                  let distance = activity["distance"] as? Double,
                  let startDate = ISO8601DateFormatter().date(from: startDateStr)
            else { return nil }
            return TimeSeriesData(timestamp: startDate, value: averageSpeed, distance: distance)
        }
        let elevationData: [TimeSeriesData] = activities.compactMap { activity in
            guard let startDateStr = activity["start_date"] as? String,
                  let averageSpeed = activity["total_elevation_gain"] as? Double,
                  let distance = activity["distance"] as? Double,
                  let startDate = ISO8601DateFormatter().date(from: startDateStr)
            else { return nil }
            return TimeSeriesData(timestamp: startDate, value: averageSpeed, distance: distance)
        }
        let runData: [TimeSeriesData] = activities.compactMap { activity in
            guard let startDateStr = activity["start_date"] as? String,
                  let averageSpeed = activity["type"] as? Double,
                  let distance = activity["distance"] as? Double,
                  let startDate = ISO8601DateFormatter().date(from: startDateStr)
            else { return nil }
            return TimeSeriesData(timestamp: startDate, value: averageSpeed, distance: distance)
        }
        // Create data for both Distance and Elevation Gain
      
        
        self.speedData = speedData
        self.distanceData = distanceData
        self.elevationData = elevationData
        self.runData = elevationData
        
        generatePerformanceTrendData(speedData: speedData, distanceData: distanceData)
    }
    
    private func generatePerformanceTrendData(speedData: [TimeSeriesData], distanceData: [TimeSeriesData]) {
        var speedByDate: [Date: Double] = [:]
        for item in speedData {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: item.timestamp)
            if let date = calendar.date(from: dateComponents) {
                speedByDate[date] = item.value
            }
        }
        
        var trendData: [PerformanceTrendData] = []
        for distanceItem in distanceData {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: distanceItem.timestamp)
            if let date = calendar.date(from: dateComponents),
               let speed = speedByDate[date] {
                let performanceIndex = (speed * 0.4) + (distanceItem.value * 0.6)
                trendData.append(PerformanceTrendData(
                    timestamp: date,
                    speedValue: speed,
                    distanceValue: distanceItem.distance,
                    performanceIndex: performanceIndex
                ))
            }
        }
        
        self.trendData = trendData.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    func filteredTrendData() -> [PerformanceTrendData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return trendData.filter { $0.timestamp >= startDate }
    }
    
    func filteredSpeedData() -> [TimeSeriesData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return speedData.filter { $0.timestamp >= startDate }
    }
    
    func filteredDistanceData() -> [TimeSeriesData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return distanceData.filter { $0.timestamp >= startDate }
    }
    
    func filteredElevationData() -> [TimeSeriesData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return elevationData.filter { $0.timestamp >= startDate }
    }
    func filteredRunData() -> [TimeSeriesData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return runData.filter { $0.timestamp >= startDate }
    }
    
    func getPerformanceRecommendation() -> AIRecommendationEngine.Recommendation {
        // Analyze data to determine trend type
        let trendType: AIRecommendationEngine.TrendType
        
        // Simple logic to determine trend type based on recent data
        let recentData = filteredTrendData().suffix(3) // Last 3 data points
        if recentData.count < 2 {
            trendType = .insufficient
        } else {
            let firstValue = recentData.first?.speedValue ?? 0
            let lastValue = recentData.last?.speedValue ?? 0
            let percentChange = firstValue > 0 ? (lastValue - firstValue) / firstValue * 100 : 0
            
            if percentChange > 5 {
                trendType = .improvement
            } else if percentChange < -5 {
                trendType = .decline
            } else {
                trendType = .constant
            }
        }
        
        // Create appropriate message based on trend
        let message: String
        let detailedAdvice: String
        
        switch trendType {
        case .improvement:
            message = "Great progress! Your performance is improving."
            detailedAdvice = "Keep up the good work. Try increasing your distance by 10% this week to build on your momentum."
        case .decline:
            message = "Your performance shows a slight decrease."
            detailedAdvice = "Consider a recovery week with lighter workouts, then gradually build back up. Focus on proper nutrition and sleep."
        case .constant:
            message = "Your performance has been consistent."
            detailedAdvice = "Try adding interval training to break through your plateau. Mix up your routes to keep things interesting."
        case .insufficient:
            message = "Not enough data to analyze trends."
            detailedAdvice = "Track a few more workouts so we can provide personalized recommendations."
        }
        
        return AIRecommendationEngine.Recommendation(
            trendType: trendType,
            message: message,
            detailedAdvice: detailedAdvice
        )
    }
    
    func getTimeRangeDescription() -> String {
        switch selectedTimeRange {
        case .week:  return "Last 7 days"
        case .month: return "Last 30 days"
        case .year:  return "Last 12 months"
        }
    }
    
    func getXAxisStride() -> Calendar.Component {
        switch selectedTimeRange {
        case .week, .month: return .day
        case .year:  return .month
        }
    }
    
    func getDateFormat() -> Date.FormatStyle {
        switch selectedTimeRange {
        case .week, .month: return .dateTime.month().day()
        case .year:  return .dateTime.month().year()
        }
    }
}
extension DashboardViewModel {
    // Get AI-powered recommendation for speed
    func getDeepSeekSpeedRecommendation() async -> String {
        return await aiEngine.getDeepSeekRecommendation(
            performanceData: self.filteredTrendData(),
            dataType: "running speed"
        )
    }
    
    // Get AI-powered recommendation for distance
    func getDeepSeekDistanceRecommendation() async -> String {
        return await aiEngine.getDeepSeekRecommendation(
            performanceData: self.filteredTrendData(),
            dataType: "running distance"
        )
    }
    
    // Get comprehensive AI recommendation
    func getAIEnhancedRecommendation() async -> AIRecommendationEngine.Recommendation {
        let basicRecommendation = self.getPerformanceRecommendation()
        let dataType = self.trendDisplayMode == .speed ? "running speed" : "running distance"
        
        // Get enhanced advice from DeepSeek
        let aiAdvice = await aiEngine.getDeepSeekRecommendation(
            performanceData: self.filteredTrendData(),
            dataType: dataType
        )
        
        // Return enhanced recommendation with AI-generated detailed advice
        return AIRecommendationEngine.Recommendation(
            trendType: basicRecommendation.trendType,
            message: basicRecommendation.message,
            detailedAdvice: aiAdvice
        )
    }
}
