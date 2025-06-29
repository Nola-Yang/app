import SwiftUI

struct HealthInsightsView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var analysisEngine = HealthAnalysisEngine.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingPermissionAlert = false
    @State private var selectedTimeRange = TimeRange.month
    @State private var showingDetailedAnalysis = false
    
    enum TimeRange: String, CaseIterable {
        case week = "week"
        case month = "month"
        case threeMonths = "3months"
        case sixMonths = "6months"
        
        var displayName: String {
            switch self {
            case .week: return "1周"
            case .month: return "1个月"
            case .threeMonths: return "3个月"
            case .sixMonths: return "6个月"
            }
        }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部状态卡片
                healthStatusCard
                
                // 时间范围选择器
                timeRangeSelector
                
                // HealthKit授权状态
                if !healthKitManager.isAuthorized {
                    healthKitAuthorizationCard
                } else {
                    // 健康数据快照
                    if healthKitManager.isAnalyzing {
                        loadingView
                    } else {
                        healthDataSnapshot
                    }
                    
                    // 相关性分析结果
                    correlationAnalysisSection
                    
                    // 风险预测
                    riskPredictionSection
                    
                    // 详细分析按钮
                    detailedAnalysisButton
                }
            }
            .padding()
        }
        .navigationTitle("健康洞察")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if healthKitManager.isAuthorized {
                Task {
                    await healthKitManager.fetchRecentHealthData(days: selectedTimeRange.days)
                    await analysisEngine.performCorrelationAnalysis()
                }
            }
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            if healthKitManager.isAuthorized {
                Task {
                    await healthKitManager.fetchRecentHealthData(days: newRange.days)
                    await analysisEngine.performCorrelationAnalysis()
                }
            }
        }
        .alert("HealthKit权限", isPresented: $showingPermissionAlert) {
            Button("去设置") {
                Task {
                    let success = await healthKitManager.requestHealthKitPermissions()
                    if success {
                        await healthKitManager.fetchRecentHealthData(days: selectedTimeRange.days)
                    }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("需要访问健康数据才能进行分析")
        }
        .sheet(isPresented: $showingDetailedAnalysis) {
            DetailedHealthAnalysisView()
        }
    }
    
    // MARK: - 子视图组件
    
    @ViewBuilder
    private var healthStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("健康状态概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let snapshot = healthKitManager.healthDataSnapshot {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    HealthMetricCardSimple(
                        title: "HRV",
                        value: snapshot.heartRateVariability.map { "\(Int($0.value))ms" } ?? "未知",
                        icon: "waveform.path.ecg",
                        color: .green
                    )
                    
                    HealthMetricCardSimple(
                        title: "睡眠",
                        value: snapshot.sleepDuration.map { "\(Int($0.value / 3600))h" } ?? "未知",
                        icon: "bed.double",
                        color: .blue
                    )
                    
                    HealthMetricCardSimple(
                        title: "心率",
                        value: snapshot.restingHeartRate.map { "\(Int($0.value))bpm" } ?? "未知",
                        icon: "heart",
                        color: .red
                    )
                    
                    HealthMetricCardSimple(
                        title: "周期",
                        value: snapshot.cycleDay.map { "第\($0)天" } ?? "未知",
                        icon: "calendar",
                        color: .purple
                    )
                }
            } else {
                Text("暂无健康数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分析时间范围")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    @ViewBuilder
    private var healthKitAuthorizationCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundColor(.pink)
            
            Text("连接健康应用")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("授权访问健康数据后，我们可以分析HRV、睡眠、月经周期等数据与头痛的关联性，为您提供个性化的健康洞察。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("连接健康应用") {
                showingPermissionAlert = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在分析健康数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
    
    @ViewBuilder
    private var healthDataSnapshot: some View {
        if let snapshot = healthKitManager.healthDataSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                Text("健康指标详情")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    HealthDetailRow(
                        title: "心率变异性",
                        value: snapshot.heartRateVariability.map { String(format: "%.1f ms", $0.value) } ?? "无数据",
                        description: "反映自主神经系统功能"
                    )
                    
                    HealthDetailRow(
                        title: "睡眠时长",
                        value: snapshot.sleepDuration.map { formatDuration($0.value) } ?? "无数据",
                        description: "深睡眠比例: \(snapshot.deepSleepPercentage.map { String(format: "%.0f%%", $0.value) } ?? "无数据")"
                    )
                    
                    if let cycleDay = snapshot.cycleDay {
                        HealthDetailRow(
                            title: "月经周期",
                            value: "第\(cycleDay)天",
                            description: "月经流量: \(menstrualFlowDescription(snapshot.menstrualFlowLevel?.value))"
                        )
                    }
                    
                    HealthDetailRow(
                        title: "运动数据",
                        value: snapshot.stepCount.map { "\(Int($0.value)) 步" } ?? "无数据",
                        description: "活跃卡路里: \(snapshot.activeEnergyBurned.map { "\(Int($0.value)) 卡" } ?? "无数据")"
                    )
                    
                    if let mindfulMinutes = snapshot.mindfulMinutes {
                        HealthDetailRow(
                            title: "正念练习",
                            value: "\(Int(mindfulMinutes.value)) 分钟",
                            description: "过去7天平均时长"
                        )
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var correlationAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("相关性分析")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if analysisEngine.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if analysisEngine.correlationResults.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "暂无分析结果",
                    description: "需要更多头痛记录和健康数据进行分析"
                )
            } else {
                ForEach(analysisEngine.correlationResults.prefix(5), id: \.healthMetric) { result in
                    CorrelationResultCard(result: result)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var riskPredictionSection: some View {
        if let prediction = analysisEngine.riskPrediction {
            VStack(alignment: .leading, spacing: 16) {
                Text("头痛风险预测")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // 风险评分
                RiskScoreView(riskLevel: prediction.riskLevel, confidence: prediction.confidenceLevel)
                
                // 主要风险因素
                if !prediction.primaryFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主要风险因素")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(prediction.primaryFactors, id: \.self) { factor in
                            Label(factor, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 建议
                if !prediction.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预防建议")
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
    
    @ViewBuilder
    private var detailedAnalysisButton: some View {
        Button("查看详细分析") {
            showingDetailedAnalysis = true
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)小时\(minutes)分钟"
    }
    
    private func menstrualFlowDescription(_ level: Int?) -> String {
        guard let level = level else { return "无数据" }
        switch level {
        case 1: return "轻度"
        case 2: return "中度"
        case 3: return "重度"
        case 4: return "极重"
        default: return "无"
        }
    }
}

// MARK: - 支持组件

struct HealthMetricCard: View {
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

struct HealthMetricCardSimple: View {
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

struct HealthDetailRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CorrelationResultCard: View {
    let result: HealthCorrelationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.healthMetric)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                
                Circle()
                    .fill(Color(result.riskFactor.color))
                    .frame(width: 12, height: 12)
            }
            
            HStack {
                Text("相关性: \(result.correlation, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if result.isSignificant {
                    Text("显著")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            
            Text(result.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct RiskScoreView: View {
    let riskLevel: Double
    let confidence: Double
    
    private var riskColor: Color {
        switch riskLevel {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var riskDescription: String {
        switch riskLevel {
        case 0..<0.3: return "低风险"
        case 0.3..<0.6: return "中等风险"
        case 0.6..<0.8: return "高风险"
        default: return "极高风险"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("风险评分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(riskDescription)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("可信度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(confidence * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            
            // 风险评分进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(riskColor)
                        .frame(width: geometry.size.width * riskLevel, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - 详细分析视图

struct DetailedHealthAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analysisEngine = HealthAnalysisEngine.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(analysisEngine.correlationResults, id: \.healthMetric) { result in
                        DetailedCorrelationCard(result: result)
                    }
                }
                .padding()
            }
            .navigationTitle("详细分析")
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
}

struct DetailedCorrelationCard: View {
    let result: HealthCorrelationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.healthMetric)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(Color(result.riskFactor.color))
                    .frame(width: 16, height: 16)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("相关系数:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(result.correlation, specifier: "%.3f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("统计显著性:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("p = \(result.pValue, specifier: "%.3f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("风险等级:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.riskFactor.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(result.riskFactor.color))
                }
            }
            
            Divider()
            
            Text(result.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

extension HealthCorrelationResult.RiskLevel {
    var localizedDescription: String {
        switch self {
        case .low: return "低"
        case .moderate: return "中等"
        case .high: return "高"
        case .veryHigh: return "极高"
        }
    }
    
    var colorName: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
}

#Preview {
    NavigationView {
        HealthInsightsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}