import SwiftUI
import CoreData

struct ComprehensiveInsightsView: View {
    @StateObject private var triggerEngine = ComprehensiveTriggerEngine.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var healthAnalysisEngine = HealthAnalysisEngine.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTab = 0
    @State private var showingDetailedAlert = false
    @State private var selectedAlert: PredictiveAlert?
    
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
                    Text("健康关联").tag(1)
                    Text("天气分析").tag(2)
                    Text("预测预警").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                
                // 主要内容
                TabView(selection: $selectedTab) {
                    comprehensiveAnalysisTab
                        .tag(0)
                    
                    healthAnalysisTab
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
    private var comprehensiveAnalysisTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let analysis = triggerEngine.comprehensiveAnalysis {
                    // 综合统计概览卡片
                    EnhancedComprehensiveStatsCard(analysis: analysis, context: viewContext)
                    
                    // 头痛模式分析卡片
                    HeadachePatternAnalysisCard(analysis: analysis, context: viewContext)
                    
                    // 跨因素关联分析
                    CrossFactorCorrelationCard(analysis: analysis)
                    
                    // 主要触发因素组合（保留但简化）
                    if !analysis.primaryTriggerCombinations.isEmpty {
                        TriggerCombinationsCard(combinations: analysis.primaryTriggerCombinations)
                    }
                    
                    // 个性化洞察（保留）
                    if !analysis.personalizedInsights.isEmpty {
                        PersonalizedInsightsCard(insights: analysis.personalizedInsights)
                    }
                    
                    // 预测和建议综合卡片
                    PredictiveInsightsCard(analysis: analysis)
                    
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
    private var healthAnalysisTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // HealthKit权限状态检查
                if !healthKitManager.isAuthorized {
                    HealthKitPermissionCard()
                } else {
                    // 健康数据概览卡片
                    if let snapshot = healthKitManager.healthDataSnapshot {
                        HealthDataOverviewCard(snapshot: snapshot)
                    }
                }
                
                // 健康相关性分析结果
                if !healthAnalysisEngine.correlationResults.isEmpty {
                    HealthCorrelationsSection(correlations: healthAnalysisEngine.correlationResults)
                } else if healthAnalysisEngine.isAnalyzing || triggerEngine.isAnalyzing {
                    LoadingAnalysisView()
                } else {
                    EmptyHealthAnalysisView()
                }
                
                // 健康风险预测
                if let prediction = healthAnalysisEngine.riskPrediction {
                    HealthRiskPredictionCard(prediction: prediction)
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
            await healthAnalysisEngine.performCorrelationAnalysis()
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
            Text("基于现有数据进行初步分析，随着数据积累将提供更准确的洞察")
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

// MARK: - 健康分析相关组件

struct HealthKitPermissionCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("需要HealthKit权限")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("授权访问健康数据以分析与头痛的关联")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("授权HealthKit") {
                Task {
                    let _ = await HealthKitManager.shared.requestHealthKitPermissions()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HealthDataOverviewCard: View {
    let snapshot: HealthDataSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("健康数据概览")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let hrv = snapshot.heartRateVariability {
                    HealthMetricItem(
                        title: "心率变异性",
                        value: String(format: "%.1f ms", hrv.value),
                        icon: "heart.circle",
                        color: .red,
                        trend: hrv.trend
                    )
                }
                
                if let sleep = snapshot.sleepDuration {
                    HealthMetricItem(
                        title: "睡眠时长",
                        value: String(format: "%.1f h", sleep.value / 3600),
                        icon: "bed.double.circle",
                        color: .purple,
                        trend: sleep.trend
                    )
                }
                
                if let heartRate = snapshot.restingHeartRate {
                    HealthMetricItem(
                        title: "静息心率",
                        value: String(format: "%.0f bpm", heartRate.value),
                        icon: "heart.circle",
                        color: .pink,
                        trend: heartRate.trend
                    )
                }
                
                if let steps = snapshot.stepCount {
                    HealthMetricItem(
                        title: "步数",
                        value: String(format: "%.0f", steps.value),
                        icon: "figure.walk.circle",
                        color: .green,
                        trend: steps.trend
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HealthMetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                if let trend = trend {
                    Image(systemName: trend > 0 ? "arrow.up" : trend < 0 ? "arrow.down" : "minus")
                        .foregroundColor(trend > 0 ? .green : trend < 0 ? .red : .gray)
                        .font(.caption)
                }
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

struct HealthCorrelationsSection: View {
    let correlations: [HealthCorrelationResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("健康数据关联分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(correlations.prefix(8), id: \.healthMetric) { correlation in
                HealthCorrelationCard(correlation: correlation)
            }
        }
    }
}

struct HealthCorrelationCard: View {
    let correlation: HealthCorrelationResult
    
    private var correlationColor: Color {
        let absCorr = abs(correlation.correlation)
        switch absCorr {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .orange
        default: return .red
        }
    }
    
    private var riskColor: Color {
        switch correlation.riskFactor {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(correlation.healthMetric)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(correlationColor)
                        .frame(width: 8, height: 8)
                    if correlation.isSignificant {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相关性")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", correlation.correlation))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(correlationColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("显著性")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", correlation.pValue))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(correlation.isSignificant ? .green : .gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("风险级别")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(correlation.riskFactor.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(riskColor.opacity(0.2))
                        .foregroundColor(riskColor)
                        .cornerRadius(4)
                }
            }
            
            if !correlation.description.isEmpty {
                Text(correlation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HealthRiskPredictionCard: View {
    let prediction: HeadacheRiskPrediction
    
    private var riskColor: Color {
        switch prediction.riskLevel {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("健康风险预测")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 风险评分显示
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("风险评分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", prediction.riskLevel * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("可信度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", prediction.confidenceLevel * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            
            // 主要风险因素
            if !prediction.primaryFactors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("主要风险因素")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(prediction.primaryFactors, id: \.self) { factor in
                        HStack {
                            Circle()
                                .fill(riskColor)
                                .frame(width: 6, height: 6)
                            Text(factor)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            
            // 预防建议
            if !prediction.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("健康建议")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(prediction.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyHealthAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无健康关联分析")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("基于现有健康数据进行分析，持续记录将提供更精确的健康关联洞察")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}


// MARK: - 扩展HealthCorrelationResult.RiskLevel
extension HealthCorrelationResult.RiskLevel {
    var description: String {
        switch self {
        case .low: return "低"
        case .moderate: return "中"
        case .high: return "高"
        case .veryHigh: return "极高"
        }
    }
}

// MARK: - 新增综合分析组件

struct EnhancedComprehensiveStatsCard: View {
    let analysis: ComprehensiveHeadacheAnalysis
    let context: NSManagedObjectContext
    
    @State private var headacheStats: HeadacheStatistics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("头痛数据概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(analysis.analysisDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let stats = headacheStats {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ComprehensiveStatItem(
                        title: "记录总数",
                        value: "\(analysis.totalRecords)条",
                        icon: "chart.bar.doc.horizontal",
                        color: .blue
                    )
                    
                    ComprehensiveStatItem(
                        title: "平均强度",
                        value: String(format: "%.1f", stats.averageIntensity),
                        icon: "gauge.medium",
                        color: .orange
                    )
                    
                    ComprehensiveStatItem(
                        title: "头痛频率",
                        value: String(format: "%.1f天/次", stats.daysBetweenHeadaches),
                        icon: "clock",
                        color: .purple
                    )
                    
                    ComprehensiveStatItem(
                        title: "数据质量",
                        value: stats.dataQualityDescription,
                        icon: "checkmark.seal",
                        color: stats.dataQualityColor
                    )
                }
            } else {
                ProgressView("计算统计数据...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            calculateHeadacheStats()
        }
    }
    
    private func calculateHeadacheStats() {
        Task {
            let stats = await computeHeadacheStatistics()
            await MainActor.run {
                self.headacheStats = stats
            }
        }
    }
    
    private func computeHeadacheStatistics() async -> HeadacheStatistics {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: true)]
                
                do {
                    let records = try context.fetch(request)
                    
                    let intensities = records.map { Double($0.intensity) }
                    let averageIntensity = intensities.isEmpty ? 0 : intensities.reduce(0, +) / Double(intensities.count)
                    
                    let daysBetween: Double
                    if records.count > 1, let firstDate = records.first?.timestamp, let lastDate = records.last?.timestamp {
                        let totalDays = lastDate.timeIntervalSince(firstDate) / (24 * 3600)
                        daysBetween = totalDays / Double(records.count - 1)
                    } else {
                        daysBetween = 0
                    }
                    
                    let dataQuality: (String, Color)
                    switch records.count {
                    case 0..<5: dataQuality = ("初期", .gray)
                    case 5..<15: dataQuality = ("基础", .yellow)
                    case 15..<30: dataQuality = ("良好", .green)
                    default: dataQuality = ("优秀", .blue)
                    }
                    
                    let stats = HeadacheStatistics(
                        totalRecords: records.count,
                        averageIntensity: averageIntensity,
                        daysBetweenHeadaches: daysBetween,
                        dataQualityDescription: dataQuality.0,
                        dataQualityColor: dataQuality.1
                    )
                    
                    continuation.resume(returning: stats)
                } catch {
                    let stats = HeadacheStatistics(
                        totalRecords: 0,
                        averageIntensity: 0,
                        daysBetweenHeadaches: 0,
                        dataQualityDescription: "无数据",
                        dataQualityColor: .gray
                    )
                    continuation.resume(returning: stats)
                }
            }
        }
    }
}

struct HeadachePatternAnalysisCard: View {
    let analysis: ComprehensiveHeadacheAnalysis
    let context: NSManagedObjectContext
    
    @State private var patternData: HeadachePatternData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("头痛模式分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let pattern = patternData {
                VStack(spacing: 12) {
                    // 时间模式
                    PatternRow(
                        title: "高发时段",
                        value: pattern.peakTimeDescription,
                        icon: "clock.fill",
                        color: .blue
                    )
                    
                    // 持续时间模式
                    PatternRow(
                        title: "平均持续",
                        value: pattern.averageDurationDescription,
                        icon: "timer",
                        color: .green
                    )
                    
                    // 强度趋势
                    PatternRow(
                        title: "强度趋势",
                        value: pattern.intensityTrendDescription,
                        icon: "chart.line.uptrend.xyaxis",
                        color: pattern.intensityTrendColor
                    )
                    
                    // 频率趋势
                    PatternRow(
                        title: "频率变化",
                        value: pattern.frequencyTrendDescription,
                        icon: "waveform.path.ecg",
                        color: pattern.frequencyTrendColor
                    )
                }
            } else {
                ProgressView("分析头痛模式...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            analyzeHeadachePatterns()
        }
    }
    
    private func analyzeHeadachePatterns() {
        Task {
            let pattern = await computeHeadachePatterns()
            await MainActor.run {
                self.patternData = pattern
            }
        }
    }
    
    private func computeHeadachePatterns() async -> HeadachePatternData {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: true)]
                
                do {
                    let records = try context.fetch(request)
                    
                    // 分析高发时段
                    let hourCounts = records.reduce(into: [Int: Int]()) { counts, record in
                        if let timestamp = record.timestamp {
                            let hour = Calendar.current.component(.hour, from: timestamp)
                            counts[hour, default: 0] += 1
                        }
                    }
                    let peakHour = hourCounts.max(by: { $0.value < $1.value })?.key ?? 12
                    let peakTimeDesc = "\(peakHour):00-\(peakHour+1):00"
                    
                    // 分析平均持续时间
                    let durations = records.compactMap { record -> Double? in
                        guard let start = record.startTime, let end = record.endTime else { return nil }
                        return end.timeIntervalSince(start) / 3600 // 转换为小时
                    }
                    let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
                    let durationDesc = avgDuration > 0 ? String(format: "%.1f小时", avgDuration) : "未记录"
                    
                    // 分析强度趋势（最近vs早期）
                    let recentRecords = records.suffix(max(records.count / 3, 5))
                    let earlyRecords = records.prefix(max(records.count / 3, 5))
                    let recentAvgIntensity = recentRecords.isEmpty ? 0 : Double(recentRecords.map { $0.intensity }.reduce(0, +)) / Double(recentRecords.count)
                    let earlyAvgIntensity = earlyRecords.isEmpty ? 0 : Double(earlyRecords.map { $0.intensity }.reduce(0, +)) / Double(earlyRecords.count)
                    
                    let intensityChange = recentAvgIntensity - earlyAvgIntensity
                    let intensityTrend: (String, Color)
                    if abs(intensityChange) < 0.5 {
                        intensityTrend = ("保持稳定", .blue)
                    } else if intensityChange > 0 {
                        intensityTrend = ("逐渐加重", .red)
                    } else {
                        intensityTrend = ("有所改善", .green)
                    }
                    
                    // 分析频率趋势
                    let now = Date()
                    let recent30Days = records.filter { record in
                        guard let timestamp = record.timestamp else { return false }
                        return now.timeIntervalSince(timestamp) < 30 * 24 * 3600
                    }
                    let previous30Days = records.filter { record in
                        guard let timestamp = record.timestamp else { return false }
                        let daysSince = now.timeIntervalSince(timestamp) / (24 * 3600)
                        return daysSince >= 30 && daysSince < 60
                    }
                    
                    let recentFreq = recent30Days.count
                    let prevFreq = previous30Days.count
                    let freqTrend: (String, Color)
                    if recentFreq == prevFreq {
                        freqTrend = ("无明显变化", .blue)
                    } else if recentFreq > prevFreq {
                        freqTrend = ("频率增加", .red)
                    } else {
                        freqTrend = ("频率减少", .green)
                    }
                    
                    let pattern = HeadachePatternData(
                        peakTimeDescription: peakTimeDesc,
                        averageDurationDescription: durationDesc,
                        intensityTrendDescription: intensityTrend.0,
                        intensityTrendColor: intensityTrend.1,
                        frequencyTrendDescription: freqTrend.0,
                        frequencyTrendColor: freqTrend.1
                    )
                    
                    continuation.resume(returning: pattern)
                } catch {
                    let pattern = HeadachePatternData(
                        peakTimeDescription: "无数据",
                        averageDurationDescription: "无数据",
                        intensityTrendDescription: "无数据",
                        intensityTrendColor: .gray,
                        frequencyTrendDescription: "无数据",
                        frequencyTrendColor: .gray
                    )
                    continuation.resume(returning: pattern)
                }
            }
        }
    }
}

struct CrossFactorCorrelationCard: View {
    let analysis: ComprehensiveHeadacheAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("跨因素关联强度")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                // 综合关联评分
                HStack {
                    Text("综合关联评分")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.0f%%", overallCorrelationScore * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(correlationScoreColor)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                
                // 主要关联因素
                if !topCorrelationFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主要关联因素")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(topCorrelationFactors, id: \.factor) { item in
                            HStack {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                Text(item.factor)
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1f%%", item.strength * 100))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(item.color)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                
                // 关联分析洞察
                Text(correlationInsight)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var overallCorrelationScore: Double {
        // Assuming menstrualCorrelation, combinedCorrelation, and riskScore are already percentages (0-100)
        // We need to convert them to a 0-1 scale before applying weights.
        let menstrualWeight = (abs(analysis.menstrualCorrelation) / 100.0) * 0.4
        
        // Break down weather health weight calculation
        let weatherCorrelations = analysis.weatherHealthCorrelations.prefix(3)
        let weatherAbsValues = weatherCorrelations.map { abs($0.combinedCorrelation) / 100.0 }
        let weatherSum = weatherAbsValues.reduce(0, +)
        let weatherCount = max(1, weatherAbsValues.count)
        let weatherHealthWeight = (weatherSum / Double(weatherCount)) * 0.3
        
        // Break down trigger weight calculation
        let triggerCombinations = analysis.primaryTriggerCombinations.prefix(3)
        let triggerScores = triggerCombinations.map { $0.riskScore }
        let triggerSum = triggerScores.reduce(0, +)
        let triggerCount = max(1, triggerScores.count)
        let triggerWeight = (triggerSum / Double(triggerCount)) * 0.3
        
        let totalWeight = menstrualWeight + weatherHealthWeight + triggerWeight
        return min(totalWeight, 1.0)
    }
    
    private var correlationScoreColor: Color {
        switch overallCorrelationScore {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .orange
        default: return .red
        }
    }
    
    private var topCorrelationFactors: [(factor: String, strength: Double, color: Color)] {
        var factors: [(String, Double, Color)] = []
        
        if abs(analysis.menstrualCorrelation) > 0.3 {
            factors.append(("月经周期", abs(analysis.menstrualCorrelation), .purple))
        }
        
        for correlation in analysis.weatherHealthCorrelations.prefix(2) {
            if abs(correlation.combinedCorrelation) > 0.3 {
                factors.append(("\(correlation.weatherFactor)×\(correlation.healthMetric)", abs(correlation.combinedCorrelation), .blue))
            }
        }
        
        for combo in analysis.primaryTriggerCombinations.prefix(2) {
            if combo.riskScore > 0.5 {
                factors.append((combo.combinationKey, combo.riskScore, .orange))
            }
        }
        
        return Array(factors.sorted { $0.1 > $1.1 }.prefix(4))
    }
    
    private var correlationInsight: String {
        let score = overallCorrelationScore
        
        if score > 0.7 {
            return "您的头痛与多个因素存在强烈关联，预测准确性较高。建议重点关注主要关联因素的管理。"
        } else if score > 0.4 {
            return "发现了一些重要的关联模式，继续记录数据将提高分析准确性。"
        } else if score > 0.2 {
            return "找到了一些潜在的关联因素，需要更多数据来确认这些模式。"
        } else {
            return "目前关联模式不够明显，可能需要更长时间的数据积累，或头痛原因较为复杂多样。"
        }
    }
}

struct PredictiveInsightsCard: View {
    let analysis: ComprehensiveHeadacheAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预测洞察与建议")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 预测可信度
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("预测可信度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", predictiveConfidence * 100))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(confidenceColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("风险评级")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentRiskLevel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(riskLevelColor)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                
                // 关键建议
                if !keyRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关键建议")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(keyRecommendations.enumerated()), id: \.offset) { index, recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: recommendation.icon)
                                    .foregroundColor(recommendation.color)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recommendation.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(recommendation.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var predictiveConfidence: Double {
        let recordCount = analysis.totalRecords
        let combinationCount = analysis.primaryTriggerCombinations.count
        let correlationStrength = abs(analysis.menstrualCorrelation)
        
        var confidence = 0.0
        
        // 基于记录数量
        confidence += min(Double(recordCount) / 50.0, 1.0) * 0.4
        
        // 基于找到的模式数量
        confidence += min(Double(combinationCount) / 5.0, 1.0) * 0.3
        
        // 基于关联强度
        confidence += correlationStrength * 0.3
        
        return min(confidence, 1.0)
    }
    
    private var confidenceColor: Color {
        switch predictiveConfidence {
        case 0..<0.4: return .red
        case 0.4..<0.7: return .orange
        default: return .green
        }
    }
    
    private var currentRiskLevel: String {
        let currentRisk = analysis.riskPrediction.riskForecast.first?.riskScore ?? 0
        switch currentRisk {
        case 0..<0.3: return "低风险"
        case 0.3..<0.6: return "中等风险"
        case 0.6..<0.8: return "高风险"
        default: return "极高风险"
        }
    }
    
    private var riskLevelColor: Color {
        let currentRisk = analysis.riskPrediction.riskForecast.first?.riskScore ?? 0
        switch currentRisk {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .orange
        case 0.6..<0.8: return .red
        default: return .purple
        }
    }
    
    private var keyRecommendations: [KeyRecommendation] {
        var recommendations: [KeyRecommendation] = []
        
        // 基于月经相关性的建议
        if abs(analysis.menstrualCorrelation) > 0.5 {
            recommendations.append(KeyRecommendation(
                icon: "calendar",
                title: "月经周期管理",
                description: "重点关注月经前2-3天的预防措施",
                color: .purple
            ))
        }
        
        // 基于触发因素组合的建议
        if let topCombination = analysis.primaryTriggerCombinations.first, topCombination.riskScore > 0.6 {
            recommendations.append(KeyRecommendation(
                icon: "exclamationmark.triangle",
                title: "避免高危组合",
                description: "当\(topCombination.combinationKey)同时出现时特别注意",
                color: .orange
            ))
        }
        
        // 基于数据质量的建议
        if analysis.totalRecords < 15 {
            recommendations.append(KeyRecommendation(
                icon: "chart.bar.doc.horizontal",
                title: "继续记录数据",
                description: "更多数据将显著提高预测准确性",
                color: .blue
            ))
        }
        
        // 基于预测可信度的建议
        if predictiveConfidence < 0.5 {
            recommendations.append(KeyRecommendation(
                icon: "info.circle",
                title: "模式识别中",
                description: "需要更多时间来识别个人化的头痛模式",
                color: .gray
            ))
        }
        
        return Array(recommendations.prefix(3))
    }
}

struct PatternRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 数据结构

struct HeadacheStatistics {
    let totalRecords: Int
    let averageIntensity: Double
    let daysBetweenHeadaches: Double
    let dataQualityDescription: String
    let dataQualityColor: Color
}

struct HeadachePatternData {
    let peakTimeDescription: String
    let averageDurationDescription: String
    let intensityTrendDescription: String
    let intensityTrendColor: Color
    let frequencyTrendDescription: String
    let frequencyTrendColor: Color
}

struct KeyRecommendation {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    ComprehensiveInsightsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}