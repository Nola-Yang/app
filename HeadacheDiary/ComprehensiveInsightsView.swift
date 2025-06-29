import SwiftUI

struct ComprehensiveInsightsView: View {
    @StateObject private var triggerEngine = ComprehensiveTriggerEngine.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var weatherService = WeatherService.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTab = 0
    @State private var showingDetailedAlert = false
    @State private var selectedAlert: PredictiveAlert?
    @State private var timeRange = TimeRange.month
    
    enum TimeRange: String, CaseIterable {
        case week = "week"
        case month = "month"
        case threeMonths = "3months"
        
        var displayName: String {
            switch self {
            case .week: return "1周"
            case .month: return "1个月"
            case .threeMonths: return "3个月"
            }
        }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部预警横幅
                if !triggerEngine.predictiveAlerts.isEmpty {
                    topAlertBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // 分段控制器
                Picker("洞察类型", selection: $selectedTab) {
                    Text("综合分析").tag(0)
                    Text("月经关联").tag(1)
                    Text("天气分析").tag(2)
                    Text("预测预警").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 时间范围选择器
                timeRangeSelector
                
                // 主要内容
                TabView(selection: $selectedTab) {
                    comprehensiveAnalysisTab
                        .tag(0)
                    
                    menstrualAnalysisTab
                        .tag(1)
                    
                    weatherHealthTab
                        .tag(2)
                    
                    predictiveAlertsTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .navigationTitle("综合分析")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            performAnalysis()
        }
        .onChange(of: timeRange) { _, _ in
            performAnalysis()
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
    }
    
    // MARK: - 子视图组件
    
    @ViewBuilder
    private var topAlertBanner: some View {
        if let highestAlert = triggerEngine.predictiveAlerts.first(where: { $0.riskLevel == .high || $0.riskLevel == .critical }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("头痛高风险预警")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(highestAlert.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("查看") {
                    selectedAlert = highestAlert
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分析时间范围")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Picker("时间范围", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var comprehensiveAnalysisTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let analysis = triggerEngine.comprehensiveAnalysis {
                    // 总体统计卡片
                    ComprehensiveOverallStatsCard(analysis: analysis)
                    
                    // 主要触发因素组合
                    TriggerCombinationsCard(combinations: analysis.primaryTriggerCombinations)
                    
                    // 个性化洞察
                    PersonalizedInsightsCard(insights: analysis.personalizedInsights)
                    
                } else if triggerEngine.isAnalyzing {
                    LoadingAnalysisView()
                } else {
                    EmptyAnalysisView()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var menstrualAnalysisTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let insights = triggerEngine.menstrualInsights {
                    // 月经周期相关性卡片
                    MenstrualCorrelationCard(insights: insights)
                    
                    // 周期阶段分析
                    MenstrualPhasesCard(insights: insights)
                    
                    // 预防建议
                    MenstrualPreventionCard(insights: insights)
                    
                } else if triggerEngine.isAnalyzing {
                    LoadingAnalysisView()
                } else {
                    EmptyAnalysisView()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var weatherHealthTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 权限状态检查卡片
                if !weatherService.isLocationAuthorized {
                    LocationPermissionCard()
                } else {
                    // 当前天气状况卡片
                    CurrentWeatherCard()
                    
                    // 头痛风险预警卡片
                    HeadacheRiskCard()
                }
                
                // 天气健康相关性分析
                if !triggerEngine.weatherHealthCorrelations.isEmpty {
                    WeatherHealthCorrelationsSection(correlations: triggerEngine.weatherHealthCorrelations)
                } else if triggerEngine.isAnalyzing {
                    LoadingAnalysisView()
                } else {
                    EmptyAnalysisView()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var predictiveAlertsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !triggerEngine.predictiveAlerts.isEmpty {
                    // 预测预警列表
                    ForEach(triggerEngine.predictiveAlerts, id: \.date) { alert in
                        PredictiveAlertCard(alert: alert) {
                            selectedAlert = alert
                        }
                    }
                } else if triggerEngine.isAnalyzing {
                    LoadingAnalysisView()
                } else {
                    Text("暂无预警信息")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 私有方法
    
    private func performAnalysis() {
        Task {
            await triggerEngine.performComprehensiveAnalysis()
        }
    }
}

// MARK: - 支持组件

struct ComprehensiveOverallStatsCard: View {
    let analysis: ComprehensiveHeadacheAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("综合分析概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(analysis.analysisDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ComprehensiveStatItem(
                    title: "分析记录数",
                    value: "\(analysis.totalRecords)条",
                    icon: "chart.bar.doc.horizontal",
                    color: .blue
                )
                
                ComprehensiveStatItem(
                    title: "月经相关性",
                    value: String(format: "%.2f", analysis.menstrualCorrelation),
                    icon: "calendar",
                    color: .purple
                )
                
                ComprehensiveStatItem(
                    title: "主要触发因素",
                    value: "\(analysis.primaryTriggerCombinations.count)个",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
                
                ComprehensiveStatItem(
                    title: "风险评分",
                    value: String(format: "%.2f", analysis.riskPrediction.riskForecast.first?.riskScore ?? 0),
                    icon: "gauge",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ComprehensiveStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TriggerCombinationsCard: View {
    let combinations: [TriggerCombination]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主要触发因素组合")
                .font(.headline)
                .fontWeight(.semibold)
            
            if combinations.isEmpty {
                Text("暂无明显的触发因素组合")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(combinations.prefix(3), id: \.combinationKey) { combination in
                    TriggerCombinationRow(combination: combination)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TriggerCombinationRow: View {
    let combination: TriggerCombination
    
    private var riskColor: Color {
        switch combination.riskScore {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(combination.combinationKey)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Circle()
                    .fill(riskColor)
                    .frame(width: 12, height: 12)
            }
            
            HStack {
                Text("频次: \(combination.frequency)次")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("平均强度: \(String(format: "%.1f", combination.averageIntensity))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct PersonalizedInsightsCard: View {
    let insights: [PersonalizedInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("个性化洞察")
                .font(.headline)
                .fontWeight(.semibold)
            
            if insights.isEmpty {
                Text("需要更多数据来生成个性化洞察")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(insights, id: \.title) { insight in
                    PersonalizedInsightRow(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PersonalizedInsightRow: View {
    let insight: PersonalizedInsight
    
    private var priorityColor: Color {
        switch insight.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(Array(insight.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        Text("• \(recommendation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct MenstrualCorrelationCard: View {
    let insights: MenstrualHeadacheInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月经周期关联性")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相关性系数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", insights.correlation))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(insights.correlation > 0.5 ? .red : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("可预测性")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", insights.cyclePredictability * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MenstrualPhasesCard: View {
    let insights: MenstrualHeadacheInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月经周期阶段分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            PhaseAnalysisRow(
                title: insights.preMenstrualPatterns.phaseName,
                intensity: insights.preMenstrualPatterns.averageIntensity,
                frequency: insights.preMenstrualPatterns.frequency,
                triggers: insights.preMenstrualPatterns.commonTriggers
            )
            
            PhaseAnalysisRow(
                title: insights.menstrualPatterns.phaseName,
                intensity: insights.menstrualPatterns.averageIntensity,
                frequency: insights.menstrualPatterns.frequency,
                triggers: insights.menstrualPatterns.commonTriggers
            )
            
            PhaseAnalysisRow(
                title: insights.ovulationPatterns.phaseName,
                intensity: insights.ovulationPatterns.averageIntensity,
                frequency: insights.ovulationPatterns.frequency,
                triggers: insights.ovulationPatterns.commonTriggers
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PhaseAnalysisRow: View {
    let title: String
    let intensity: Double
    let frequency: Int
    let triggers: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("强度: \(String(format: "%.1f", intensity))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("频次: \(frequency)次")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !triggers.isEmpty {
                    Text("常见触发: \(triggers.prefix(2).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct MenstrualPreventionCard: View {
    let insights: MenstrualHeadacheInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预防建议")
                .font(.headline)
                .fontWeight(.semibold)
            
            if insights.recommendedPreventions.isEmpty {
                Text("暂无特殊预防建议")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(Array(insights.recommendedPreventions.enumerated()), id: \.offset) { index, prevention in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(prevention)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeatherHealthCorrelationCard: View {
    let correlation: WeatherHealthCorrelation
    
    private var correlationColor: Color {
        let absCorr = abs(correlation.combinedCorrelation)
        switch absCorr {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(correlation.weatherFactor) × \(correlation.healthMetric)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Circle()
                    .fill(correlationColor)
                    .frame(width: 12, height: 12)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("天气相关性:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.3f", correlation.weatherCorrelation))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("健康相关性:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.3f", correlation.healthCorrelation))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("综合相关性:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.3f", correlation.combinedCorrelation))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(correlationColor)
                }
            }
            
            Text(correlation.insights)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PredictiveAlertCard: View {
    let alert: PredictiveAlert
    let onTap: () -> Void
    
    private var alertColor: Color {
        switch alert.riskLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(alert.date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(alert.riskLevel.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(alertColor.opacity(0.2))
                        .foregroundColor(alertColor)
                        .cornerRadius(4)
                }
                
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("风险评分: \(String(format: "%.2f", alert.riskScore))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoadingAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在进行综合分析...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

struct EmptyAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无分析数据")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("需要更多头痛记录和健康数据进行分析")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - 预警详情视图

struct AlertDetailView: View {
    let alert: PredictiveAlert
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 预警头部信息
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(alert.date, style: .date)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(alert.riskScore * 100))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(alertColor)
                        }
                        
                        Text(alert.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 主要触发因素
                    if !alert.primaryTriggers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("主要触发因素")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(alert.primaryTriggers, id: \.self) { trigger in
                                Label(trigger, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // 预防建议
                    if !alert.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("预防建议")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(alert.recommendations.enumerated()), id: \.offset) { index, recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(recommendation)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("预警详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var alertColor: Color {
        switch alert.riskLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}



struct WeatherHealthCorrelationsSection: View {
    let correlations: [WeatherHealthCorrelation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("天气健康关联分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(correlations.prefix(5), id: \.weatherFactor) { correlation in
                WeatherHealthCorrelationCard(correlation: correlation)
            }
        }
    }
}

#Preview {
    ComprehensiveInsightsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}