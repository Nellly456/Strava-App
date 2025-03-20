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
        let distanceValue: Double 
        let elevationValue: Double// Distance metric
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
        
        
        @Published var speedRecommendationState: LoadingState = .idle
        @Published var distanceRecommendationState: LoadingState = .idle
        @Published var elevationRecommendationState: LoadingState = .idle
        @Published var paceDistributionRecommendationState: LoadingState = .idle
        
        @Published var chartDataLoadingState: LoadingState = .idle
        
        @Published var speedRecommendation: AIRecommendationEngine.Recommendation?
        @Published var distanceRecommendation: AIRecommendationEngine.Recommendation?
        @Published var elevationRecommendation: AIRecommendationEngine.Recommendation?
        @Published var paceDistributionRecommendation: AIRecommendationEngine.Recommendation?
        
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
            
            generatePerformanceTrendData(speedData: speedData, distanceData: distanceData, elevationData:elevationData)
        }
        
        private func generatePerformanceTrendData(speedData: [TimeSeriesData], distanceData: [TimeSeriesData], elevationData: [TimeSeriesData]) {
            var speedByDate: [Date: Double] = [:]
            var elevationByDate: [Date: Double] = [:]
            
            // Process speed data
            for item in speedData {
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: item.timestamp)
                if let date = calendar.date(from: dateComponents) {
                    speedByDate[date] = item.value
                }
            }
            
            // Process elevation data
            for item in elevationData {
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: item.timestamp)
                if let date = calendar.date(from: dateComponents) {
                    elevationByDate[date] = item.value
                }
            }
            
            var trendData: [PerformanceTrendData] = []
            for distanceItem in distanceData {
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: distanceItem.timestamp)
                if let date = calendar.date(from: dateComponents),
                   let speed = speedByDate[date],
                   let elevation = elevationByDate[date] {
                    let performanceIndex = (speed * 0.4) + (distanceItem.value * 0.6)
                    trendData.append(PerformanceTrendData(
                        timestamp: date,
                        speedValue: speed,
                        distanceValue: distanceItem.value,
                        elevationValue: elevation,
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
    // Add this extension to the existing DashboardViewModel class
    extension DashboardViewModel {
        // Enum to track loading states
        enum LoadingState {
            case idle
            case loading
            case success
            case error(Error)
        }
        
        // Add these properties to the main class
       
        
        // Enhanced data fetching with error handling
        func fetchChartData() {
            chartDataLoadingState = .loading
            
            Task {
                do {
                    await authManager.syncActivities()
                    let activities = authManager.activities
                    
                    if activities.isEmpty {
                        await MainActor.run {
                            self.chartDataLoadingState = .error(NSError(domain: "NoData", code: 1, userInfo: [NSLocalizedDescriptionKey: "No activity data available"]))
                        }
                        return
                    }
                    
                    await prepareChartData(activities: activities)
                    
                    await MainActor.run {
                        self.chartDataLoadingState = .success
                    }
                } catch {
                    await MainActor.run {
                        self.chartDataLoadingState = .error(error)
                    }
                }
            }
        }
        
        // Get AI recommendation for speed data
        func getSpeedRecommendation() async -> AIRecommendationEngine.Recommendation {
            await MainActor.run {
                self.speedRecommendationState = .loading
            }
            
            do {
                let aiAdvice = try await aiEngine.getDeepSeekRecommendation(
                    performanceData: self.filteredTrendData(),
                    dataType: "running speed"
                )
                
                let recommendation = AIRecommendationEngine.Recommendation(
                    trendType: determineSpeedTrendType(),
                    message: "Speed Analysis",
                    detailedAdvice: aiAdvice
                )
                
                await MainActor.run {
                    self.speedRecommendation = recommendation
                    self.speedRecommendationState = .success
                }
                
                return recommendation
            } catch {
                let fallbackRecommendation = aiEngine.createFallbackRecommendation(
                    for: determineSpeedTrendType(),
                    dataType: "running speed"
                )
                
                await MainActor.run {
                    self.speedRecommendation = fallbackRecommendation
                    self.speedRecommendationState = .error(error)
                }
                
                return fallbackRecommendation
            }
        }
        
        // Get AI recommendation for distance data
        func getDistanceRecommendation() async -> AIRecommendationEngine.Recommendation {
            await MainActor.run {
                self.distanceRecommendationState = .loading
            }
            
            do {
                let aiAdvice = try await aiEngine.getDeepSeekRecommendation(
                    performanceData: self.filteredTrendData(),
                    dataType: "running distance"
                )
                
                let recommendation = AIRecommendationEngine.Recommendation(
                    trendType: determineDistanceTrendType(),
                    message: "Distance Analysis",
                    detailedAdvice: aiAdvice
                )
                
                await MainActor.run {
                    self.distanceRecommendation = recommendation
                    self.distanceRecommendationState = .success
                }
                
                return recommendation
            } catch {
                let fallbackRecommendation = aiEngine.createFallbackRecommendation(
                    for: determineDistanceTrendType(),
                    dataType: "running distance"
                )
                
                await MainActor.run {
                    self.distanceRecommendation = fallbackRecommendation
                    self.distanceRecommendationState = .error(error)
                }
                
                return fallbackRecommendation
            }
        }
        
        // Get AI recommendation for elevation data
        func getElevationRecommendation() async -> AIRecommendationEngine.Recommendation {
            await MainActor.run {
                self.elevationRecommendationState = .loading
            }
            
            do {
                let aiAdvice = try await aiEngine.getDeepSeekRecommendation(
                    performanceData: self.filteredTrendData(),
                    dataType: "elevation gain"
                )
                
                let recommendation = AIRecommendationEngine.Recommendation(
                    trendType: determineElevationTrendType(),
                    message: "Elevation Analysis",
                    detailedAdvice: aiAdvice
                )
                
                await MainActor.run {
                    self.elevationRecommendation = recommendation
                    self.elevationRecommendationState = .success
                }
                
                return recommendation
            } catch {
                let fallbackRecommendation = aiEngine.createFallbackRecommendation(
                    for: determineElevationTrendType(),
                    dataType: "elevation gain"
                )
                
                await MainActor.run {
                    self.elevationRecommendation = fallbackRecommendation
                    self.elevationRecommendationState = .error(error)
                }
                
                return fallbackRecommendation
            }
        }
        
        // Get AI recommendation for pace distribution
        func getPaceDistributionRecommendation() async -> AIRecommendationEngine.Recommendation {
            await MainActor.run {
                self.paceDistributionRecommendationState = .loading
            }
            
            // Prepare special metrics for pace distribution
            let paceMetrics = preparePaceMetricsForAI()
            
            do {
                let aiAdvice = try await aiEngine.getDeepSeekRecommendation(
                    performanceData: self.filteredTrendData(),
                    dataType: "pace distribution"
                )
                
                let recommendation = AIRecommendationEngine.Recommendation(
                    trendType: determinePaceTrendType(),
                    message: "Pace Distribution Analysis",
                    detailedAdvice: aiAdvice
                )
                
                await MainActor.run {
                    self.paceDistributionRecommendation = recommendation
                    self.paceDistributionRecommendationState = .success
                }
                
                return recommendation
            } catch {
                let fallbackRecommendation = aiEngine.createFallbackRecommendation(
                    for: determinePaceTrendType(),
                    dataType: "pace distribution"
                )
                
                await MainActor.run {
                    self.paceDistributionRecommendation = fallbackRecommendation
                    self.paceDistributionRecommendationState = .error(error)
                }
                
                return fallbackRecommendation
            }
        }
        
        // Get comprehensive AI recommendation (original function, now with error handling)
        func getAIEnhancedRecommendation() async -> AIRecommendationEngine.Recommendation {
            let basicRecommendation = self.getPerformanceRecommendation()
            let dataType = self.trendDisplayMode == .speed ? "running speed" : "running distance"
            
            do {
                // Get enhanced advice from DeepSeek
                let aiAdvice = try await aiEngine.getDeepSeekRecommendation(
                    performanceData: self.filteredTrendData(),
                    dataType: dataType
                )
                
                // Return enhanced recommendation with AI-generated detailed advice
                return AIRecommendationEngine.Recommendation(
                    trendType: basicRecommendation.trendType,
                    message: basicRecommendation.message,
                    detailedAdvice: aiAdvice
                )
            } catch {
                print("AI recommendation error: \(error)")
                // If the API call fails, use fallback recommendation
                return aiEngine.createFallbackRecommendation(
                    for: basicRecommendation.trendType,
                    dataType: dataType
                )
            }
        }
        
        // Helper methods to determine trend types for various metrics
        private func determineSpeedTrendType() -> AIRecommendationEngine.TrendType {
            let recentData = filteredSpeedData().suffix(3)
            if recentData.count < 2 {
                return .insufficient
            } else {
                let firstValue = recentData.first?.value ?? 0
                let lastValue = recentData.last?.value ?? 0
                let percentChange = firstValue > 0 ? (lastValue - firstValue) / firstValue * 100 : 0
                
                if percentChange > 5 {
                    return .improvement
                } else if percentChange < -5 {
                    return .decline
                } else {
                    return .constant
                }
            }
        }
        
        private func determineDistanceTrendType() -> AIRecommendationEngine.TrendType {
            let recentData = filteredDistanceData().suffix(3)
            if recentData.count < 2 {
                return .insufficient
            } else {
                let firstValue = recentData.first?.distance ?? 0
                let lastValue = recentData.last?.distance ?? 0
                let percentChange = firstValue > 0 ? (lastValue - firstValue) / firstValue * 100 : 0
                
                if percentChange > 5 {
                    return .improvement
                } else if percentChange < -5 {
                    return .decline
                } else {
                    return .constant
                }
            }
        }
        
        private func determineElevationTrendType() -> AIRecommendationEngine.TrendType {
            let recentData = filteredElevationData().suffix(3)
            if recentData.count < 2 {
                return .insufficient
            } else {
                let firstValue = recentData.first?.value ?? 0
                let lastValue = recentData.last?.value ?? 0
                let percentChange = firstValue > 0 ? (lastValue - firstValue) / firstValue * 100 : 0
                
                if percentChange > 10 {
                    return .improvement
                } else if percentChange < -10 {
                    return .decline
                } else {
                    return .constant
                }
            }
        }
        
        private func determinePaceTrendType() -> AIRecommendationEngine.TrendType {
            let runData = filteredRunData()
            
            // If insufficient data, report that
            if runData.count < 3 {
                return .insufficient
            }
            
            // Calculate pace consistency (lower standard deviation is better)
            let values = runData.map { $0.value }
            let mean = values.reduce(0, +) / Double(values.count)
            let sumSquaredDiff = values.reduce(0) { $0 + pow($1 - mean, 2) }
            let standardDeviation = sqrt(sumSquaredDiff / Double(values.count))
            
            // Lower standard deviation indicates more consistent pacing
            if standardDeviation < 0.5 {
                return .improvement
            } else if standardDeviation > 1.5 {
                return .decline
            } else {
                return .constant
            }
        }
        
        // Helper method to format pace distribution data for AI consumption
        private func preparePaceMetricsForAI() -> String {
            let runData = filteredRunData()
            
            // Create categories based on pace/speed
            let fastRuns = runData.filter { $0.value > 12.0 }.count
            let moderateRuns = runData.filter { $0.value >= 8.0 && $0.value <= 12.0 }.count
            let slowRuns = runData.filter { $0.value < 8.0 }.count
            
            let total = Double(fastRuns + moderateRuns + slowRuns)
            
            guard total > 0 else { return "Insufficient pace data" }
            
            // Format as percentages
            let fastPercentage = Double(fastRuns) / total * 100.0
            let moderatePercentage = Double(moderateRuns) / total * 100.0
            let slowPercentage = Double(slowRuns) / total * 100.0
            
            return """
            Fast Pace (>12 km/h): \(fastRuns) runs (\(String(format: "%.1f", fastPercentage))%)
            Moderate Pace (8-12 km/h): \(moderateRuns) runs (\(String(format: "%.1f", moderatePercentage))%)
            Slow Pace (<8 km/h): \(slowRuns) runs (\(String(format: "%.1f", slowPercentage))%)
            Total runs: \(Int(total))
            """
        }
    }
