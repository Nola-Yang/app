//
//  WeatherWarningManager.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//


import Foundation
import UserNotifications
import Combine

// 预警设置
struct WeatherWarningSettings: Codable {
    var isEnabled: Bool = true
    var riskThreshold: HeadacheRisk = .moderate
    var pressureChangeThreshold: Double = 3.0 // 百帕
    var temperatureChangeThreshold: Double = 8.0 // 摄氏度
    var humidityThreshold: Double = 80.0 // 百分比
    var windSpeedThreshold: Double = 25.0 // km/h
    var enabledConditions: Set<String> = [
        WeatherCondition.stormy.rawValue,
        WeatherCondition.rainy.rawValue
    ]
    var notificationTiming: NotificationTiming = .morning
    var enableDailyForecast: Bool = true
    var enableRealTimeWarning: Bool = true
    
    enum NotificationTiming: String, CaseIterable, Codable {
        case morning = "morning"
        case evening = "evening"
        case both = "both"
        
        var displayName: String {
            switch self {
            case .morning: return "早上7:00"
            case .evening: return "晚上20:00"
            case .both: return "早晚各一次"
            }
        }
    }
}

// 预警类型
enum WeatherWarningType: String, CaseIterable {
    case pressureChange = "pressure_change"
    case temperatureChange = "temperature_change"
    case highHumidity = "high_humidity"
    case stormyWeather = "stormy_weather"
    case windyWeather = "windy_weather"
    case generalRisk = "general_risk"
    
    var title: String {
        switch self {
        case .pressureChange: return "气压变化预警"
        case .temperatureChange: return "温度变化预警"
        case .highHumidity: return "高湿度预警"
        case .stormyWeather: return "暴风雨预警"
        case .windyWeather: return "大风预警"
        case .generalRisk: return "头痛风险预警"
        }
    }
    
    var icon: String {
        switch self {
        case .pressureChange: return "barometer"
        case .temperatureChange: return "thermometer"
        case .highHumidity: return "humidity"
        case .stormyWeather: return "cloud.bolt.rain"
        case .windyWeather: return "wind"
        case .generalRisk: return "exclamationmark.triangle"
        }
    }
}

// 预警记录
struct WeatherWarning: Identifiable, Codable {
    let id: UUID
    let type: WeatherWarningType
    let timestamp: Date
    let message: String
    let riskLevel: HeadacheRisk
    let weatherData: WeatherRecord
    let isRead: Bool
    
    init(type: WeatherWarningType, message: String, riskLevel: HeadacheRisk, weatherData: WeatherRecord, isRead: Bool = false) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.message = message
        self.riskLevel = riskLevel
        self.weatherData = weatherData
        self.isRead = isRead
    }
}

// 天气预警管理器
@MainActor
class WeatherWarningManager: ObservableObject {
    static let shared = WeatherWarningManager()
    
    @Published var settings = WeatherWarningSettings()
    @Published var warnings: [WeatherWarning] = []
    @Published var todaysRisk: HeadacheRisk = .low
    @Published var tomorrowsRisk: HeadacheRisk = .low
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "WeatherWarningSettings"
    private let warningsKey = "WeatherWarnings"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSettings()
        loadWarnings()
        setupWeatherMonitoring()
    }
    
    // MARK: - 设置管理
    
    func updateSettings(_ newSettings: WeatherWarningSettings) {
        settings = newSettings
        saveSettings()
        
        if newSettings.isEnabled {
            scheduleRegularChecks()
        } else {
            cancelAllScheduledChecks()
        }
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("❌ 保存天气预警设置失败: \(error)")
        }
    }
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey) else { return }
        
        do {
            settings = try JSONDecoder().decode(WeatherWarningSettings.self, from: data)
        } catch {
            print("❌ 加载天气预警设置失败: \(error)")
            settings = WeatherWarningSettings()
        }
    }
    
    // MARK: - 预警监控
    
    private func setupWeatherMonitoring() {
        // 监听天气服务的变化
        WeatherService.shared.$currentWeather
            .sink { [weak self] weatherRecord in
                guard let self = self, let weather = weatherRecord else { return }
                Task {
                    await self.checkForWarnings(weather: weather)
                }
            }
            .store(in: &cancellables)
        
        // 监听头痛风险变化
        WeatherService.shared.$currentRisk
            .sink { [weak self] risk in
                self?.todaysRisk = risk
            }
            .store(in: &cancellables)
    }
    
    private func checkForWarnings(weather: WeatherRecord) async {
        guard settings.isEnabled else { return }
        
        var potentialWarnings: [WeatherWarning] = []
        
        // 检查气压变化
        if abs(weather.pressureChange) >= settings.pressureChangeThreshold {
            let direction = weather.pressureChange > 0 ? "上升" : "下降"
            let message = "气压\(direction)\(abs(weather.pressureChange).formatted(.number.precision(.fractionLength(1))))百帕，可能引发头痛"
            let warning = WeatherWarning(
                type: .pressureChange,
                message: message,
                riskLevel: determineRiskLevel(for: abs(weather.pressureChange), threshold: settings.pressureChangeThreshold),
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 检查温度变化
        if abs(weather.temperatureChange) >= settings.temperatureChangeThreshold {
            let direction = weather.temperatureChange > 0 ? "上升" : "下降"
            let message = "温度\(direction)\(abs(weather.temperatureChange).formatted(.number.precision(.fractionLength(1))))°C，注意头痛风险"
            let warning = WeatherWarning(
                type: .temperatureChange,
                message: message,
                riskLevel: determineRiskLevel(for: abs(weather.temperatureChange), threshold: settings.temperatureChangeThreshold),
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 检查湿度
        if weather.humidity >= settings.humidityThreshold {
            let message = "湿度高达\(weather.humidity.formatted(.number.precision(.fractionLength(0))))%，可能影响舒适度"
            let warning = WeatherWarning(
                type: .highHumidity,
                message: message,
                riskLevel: .moderate,
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 检查风速
        if weather.windSpeed >= settings.windSpeedThreshold {
            let message = "风速达到\(weather.windSpeed.formatted(.number.precision(.fractionLength(0))))km/h，大风天气注意保暖"
            let warning = WeatherWarning(
                type: .windyWeather,
                message: message,
                riskLevel: .moderate,
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 检查天气条件
        if settings.enabledConditions.contains(weather.condition) {
            let conditionName = WeatherCondition(rawValue: weather.condition)?.displayName ?? "恶劣天气"
            let message = "预报\(conditionName)，请注意头痛风险并做好准备"
            let warning = WeatherWarning(
                type: .stormyWeather,
                message: message,
                riskLevel: .high,
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 检查综合风险
        if todaysRisk.rawValue >= settings.riskThreshold.rawValue {
            let message = "今日头痛风险：\(todaysRisk.displayName)，建议提前准备"
            let warning = WeatherWarning(
                type: .generalRisk,
                message: message,
                riskLevel: todaysRisk,
                weatherData: weather
            )
            potentialWarnings.append(warning)
        }
        
        // 添加新预警并发送通知
        for warning in potentialWarnings {
            if !isDuplicateWarning(warning) {
                addWarning(warning)
                if settings.enableRealTimeWarning {
                    await sendWarningNotification(warning)
                }
            }
        }
    }
    
    private func determineRiskLevel(for value: Double, threshold: Double) -> HeadacheRisk {
        let ratio = value / threshold
        switch ratio {
        case 1.0..<1.5: return .moderate
        case 1.5..<2.0: return .high
        default: return .veryHigh
        }
    }
    
    private func isDuplicateWarning(_ warning: WeatherWarning) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return warnings.contains { existing in
            existing.type == warning.type &&
            Calendar.current.startOfDay(for: existing.timestamp) == today
        }
    }
    
    // MARK: - 预警管理
    
    private func addWarning(_ warning: WeatherWarning) {
        warnings.insert(warning, at: 0)
        
        // 保持最近30天的预警
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        warnings = warnings.filter { $0.timestamp >= thirtyDaysAgo }
        
        saveWarnings()
        print("✅ 添加天气预警: \(warning.type.title)")
    }
    
    func markWarningAsRead(_ warningId: UUID) {
        if let index = warnings.firstIndex(where: { $0.id == warningId }) {
            let updatedWarning = WeatherWarning(
                type: warnings[index].type,
                message: warnings[index].message,
                riskLevel: warnings[index].riskLevel,
                weatherData: warnings[index].weatherData,
                isRead: true
            )
            warnings[index] = updatedWarning
            saveWarnings()
        }
    }
    
    func clearOldWarnings() {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        warnings = warnings.filter { $0.timestamp >= oneWeekAgo || !$0.isRead }
        saveWarnings()
    }
    
    private func saveWarnings() {
        do {
            let data = try JSONEncoder().encode(warnings)
            userDefaults.set(data, forKey: warningsKey)
        } catch {
            print("❌ 保存天气预警失败: \(error)")
        }
    }
    
    private func loadWarnings() {
        guard let data = userDefaults.data(forKey: warningsKey) else { return }
        
        do {
            warnings = try JSONDecoder().decode([WeatherWarning].self, from: data)
        } catch {
            print("❌ 加载天气预警失败: \(error)")
            warnings = []
        }
    }
    
    // MARK: - 通知管理
    
    func scheduleRegularChecks() {
        cancelAllScheduledChecks()
        
        if settings.enableDailyForecast {
            switch settings.notificationTiming {
            case .morning:
                scheduleDailyNotification(hour: 7, minute: 0)
            case .evening:
                scheduleDailyNotification(hour: 20, minute: 0)
            case .both:
                scheduleDailyNotification(hour: 7, minute: 0)
                scheduleDailyNotification(hour: 20, minute: 0)
            }
        }
    }
    
    private func scheduleDailyNotification(hour: Int, minute: Int) {
        let identifier = "weather_forecast_\(hour)_\(minute)"
        
        let content = UNMutableNotificationContent()
        content.title = "头痛天气预报"
        content.sound = .default
        content.categoryIdentifier = "weather_forecast_category"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 安排天气预报通知失败: \(error)")
            } else {
                print("✅ 安排天气预报通知: \(hour):\(minute)")
            }
        }
    }
    
    private func sendWarningNotification(_ warning: WeatherWarning) async {
        let content = UNMutableNotificationContent()
        content.title = warning.type.title
        content.body = warning.message
        content.sound = .default
        content.badge = 1
        
        // 根据风险级别设置不同的图标和优先级
        switch warning.riskLevel {
        case .low:
            content.interruptionLevel = .passive
        case .moderate:
            content.interruptionLevel = .active
        case .high, .veryHigh:
            content.interruptionLevel = .timeSensitive
        }
        
        content.userInfo = [
            "type": "weather_warning",
            "warningId": warning.id.uuidString,
            "riskLevel": warning.riskLevel.rawValue
        ]
        
        // 添加操作按钮
        let viewAction = UNNotificationAction(
            identifier: "view_warning",
            title: "查看详情",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "dismiss_warning",
            title: "知道了",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "weather_warning_category",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "weather_warning_category"
        
        let request = UNNotificationRequest(
            identifier: warning.id.uuidString,
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送天气预警通知: \(warning.type.title)")
        } catch {
            print("❌ 发送天气预警通知失败: \(error)")
        }
    }
    
    func cancelAllScheduledChecks() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let weatherNotificationIds = requests
                .filter { $0.identifier.hasPrefix("weather_forecast_") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: weatherNotificationIds)
            print("✅ 取消所有天气预报通知")
        }
    }
    
    // MARK: - 每日预报
    
    func generateDailyForecast() async -> String {
        // 获取明天的天气预报
        guard let tomorrowWeather = await WeatherService.shared.fetchTomorrowWeatherForecast() else {
            return "无法获取明天的天气预报"
        }
        
        // 分析明天的头痛风险
        tomorrowsRisk = analyzeForecastRisk(weather: tomorrowWeather)
        
        let conditionName = WeatherCondition(rawValue: tomorrowWeather.condition)?.displayName ?? "未知"
        
        var forecast = "明天天气：\(conditionName)，"
        forecast += "温度\(tomorrowWeather.temperature.formatted(.number.precision(.fractionLength(0))))°C，"
        forecast += "头痛风险：\(tomorrowsRisk.displayName)"
        
        if tomorrowsRisk.rawValue >= HeadacheRisk.moderate.rawValue {
            forecast += "\n建议提前准备止痛药物，注意休息"
        }
        
        return forecast
    }
    
    private func analyzeForecastRisk(weather: WeatherRecord) -> HeadacheRisk {
        var riskScore = 0
        
        // 基于天气条件评估风险
        switch weather.condition {
        case WeatherCondition.stormy.rawValue:
            riskScore += 3
        case WeatherCondition.rainy.rawValue:
            riskScore += 2
        case WeatherCondition.cloudy.rawValue, WeatherCondition.foggy.rawValue:
            riskScore += 1
        default:
            break
        }
        
        // 基于降水概率
        if weather.precipitationChance > 70 {
            riskScore += 2
        } else if weather.precipitationChance > 40 {
            riskScore += 1
        }
        
        // 基于风速
        if weather.windSpeed > 30 {
            riskScore += 1
        }
        
        // 确定风险级别
        switch riskScore {
        case 0...1: return .low
        case 2...3: return .moderate
        case 4...5: return .high
        default: return .veryHigh
        }
    }
    
    // MARK: - 统计分析
    
    func getWarningStatistics() -> WeatherWarningStatistics {
        let last30Days = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentWarnings = warnings.filter { $0.timestamp >= last30Days }
        
        var typeCounts: [WeatherWarningType: Int] = [:]
        var riskCounts: [HeadacheRisk: Int] = [:]
        
        for warning in recentWarnings {
            typeCounts[warning.type, default: 0] += 1
            riskCounts[warning.riskLevel, default: 0] += 1
        }
        
        return WeatherWarningStatistics(
            totalWarnings: recentWarnings.count,
            warningsByType: typeCounts,
            warningsByRisk: riskCounts,
            averageWarningsPerWeek: Double(recentWarnings.count) / 4.0,
            mostCommonWarningType: typeCounts.max(by: { $0.value < $1.value })?.key
        )
    }
}

// 统计数据结构
struct WeatherWarningStatistics {
    let totalWarnings: Int
    let warningsByType: [WeatherWarningType: Int]
    let warningsByRisk: [HeadacheRisk: Int]
    let averageWarningsPerWeek: Double
    let mostCommonWarningType: WeatherWarningType?
}
