//
//  WeatherSettingsView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//

//
//  WeatherSettingsView.swift
//  HeadacheDiary
//
//  Created by Claude on 2025-06-06.
//

import SwiftUI
import UserNotifications

struct WeatherSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var weatherService = WeatherService.shared
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    @State private var settings: WeatherWarningSettings
    @State private var showLocationAlert = false
    @State private var showNotificationAlert = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        _settings = State(initialValue: WeatherWarningManager.shared.settings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 功能概述
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cloud.sun.bolt")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("天气与头痛分析")
                                    .font(.headline.bold())
                                Text("智能监控天气变化，预测头痛风险")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 当前状态
                        HStack {
                            StatusItem(
                                title: "位置权限",
                                status: weatherService.isLocationAuthorized ? "已授权" : "未授权",
                                color: weatherService.isLocationAuthorized ? .green : .red
                            )
                            
                            StatusItem(
                                title: "通知权限",
                                status: notificationStatusText,
                                color: notificationStatus == .authorized ? .green : .red
                            )
                            
                            StatusItem(
                                title: "预警功能",
                                status: settings.isEnabled ? "已启用" : "已禁用",
                                color: settings.isEnabled ? .green : .gray
                            )
                        }
                    }
                } header: {
                    Text("功能状态")
                }
                
                // 基本设置
                Section {
                    Toggle("启用天气预警", isOn: $settings.isEnabled)
                        .onChange(of: settings.isEnabled) { newValue in
                            if newValue && !weatherService.isLocationAuthorized {
                                showLocationAlert = true
                            }
                            if newValue && notificationStatus != .authorized {
                                showNotificationAlert = true
                            }
                        }
                    
                    if settings.isEnabled {
                        Toggle("实时风险预警", isOn: $settings.enableRealTimeWarning)
                        Toggle("每日风险预报", isOn: $settings.enableDailyForecast)
                        
                        if settings.enableDailyForecast {
                            Picker("预报时间", selection: $settings.notificationTiming) {
                                ForEach(WeatherWarningSettings.NotificationTiming.allCases, id: \.self) { timing in
                                    Text(timing.displayName).tag(timing)
                                }
                            }
                        }
                    }
                } header: {
                    Text("基本设置")
                } footer: {
                    if settings.isEnabled {
                        Text("实时预警会在检测到高风险天气时立即通知，每日预报会定时发送当日和次日的头痛风险评估")
                    }
                }
                
                // 预警阈值设置
                if settings.isEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("最低预警风险级别")
                                .font(.subheadline.bold())
                            
                            Picker("风险级别", selection: $settings.riskThreshold) {
                                ForEach(HeadacheRisk.allCases, id: \.self) { risk in
                                    HStack {
                                        Image(systemName: risk.icon)
                                        Text(risk.displayName)
                                    }
                                    .tag(risk)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Text("只有达到或超过此风险级别时才会发送预警")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("气压变化阈值")
                                Spacer()
                                Text("\(settings.pressureChangeThreshold.formatted(.number.precision(.fractionLength(1))))百帕")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.pressureChangeThreshold, in: 1...10, step: 0.5)
                                .accentColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("温度变化阈值")
                                Spacer()
                                Text("\(settings.temperatureChangeThreshold.formatted(.number.precision(.fractionLength(1))))°C")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.temperatureChangeThreshold, in: 3...15, step: 0.5)
                                .accentColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("湿度阈值")
                                Spacer()
                                Text("\(settings.humidityThreshold.formatted(.number.precision(.fractionLength(0))))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.humidityThreshold, in: 60...95, step: 5)
                                .accentColor(.cyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("风速阈值")
                                Spacer()
                                Text("\(settings.windSpeedThreshold.formatted(.number.precision(.fractionLength(0))))km/h")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.windSpeedThreshold, in: 15...50, step: 5)
                                .accentColor(.green)
                        }
                    } header: {
                        Text("预警阈值")
                    } footer: {
                        Text("当天气参数变化超过设定阈值时，系统会评估头痛风险并发送相应预警")
                    }
                    
                    // 天气条件设置
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("需要预警的天气条件")
                                .font(.subheadline.bold())
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(WeatherCondition.allCases, id: \.self) { condition in
                                    WeatherConditionToggle(
                                        condition: condition,
                                        isEnabled: settings.enabledConditions.contains(condition.rawValue)
                                    ) { isEnabled in
                                        if isEnabled {
                                            settings.enabledConditions.insert(condition.rawValue)
                                        } else {
                                            settings.enabledConditions.remove(condition.rawValue)
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("天气条件")
                    } footer: {
                        Text("选中的天气条件出现时会触发预警")
                    }
                }
                
                // 权限管理
                Section {
                    Button(action: requestLocationPermission) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(weatherService.isLocationAuthorized ? .green : .red)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("位置权限")
                                Text(weatherService.isLocationAuthorized ? "已授权" : "需要授权才能获取天气数据")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !weatherService.isLocationAuthorized {
                                Text("授权")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(weatherService.isLocationAuthorized)
                    
                    Button(action: requestNotificationPermission) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(notificationStatus == .authorized ? .green : .red)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("通知权限")
                                Text(notificationStatusText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if notificationStatus != .authorized {
                                Text("授权")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(notificationStatus == .authorized)
                } header: {
                    Text("权限管理")
                }
                
                // 数据管理
                Section {
                    Button("刷新当前天气") {
                        weatherService.requestCurrentLocationWeather()
                    }
                    .foregroundColor(.blue)
                    
                    Button("清除天气历史") {
                        clearWeatherHistory()
                    }
                    .foregroundColor(.orange)
                    
                    Button("清除预警历史") {
                        warningManager.clearOldWarnings()
                    }
                    .foregroundColor(.orange)
                    
                    NavigationLink("查看预警统计") {
                        WeatherStatisticsView()
                    }
                } header: {
                    Text("数据管理")
                }
                
                // 帮助信息
                Section {
                    DisclosureGroup("天气参数说明") {
                        VStack(alignment: .leading, spacing: 8) {
                            HelpItem(
                                icon: "barometer",
                                title: "气压变化",
                                description: "气压快速变化常与头痛发作相关，特别是低气压和气压下降"
                            )
                            
                            HelpItem(
                                icon: "thermometer",
                                title: "温度变化",
                                description: "温度骤变可能触发头痛，冷热交替尤其需要注意"
                            )
                            
                            HelpItem(
                                icon: "humidity",
                                title: "湿度",
                                description: "高湿度环境可能加重头痛症状，影响舒适度"
                            )
                            
                            HelpItem(
                                icon: "wind",
                                title: "风速",
                                description: "大风天气可能导致头部受凉，诱发头痛"
                            )
                        }
                    }
                } header: {
                    Text("帮助信息")
                }
            }
            .navigationTitle("天气设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                checkNotificationPermission()
            }
            .alert("需要位置权限", isPresented: $showLocationAlert) {
                Button("去设置") {
                    openSettings()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在系统设置中为HeadacheDiary开启位置权限，以获取准确的天气数据")
            }
            .alert("需要通知权限", isPresented: $showNotificationAlert) {
                Button("去设置") {
                    openSettings()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在系统设置中为HeadacheDiary开启通知权限，以接收天气预警")
            }
        }
    }
    
    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未询问"
        case .provisional: return "临时授权"
        case .ephemeral: return "临时权限"
        @unknown default: return "未知状态"
        }
    }
    
    private func saveSettings() {
        warningManager.updateSettings(settings)
    }
    
    private func requestLocationPermission() {
        weatherService.requestLocationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                checkNotificationPermission()
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func clearWeatherHistory() {
        // 清除天气历史数据
        weatherService.weatherHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "WeatherHistory")
    }
}

// 状态项组件
struct StatusItem: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 天气条件切换组件
struct WeatherConditionToggle: View {
    let condition: WeatherCondition
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: { onToggle(!isEnabled) }) {
            HStack(spacing: 8) {
                Image(systemName: condition.icon)
                    .foregroundColor(isEnabled ? .white : .blue)
                    .font(.caption)
                Text(condition.displayName)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isEnabled ? Color.blue : Color.blue.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 帮助项组件
struct HelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// 预警统计视图
struct WeatherStatisticsView: View {
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    private var statistics: WeatherWarningStatistics {
        warningManager.getWarningStatistics()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 总体统计卡片
                OverallWarningStatsCard(statistics: statistics)
                
                // 预警类型分布
                WarningTypeDistributionCard(statistics: statistics)
                
                // 风险级别分布
                RiskLevelDistributionCard(statistics: statistics)
                
                // 趋势分析
                WarningTrendCard()
            }
            .padding()
        }
        .navigationTitle("预警统计")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OverallWarningStatsCard: View {
    let statistics: WeatherWarningStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            Text("总体统计")
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                StatCard(
                    title: "总预警数",
                    value: "\(statistics.totalWarnings)",
                    subtitle: "最近30天",
                    color: .blue
                )
                
                StatCard(
                    title: "周平均",
                    value: "\(statistics.averageWarningsPerWeek.formatted(.number.precision(.fractionLength(1))))",
                    subtitle: "次/周",
                    color: .orange
                )
                
                if let mostCommon = statistics.mostCommonWarningType {
                    StatCard(
                        title: "最常见",
                        value: mostCommon.title.prefix(4) + "...",
                        subtitle: "类型",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct WarningTypeDistributionCard: View {
    let statistics: WeatherWarningStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            Text("预警类型分布")
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if statistics.warningsByType.isEmpty {
                Text("暂无预警数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(statistics.warningsByType.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(type.title)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline.bold())
                                .foregroundColor(.blue)
                        }
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

struct RiskLevelDistributionCard: View {
    let statistics: WeatherWarningStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            Text("风险级别分布")
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if statistics.warningsByRisk.isEmpty {
                Text("暂无风险数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack {
                    ForEach(HeadacheRisk.allCases, id: \.self) { risk in
                        if let count = statistics.warningsByRisk[risk], count > 0 {
                            VStack(spacing: 8) {
                                Text("\(count)")
                                    .font(.title2.bold())
                                    .foregroundColor(Color(risk.color))
                                Text(risk.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
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

struct WarningTrendCard: View {
    @ObservedObject private var warningManager = WeatherWarningManager.shared
    
    private var last7DaysWarnings: [(String, Int)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E"
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayName = dateFormatter.string(from: date)
            let count = warningManager.warnings.filter { warning in
                calendar.isDate(warning.timestamp, inSameDayAs: date)
            }.count
            return (dayName, count)
        }.reversed()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("最近7天趋势")
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(last7DaysWarnings, id: \.0) { day, count in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 30, height: max(CGFloat(count * 15), 4))
                            .cornerRadius(4)
                        
                        Text("\(count)")
                            .font(.caption2.bold())
                        
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 80)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption.bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    WeatherSettingsView()
}
