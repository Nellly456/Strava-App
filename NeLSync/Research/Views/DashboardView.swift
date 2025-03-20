//https://developer.apple.com/documentation/charts
//https://developer.apple.com/documentation/charts/creating-a-chart-using-swift-charts
//https://blorenzop.medium.com/swiftui-charts-b6fa4aca46db
//https://developer.apple.com/documentation/swiftui/


import SwiftUI
import Charts

// Custom button view for time range selection
struct TimeRangeButton: View {
    let range: DashboardViewModel.TimeRange
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.system(.subheadline, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.3))
                )
        }
    }
}

// Reusable interactive chart container with press animation
struct InteractiveChartSection<Content: View>: View {
    var title: String = ""
    let subtitle: String
    let onTap: () -> Void
    let content: () -> Content
    @State private var isPressed = false
    @State private var showingRecommendation = false
    @State private var aiRecommendation: String?
    @State private var isLoadingRecommendation = false
    var getRecommendation: (() async -> String)? = nil

    var body: some View {
        VStack(alignment: .leading) {
            if !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Spacer()
                    
                    // AI Recommendation button
                    if getRecommendation != nil {
                        Button(action: {
                            loadRecommendation()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("AI Tips")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.2))
                            )
                        }
                        .disabled(isLoadingRecommendation)
                    }
                }
            }
            
            // AI Recommendation display
            if isLoadingRecommendation {
                HStack {
                    Spacer()
                    ProgressView("Loading AI recommendation...")
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if showingRecommendation, let recommendation = aiRecommendation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("AI Recommendation")
                            .font(.subheadline.bold())
                        
                        Spacer()
                        
                        Button(action: {
                            showingRecommendation = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.bottom, 8)
            }
            
            content()
                .frame(height: 250)
                .padding()
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    onTap()
                }
            }
        }
    }
    
    private func loadRecommendation() {
        guard let getRecommendation = getRecommendation, !isLoadingRecommendation else { return }
        
        isLoadingRecommendation = true
        
        Task {
            let recommendation = await getRecommendation()
            
            await MainActor.run {
                self.aiRecommendation = recommendation
                self.showingRecommendation = true
                self.isLoadingRecommendation = false
            }
        }
    }
}

// Detail view for expanded chart information
struct DetailView: View {
    let title: String
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed view for \(title)")
                        .font(.headline)
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                timeRangePicker
                chartsSection
            }
            .padding()
        }
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.requestAuthorization()
            print("DashboardView appeared")
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemGray6)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading) {
            Text("   ")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("   ")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("Dashboard")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("Your analytics overview")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DashboardViewModel.TimeRange.allCases, id: \.self) { range in
                    TimeRangeButton(
                        range: range,
                        isSelected: viewModel.selectedTimeRange == range,
                        action: { viewModel.selectedTimeRange = range }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var chartsSection: some View {
        VStack(spacing: 20) {
          
            
            // Performance Trend Analysis Chart
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Picker("Trend Mode", selection: $viewModel.trendDisplayMode) {
                        ForEach(TrendDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                
                InteractiveChartSection(
                    title: "Performance Trend Analysis",
                    subtitle: getTrendSubtitle(),
                    onTap: {
                        viewModel.selectedChart = "Performance Trend"
                        viewModel.showingDetail = true
                    },
                    content: {
                        Chart {
                            switch viewModel.trendDisplayMode {
                            case .speed:
                                ForEach(viewModel.filteredTrendData()) { data in
                                    AreaMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Speed", data.speedValue)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.6), .blue.opacity(0.2)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                ForEach(viewModel.filteredTrendData()) { data in
                                    LineMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Speed", data.speedValue)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                ForEach(viewModel.filteredTrendData()) { data in
                                    PointMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Speed", data.speedValue)
                                    )
                                    .foregroundStyle(Color.blue)
                                }
                            case .distance:
                                ForEach(viewModel.filteredTrendData()) { data in
                                    AreaMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Distance", data.distanceValue)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.6), .green.opacity(0.2)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                ForEach(viewModel.filteredTrendData()) { data in
                                    LineMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Distance", data.distanceValue)
                                    )
                                    .foregroundStyle(Color.green)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                ForEach(viewModel.filteredTrendData()) { data in
                                    PointMark(
                                        x: .value("Date", data.timestamp),
                                        y: .value("Distance", data.distanceValue)
                                    )
                                    .foregroundStyle(Color.green)
                                }
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: viewModel.getXAxisStride(), count: 4)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel { Text(date, format: viewModel.getDateFormat()) }
                                }
                            }
                        }
                        .chartYAxisLabel(viewModel.trendDisplayMode == .speed ? "Speed (m/s)" : "Distance (m)")
                        .chartXAxisLabel("Date")
                    }, getRecommendation: {
                        await viewModel.getAIEnhancedRecommendation().detailedAdvice
                    }
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            barChart
            pieChart
            InteractiveChartSection(
                title: "Run Distance vs. Pace Scatter Plot",
                subtitle: viewModel.getTimeRangeDescription(),
                onTap: {
                    viewModel.selectedChart = "Performance Change - Speed"
                    viewModel.showingDetail = true
                },
                content: {
                    Chart {
                        ForEach(viewModel.filteredSpeedData()) { data in
                            PointMark(
                                x: .value("Date", data.distance),
                                y: .value("Speed", data.value)
                            )
                            .foregroundStyle(Color.blue)
                            .symbolSize(100)
                        }
                        
                        if viewModel.filteredSpeedData().count > 1 {
                            let trendlineData = viewModel.filteredSpeedData()
                            LineMark(
                                x: .value("Date", trendlineData.first?.distance ?? 0),
                                y: .value("Speed", trendlineData.first?.value ?? 0)
                            )
                            LineMark(
                                x: .value("Date", trendlineData.last?.distance ?? 0),
                                y: .value("Speed", trendlineData.last?.value ?? 0)
                            )
                            .foregroundStyle(Color.red.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let distance = value.as(Double.self) {
                                    Text(String(format: "%.1f", distance))
                                } else if let distance = value.as(Int.self) {
                                    Text("\(distance)")
                                } else if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.day().month())
                                }
                            }
                        }
                    }
                    .chartYAxisLabel("Pace (m/s)")
                    .chartXAxisLabel("Distance (m)")
                }, getRecommendation: {
                    await viewModel.getSpeedRecommendation().detailedAdvice
                }
            )
            heatmapChart
        }
    }
    
    private func getTrendSubtitle() -> String {
        switch viewModel.trendDisplayMode {
        case .speed:    return "Speed Performance Trend"
        case .distance: return "Distance Performance Trend"
        }
    }
    
    var barChart: some View {
        InteractiveChartSection(
            title: "Performance Change (Speed)",
            subtitle: viewModel.getTimeRangeDescription(),
            onTap: {
                viewModel.selectedChart = "Performance Change - Speed"
                viewModel.showingDetail = true
            },
            content: {
                Chart {
                    ForEach(viewModel.filteredElevationData()) { data in
                        BarMark(
                            x: .value("Date", data.timestamp),
                            y: .value("Speed", data.value)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                    }
                    
                    let data = viewModel.filteredElevationData()
                    if !data.isEmpty {
                        let avgValue = data.map({ $0.value }).reduce(0, +) / Double(data.count)
                        RuleMark(
                            y: .value("Average", avgValue)
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .annotation(position: .trailing) {
                            Text("Avg")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: viewModel.getXAxisStride(), count: 4)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel { Text(date, format: viewModel.getDateFormat()) }
                        }
                    }
                }
                .chartYAxisLabel("Speed (m/s)")
                .chartXAxisLabel("Date")
                .frame(height: 200)
            }, getRecommendation: {
                await viewModel.getSpeedRecommendation().detailedAdvice
            }
        )
    }
    
    var pieChart: some View {
        let runData = viewModel.filteredRunData()
        let fastRuns = runData.filter { $0.value > 12.0 }.count
        let moderateRuns = runData.filter { $0.value >= 8.0 && $0.value <= 12.0 }.count
        let slowRuns = runData.filter { $0.value < 8.0 }.count
        let pieData = [
            (label: "Fast Pace", value: Double(fastRuns)),
            (label: "Moderate Pace", value: Double(moderateRuns)),
            (label: "Slow Pace", value: Double(slowRuns))
        ]
        let total = pieData.map { $0.value }.reduce(0, +)
        let percentageData = pieData.map { item -> (label: String, value: Double) in
            let percentage = total > 0 ? (item.value / total * 100.0) : 0
            return (label: item.label, value: percentage)
        }
        
        return InteractiveChartSection(
            title: "Run Pace Distribution",
            subtitle: viewModel.getTimeRangeDescription(),
            onTap: {
                viewModel.selectedChart = "Run Pace Distribution"
                viewModel.showingDetail = true
            },
            content: {
                Chart {
                    ForEach(percentageData, id: \.label) { item in
                        SectorMark(
                            angle: .value("Value", item.value),
                            innerRadius: .ratio(0.2),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Category", item.label))
                        .annotation(position: .overlay) {
                            if item.value >= 5 {
                                Text("\(Int(round(item.value)))%")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .center, spacing: 20)
                .frame(height: 200)
            }, getRecommendation: {
                await viewModel.getPaceDistributionRecommendation().detailedAdvice
            }
        )
    }
    
    var heatmapChart: some View {
        InteractiveChartSection(
            title: "Elevation Gain vs. Running Distance Heatmap",
            subtitle: viewModel.getTimeRangeDescription(),
            onTap: {
                viewModel.selectedChart = "Performance Change - Speed"
                viewModel.showingDetail = true
            },
            content: {
                Chart {
                    ForEach(viewModel.filteredElevationData()) { data in
                        RectangleMark(
                            x: .value("Distance", data.distance),
                            y: .value("Speed", data.value),
                            width: .fixed(25),
                            height: .fixed(25)
                        )
                        .foregroundStyle(viewModel.getHeatmapColor(for: data.value))
                    }
                    
                    let avgValue = viewModel.averageElevationValue()
                    RuleMark(y: .value("Average", avgValue))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let distance = value.as(Double.self) {
                                Text(String(format: "%.1f", distance))
                            } else if let distance = value.as(Int.self) {
                                Text("\(distance)")
                            } else if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.day().month())
                            }
                        }
                    }

                }
                .chartYAxisLabel("Elevation (m)")
                .chartXAxisLabel("Distance (m)")
                .chartLegend(position: .bottom)
            }, getRecommendation: {
                await viewModel.getElevationRecommendation().detailedAdvice
            }
        )
    }
}


struct AIEnhancedRecommendationCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var aiRecommendation: AIRecommendationEngine.Recommendation?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Getting AI recommendations...")
                    .padding()
            } else if let recommendation = aiRecommendation {
                RecommendationCard(recommendation: recommendation)
            } else {
                // Show standard recommendation until AI loads
                RecommendationCard(recommendation: viewModel.getPerformanceRecommendation())
                    .overlay(
                        Button(action: loadAIRecommendation) {
                            Label("Enhance with AI", systemImage: "sparkles")
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(),
                        alignment: .bottomTrailing
                    )
            }
        }
        .onAppear {
            // Optionally auto-load AI recommendation when view appears
            // loadAIRecommendation()
        }
        // Add this onChange modifier to detect time range changes
        .onChange(of: viewModel.selectedTimeRange) { newTimeRange in
            // If we already have an AI recommendation loaded, refresh it
            if aiRecommendation != nil {
                loadAIRecommendation()
            }
        }
        // Also update when trend display mode changes
        .onChange(of: viewModel.trendDisplayMode) { newMode in
            // If we already have an AI recommendation loaded, refresh it
            if aiRecommendation != nil {
                loadAIRecommendation()
            }
        }
    }
    
    private func loadAIRecommendation() {
        isLoading = true
        
        // Use Task to handle async operation
        Task {
            do {
                let recommendation = await viewModel.getAIEnhancedRecommendation()
                
                // Update UI on main thread
                await MainActor.run {
                    self.aiRecommendation = recommendation
                    self.isLoading = false
                }
            } catch {
                // Handle errors
                await MainActor.run {
                    // Fallback to regular recommendation if AI fails
                    self.aiRecommendation = viewModel.getPerformanceRecommendation()
                    self.isLoading = false
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: AIRecommendationEngine.Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForTrend(recommendation.trendType))
                    .font(.title2)
                    .foregroundColor(colorForTrend(recommendation.trendType))
                Text("Tips & Recommendation")
                    .font(.headline)
                Spacer()
            }
            
            
            Divider()
            
            Text(recommendation.detailedAdvice)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(colorForTrend(recommendation.trendType).opacity(0.3), lineWidth: 2)
        )
    }
    private func iconForTrend(_ trend: AIRecommendationEngine.TrendType) -> String {
        switch trend {
        case .improvement:
            return "arrow.up.right.circle.fill"
        case .decline:
            return "arrow.down.right.circle.fill"
        case .constant:
            return "equal.circle.fill"
        case .insufficient:
            return "questionmark.circle.fill"
        }
    }
    
    private func colorForTrend(_ trend: AIRecommendationEngine.TrendType) -> Color {
        switch trend {
        case .improvement:
            return .green
        case .decline:
            return .red
        case .constant:
            return .orange
        case .insufficient:
            return .gray
        }
    }
}
