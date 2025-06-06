//
//  WeatherAnalysisView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//

import SwiftUI
import CoreData

struct WeatherAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var headacheRecords: FetchedResults<HeadacheRecord>
    
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var warningManager = WeatherWarningManager.shared
    
    @State private var correlationResult: WeatherCorrelationResult?
    @State private var isAnalyzing = false
    @State private var showSettings = false
    @State private var selectedTimeRange: TimeRange = .last30Days
    @State private var hasInitialized = false  // 新增：防止重复初始化
    
    enum TimeRange: String, CaseIterable {
        case last7Days = "最近7天"
        case last30Days = "最近30天"
        case last90Days = "最近3个月"
        
        var days: Int {
            switch self {
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            }
        }
    }
    
    var body: some View {
        NavigationView {
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
                        
                        // 天气与头痛关联分析
                        WeatherCorrelationCard(
                            correlationResult: correlationResult,
                            isAnalyzing: isAnalyzing,
                            timeRange: selectedTimeRange,
                            onAnalyze: performCorrelationAnalysis,
                            onTimeRangeChanged: { range in
                                selectedTimeRange = range
                                performCorrelationAnalysis()
                            }
                        )
                        
                        // 最近预警历史
                        RecentWarningsCard()
                        
                        // 天气趋势图表
                        WeatherTrendCard()
                        
                        // 个性化建议
                        PersonalizedAdviceCard(correlationResult: correlationResult)
                    }
                }
                .padding()
            }
            .navigationTitle("天气分析")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("天气设置") {
                            showSettings = true
                        }
                        Button("刷新天气") {
                            Task {
                                await refreshWeatherData()
                            }
                        }
                        Button("重新分析") {
                            performCorrelationAnalysis()
                        }
                        Button("检查权限") {
                            weatherService.recheckLocationPermission()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                WeatherSettingsView()
            }
            .onAppear {
                initializeWeatherAnalysis()
            }
            .refreshable {
                await refreshWeatherData()
                performCorrelationAnalysis()
            }
        }
    }
    
    // 新增：初始化天气分析
    private func initializeWeatherAnalysis() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🔄 初始化天气分析页面...")
        
        // 检查位置权限
        weatherService.recheckLocationPermission()
        
        // 如果有权限，获取天气数据
        if weatherService.isLocationAuthorized {
            weatherService.requestCurrentLocationWeather()
        }
        
        // 延迟执行关联分析，确保数据已加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if correlationResult == nil {
                performCorrelationAnalysis()
            }
        }
    }
    
    // 新增：刷新天气数据
    private func refreshWeatherData() async {
        print("🔄 刷新天气数据...")
        
        // 重新检查权限
        weatherService.recheckLocationPermission()
        
        // 如果有权限，获取最新天气
        if weatherService.isLocationAuthorized {
            weatherService.requestCurrentLocationWeather()
            
            // 等待一段时间让数据更新
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        }
    }
    
    private func performCorrelationAnalysis() {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        print("🔄 开始天气关联分析...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let cutoff = Calendar.current.date(byAdding: .day,
                                               value: -selectedTimeRange.days,
                                               to: Date()) ?? Date()
            let filtered = headacheRecords.filter { rec in
                guard let ts = rec.timestamp else { return false }
                return ts >= cutoff
            }
            
            correlationResult = weatherService
                .analyzeWeatherHeadacheCorrelation(with: Array(filtered))
            
            isAnalyzing = false
            print("✅ 天气关联分析完成，发现 \(correlationResult?.conditions.count ?? 0) 种天气条件")
        }
    }
}

// 新增：位置权限卡片
struct LocationPermissionCard: View {
    @ObservedObject private var weatherService = WeatherService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.circle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("需要位置权限")
                .font(.headline.bold())
            
            Text("天气分析功能需要获取您的位置信息来提供准确的天气数据和头痛风险预测")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let errorMessage = weatherService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("开启位置权限") {
                    weatherService.requestLocationPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("重新检查权限") {
                    weatherService.recheckLocationPermission()
                }
                .buttonStyle(.bordered)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("开启步骤：")
                    .font(.caption.bold())
                
                Text("1. 点击「开启位置权限」")
                Text("2. 在弹出的系统设置中找到「位置服务」")
                Text("3. 开启位置服务并为头痛日记选择「使用App时」")
                Text("4. 返回应用并点击「重新检查权限」")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 更新当前天气卡片，添加更好的错误处理
struct CurrentWeatherCard: View {
    @ObservedObject private var weatherService = WeatherService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("当前天气")
                    .font(.headline.bold())
                Spacer()
                
                if weatherService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("刷新") {
                        weatherService.requestCurrentLocationWeather()
                    }
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
            }
            
            if let weather = weatherService.currentWeather {
                currentWeatherContent(weather)
            } else if weatherService.isLoading {
                loadingContent()
            } else if let error = weatherService.errorMessage {
                errorContent(error)
            } else if !weatherService.isLocationAuthorized {
                permissionContent()
            } else {
                noDataContent()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // 加载中内容
    @ViewBuilder
    private func loadingContent() -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在获取天气数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
    
    // 权限内容
    @ViewBuilder
    private func permissionContent() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .foregroundColor(.red)
                .font(.title2)
            Text("需要位置权限")
                .font(.headline)
            Button("开启权限") {
                weatherService.requestLocationPermission()
            }
            .font(.caption.bold())
            .foregroundColor(.blue)
        }
        .frame(height: 100)
    }
    
    // 其他现有方法保持不变...
    @ViewBuilder
    private func currentWeatherContent(_ weather: WeatherRecord) -> some View {
        VStack(spacing: 12) {
            HStack {
                // 主要天气信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let condition = WeatherCondition(rawValue: weather.condition) {
                            Image(systemName: condition.icon)
                                .foregroundColor(.blue)
                                .font(.title)
                        }
                        Text("\(weather.temperature.formatted(.number.precision(.fractionLength(0))))°C")
                            .font(.largeTitle.bold())
                    }
                    
                    if let condition = WeatherCondition(rawValue: weather.condition) {
                        Text(condition.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 变化指示器
                VStack(alignment: .trailing, spacing: 4) {
                    if abs(weather.temperatureChange) > 0.1 {
                        HStack(spacing: 4) {
                            Image(systemName: weather.temperatureChange > 0 ? "arrow.up" : "arrow.down")
                                .foregroundColor(weather.temperatureChange > 0 ? .red : .blue)
                                .font(.caption)
                            Text("\(abs(weather.temperatureChange).formatted(.number.precision(.fractionLength(1))))°C")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if abs(weather.pressureChange) > 0.1 {
                        HStack(spacing: 4) {
                            Image(systemName: weather.pressureChange > 0 ? "arrow.up" : "arrow.down")
                                .foregroundColor(weather.pressureChange > 0 ? .orange : .green)
                                .font(.caption)
                            Text("\(abs(weather.pressureChange).formatted(.number.precision(.fractionLength(1))))hPa")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 详细数据
            HStack {
                WeatherDetailItem(icon: "humidity", label: "湿度", value: "\(weather.humidity.formatted(.number.precision(.fractionLength(0))))%")
                Spacer()
                WeatherDetailItem(icon: "barometer", label: "气压", value: "\(weather.pressure.formatted(.number.precision(.fractionLength(0))))hPa")
                Spacer()
                WeatherDetailItem(icon: "wind", label: "风速", value: "\(weather.windSpeed.formatted(.number.precision(.fractionLength(0))))km/h")
                Spacer()
                WeatherDetailItem(icon: "sun.max", label: "紫外线", value: "\(weather.uvIndex)")
            }
        }
    }
    
    @ViewBuilder
    private func errorContent(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            Text("获取天气失败")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("重新获取") {
                    weatherService.requestCurrentLocationWeather()
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
                
                Button("检查权限") {
                    weatherService.recheckLocationPermission()
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
            }
        }
        .frame(height: 100)
    }
    
    @ViewBuilder
    private func noDataContent() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud")
                .foregroundColor(.gray)
                .font(.title2)
            Text("点击刷新获取天气数据")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("获取天气") {
                weatherService.requestCurrentLocationWeather()
            }
            .font(.caption.bold())
            .foregroundColor(.blue)
        }
        .frame(height: 100)
    }
}

// ... 其他现有组件保持不变 ...
struct WeatherDetailItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// 头痛风险预警卡片
struct HeadacheRiskCard: View {
    @ObservedObject private var weatherService = WeatherService.shared
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: weatherService.currentRisk.icon)
                    .foregroundColor(Color(weatherService.currentRisk.color))
                    .font(.title2)
                Text("头痛风险评估")
                    .font(.headline.bold())
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 今日风险
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日风险")
                            .font(.subheadline.bold())
                        Text(weatherService.currentRisk.displayName)
                            .font(.title2.bold())
                            .foregroundColor(Color(weatherService.currentRisk.color))
                    }
                    
                    Spacer()
                    
                    // 明日风险
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("明日风险")
                            .font(.subheadline.bold())
                        Text(warningManager.tomorrowsRisk.displayName)
                            .font(.title2.bold())
                            .foregroundColor(Color(warningManager.tomorrowsRisk.color))
                    }
                }
                
                // 风险说明
                if weatherService.currentRisk.rawValue >= HeadacheRisk.moderate.rawValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("风险因素:")
                            .font(.caption.bold())
                        
                        if let weather = weatherService.currentWeather {
                            riskFactorsView(for: weather)
                        }
                    }
                    .padding(8)
                    .background(Color(weatherService.currentRisk.color).opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 建议
                if weatherService.currentRisk.rawValue >= HeadacheRisk.moderate.rawValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("建议:")
                            .font(.caption.bold())
                        Text(getRiskAdvice())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private func riskFactorsView(for weather: WeatherRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if abs(weather.pressureChange) > 2 {
                Text("• 气压变化: \(weather.pressureChange > 0 ? "+" : "")\(weather.pressureChange.formatted(.number.precision(.fractionLength(1))))hPa")
                    .font(.caption)
            }
            
            if abs(weather.temperatureChange) > 5 {
                Text("• 温度变化: \(weather.temperatureChange > 0 ? "+" : "")\(weather.temperatureChange.formatted(.number.precision(.fractionLength(1))))°C")
                    .font(.caption)
            }
            
            if weather.humidity > 80 {
                Text("• 高湿度: \(weather.humidity.formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption)
            }
            
            if weather.windSpeed > 25 {
                Text("• 大风: \(weather.windSpeed.formatted(.number.precision(.fractionLength(0))))km/h")
                    .font(.caption)
            }
        }
    }
    
    private func getRiskAdvice() -> String {
        switch weatherService.currentRisk {
        case .moderate:
            return "注意休息，避免过度劳累，准备常用止痛药物"
        case .high:
            return "建议减少外出，保持充足睡眠，随身携带药物"
        case .veryHigh:
            return "高风险期，建议在家休息，提前服用预防药物，如有不适及时就医"
        default:
            return "保持良好生活习惯"
        }
    }
}

// 天气关联分析卡片
struct WeatherCorrelationCard: View {
    let correlationResult: WeatherCorrelationResult?
    let isAnalyzing: Bool
    let timeRange: WeatherAnalysisView.TimeRange
    let onAnalyze: () -> Void
    let onTimeRangeChanged: (WeatherAnalysisView.TimeRange) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("天气关联分析")
                    .font(.headline.bold())
                Spacer()
                
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("重新分析", action: onAnalyze)
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }
            
            // 时间范围选择
            Picker("分析期间", selection: .constant(timeRange)) {
                ForEach(WeatherAnalysisView.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: timeRange) { newValue in
                onTimeRangeChanged(newValue)
            }
            
            if let result = correlationResult {
                correlationContent(result)
            } else if isAnalyzing {
                analysisLoadingContent()
            } else {
                noAnalysisContent()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private func correlationContent(_ result: WeatherCorrelationResult) -> some View {
        VStack(spacing: 12) {
            // 总体统计
            HStack {
                VStack {
                    Text("\(result.totalWeatherDays)")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                    Text("天气记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(result.totalHeadacheDays)")
                        .font(.title3.bold())
                        .foregroundColor(.red)
                    Text("头痛记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(result.overallHeadacheRate.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    Text("整体概率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            if !result.conditions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("各天气条件下的头痛概率:")
                        .font(.subheadline.bold())
                    
                    ForEach(result.conditions.prefix(6), id: \.id) { condition in
                        CorrelationRow(condition: condition)
                    }
                }
            }
            
            // 最高风险天气
            if let highestRisk = result.highestRiskCondition {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最容易引发头痛的天气:")
                        .font(.caption.bold())
                    
                    HStack {
                        if let conditionEnum = highestRisk.conditionEnum {
                            Image(systemName: conditionEnum.icon)
                                .foregroundColor(.red)
                        }
                        Text(highestRisk.conditionEnum?.displayName ?? highestRisk.condition)
                            .font(.caption.bold())
                        Spacer()
                        Text("\(highestRisk.headacheRate.formatted(.number.precision(.fractionLength(1))))%")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func analysisLoadingContent() -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("正在分析天气与头痛的关联性...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
    
    @ViewBuilder
    private func noAnalysisContent() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundColor(.gray)
                .font(.title2)
            Text("点击\"重新分析\"开始分析")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
}

struct CorrelationRow: View {
    let condition: WeatherConditionCorrelation
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if let conditionEnum = condition.conditionEnum {
                    Image(systemName: conditionEnum.icon)
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 16)
                }
                Text(condition.conditionEnum?.displayName ?? condition.condition)
                    .font(.caption)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(condition.headacheRate.formatted(.number.precision(.fractionLength(1))))%")
                    .font(.caption.bold())
                    .foregroundColor(rateColor(condition.headacheRate))
                
                Text("\(condition.headacheDays)/\(condition.totalDays)天")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<20: return .green
        case 20..<40: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// 最近预警历史卡片
struct RecentWarningsCard: View {
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    private var recentWarnings: [WeatherWarning] {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return warningManager.warnings.filter { $0.timestamp >= oneWeekAgo }.prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("最近预警")
                    .font(.headline.bold())
                Spacer()
                
                if !recentWarnings.isEmpty {
                    NavigationLink("查看全部") {
                        WeatherWarningsHistoryView()
                    }
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
            }
            
            if recentWarnings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("最近一周无预警")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentWarnings) { warning in
                        WarningRow(warning: warning)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct WarningRow: View {
    let warning: WeatherWarning
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: warning.type.icon)
                .foregroundColor(Color(warning.riskLevel.color))
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.message)
                    .font(.caption)
                    .lineLimit(2)
                
                Text(warning.timestamp, formatter: relativeDateFormatter)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !warning.isRead {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            warningManager.markWarningAsRead(warning.id)
        }
    }
}

// 天气趋势图表卡片
struct WeatherTrendCard: View {
    @ObservedObject private var weatherService = WeatherService.shared
    
    private var last7DaysWeather: [WeatherRecord] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return weatherService.weatherHistory
            .filter { $0.date >= sevenDaysAgo }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("天气趋势")
                    .font(.headline.bold())
                Spacer()
            }
            
            if last7DaysWeather.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text("暂无足够的天气历史数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else {
                WeatherTrendChart(weatherData: last7DaysWeather)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct WeatherTrendChart: View {
    let weatherData: [WeatherRecord]
    
    var body: some View {
        VStack(spacing: 12) {
            // 温度趋势
            VStack(alignment: .leading, spacing: 8) {
                Text("温度趋势")
                    .font(.caption.bold())
                
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(weatherData.enumerated()), id: \.offset) { index, weather in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 25, height: max(CGFloat(weather.temperature / 40 * 60), 10))
                                .cornerRadius(2)
                            
                            Text("\(weather.temperature.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption2.bold())
                            
                            Text(dayName(for: weather.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 100)
            }
            
            // 气压趋势
            VStack(alignment: .leading, spacing: 8) {
                Text("气压趋势")
                    .font(.caption.bold())
                
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(weatherData.enumerated()), id: \.offset) { index, weather in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: 25, height: max(CGFloat((weather.pressure - 980) / 40 * 60), 10))
                                .cornerRadius(2)
                            
                            Text("\(weather.pressure.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption2.bold())
                            
                            Text(dayName(for: weather.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 100)
            }
        }
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// 个性化建议卡片
struct PersonalizedAdviceCard: View {
    let correlationResult: WeatherCorrelationResult?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("个性化建议")
                    .font(.headline.bold())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if let result = correlationResult, !result.conditions.isEmpty {
                    ForEach(generateAdvice(from: result), id: \.self) { advice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(advice)
                                .font(.caption)
                        }
                    }
                } else {
                    Text("收集更多数据后，系统将为您提供个性化的天气防护建议")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func generateAdvice(from result: WeatherCorrelationResult) -> [String] {
        var advice: [String] = []
        
        // 基于最高风险天气的建议
        if let highestRisk = result.highestRiskCondition, highestRisk.headacheRate > 50 {
            let conditionName = highestRisk.conditionEnum?.displayName ?? "该天气"
            advice.append("在\(conditionName)时，您的头痛发生率为\(highestRisk.headacheRate.formatted(.number.precision(.fractionLength(1))))%，建议提前准备药物")
        }
        
        // 基于温度的建议
        if let avgTemp = result.conditions.first?.averageTemperature {
            if avgTemp < 15 {
                advice.append("低温天气时注意保暖，避免头部受凉")
            } else if avgTemp > 30 {
                advice.append("高温天气时注意防晒和补水，避免中暑")
            }
        }
        
        // 基于气压的建议
        if let avgPressure = result.conditions.first?.averagePressure {
            if avgPressure < 1000 {
                advice.append("低气压天气时增加休息时间，避免剧烈运动")
            }
        }
        
        // 通用建议
        if result.overallHeadacheRate > 30 {
            advice.append("您对天气变化较为敏感，建议关注天气预报并提前防护")
        }
        
        advice.append("保持规律作息和充足睡眠，有助于减少天气敏感性")
        
        return advice
    }
}

// 预警历史详情视图
struct WeatherWarningsHistoryView: View {
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    @State private var selectedFilter: WarningFilter = .all
    
    enum WarningFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case highRisk = "高风险"
        case last7Days = "最近7天"
        
        func filter(_ warnings: [WeatherWarning]) -> [WeatherWarning] {
            switch self {
            case .all:
                return warnings
            case .unread:
                return warnings.filter { !$0.isRead }
            case .highRisk:
                return warnings.filter { $0.riskLevel.rawValue >= HeadacheRisk.high.rawValue }
            case .last7Days:
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return warnings.filter { $0.timestamp >= sevenDaysAgo }
            }
        }
    }
    
    private var filteredWarnings: [WeatherWarning] {
        selectedFilter.filter(warningManager.warnings)
    }
    
    var body: some View {
        VStack {
            // 筛选器
            Picker("筛选", selection: $selectedFilter) {
                ForEach(WarningFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if filteredWarnings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                        .font(.largeTitle)
                    Text("暂无预警记录")
                        .font(.headline)
                    Text("系统会根据天气变化为您发送头痛风险预警")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredWarnings) { warning in
                        DetailedWarningRow(warning: warning)
                    }
                }
            }
        }
        .navigationTitle("预警历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清理已读") {
                    warningManager.clearOldWarnings()
                }
                .font(.caption)
            }
        }
    }
}

struct DetailedWarningRow: View {
    let warning: WeatherWarning
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: warning.type.icon)
                        .foregroundColor(Color(warning.riskLevel.color))
                    Text(warning.type.title)
                        .font(.subheadline.bold())
                    Spacer()
                    if !warning.isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(warning.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(warning.timestamp, formatter: fullDateFormatter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(warning.riskLevel.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(warning.riskLevel.color).opacity(0.2))
                        .foregroundColor(Color(warning.riskLevel.color))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !warning.isRead {
                warningManager.markWarningAsRead(warning.id)
            }
        }
    }
}

private let relativeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.doesRelativeDateFormatting = true
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

private let fullDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    WeatherAnalysisView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
