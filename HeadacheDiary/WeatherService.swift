//
//  WeatherService.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//

import Foundation
import WeatherKit
import CoreLocation
import Combine
import UIKit

// 天气记录数据模型
struct WeatherRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let location: CLLocationCoordinate2D
    let temperature: Double // 摄氏度
    let humidity: Double // 百分比 0-100
    let pressure: Double // 百帕
    let condition: String // 天气状况
    let uvIndex: Int
    let windSpeed: Double // km/h
    let precipitationChance: Double // 降水概率 0-100
    let temperatureChange: Double // 相对前一天的温度变化
    let pressureChange: Double // 相对前一天的气压变化
    
    init(id: UUID = UUID(), date: Date, location: CLLocationCoordinate2D, temperature: Double, humidity: Double, pressure: Double, condition: String, uvIndex: Int, windSpeed: Double, precipitationChance: Double, temperatureChange: Double = 0, pressureChange: Double = 0) {
        self.id = id
        self.date = date
        self.location = location
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.condition = condition
        self.uvIndex = uvIndex
        self.windSpeed = windSpeed
        self.precipitationChance = precipitationChance
        self.temperatureChange = temperatureChange
        self.pressureChange = pressureChange
    }
}

// 天气条件枚举
enum WeatherCondition: String, CaseIterable {
    case sunny = "sunny"
    case cloudy = "cloudy"
    case rainy = "rainy"
    case stormy = "stormy"
    case snowy = "snowy"
    case foggy = "foggy"
    case windy = "windy"
    
    var displayName: String {
        switch self {
        case .sunny: return "晴天"
        case .cloudy: return "多云"
        case .rainy: return "下雨"
        case .stormy: return "暴风雨"
        case .snowy: return "下雪"
        case .foggy: return "雾天"
        case .windy: return "大风"
        }
    }
    
    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        case .snowy: return "cloud.snow.fill"
        case .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        }
    }
}

enum HeadacheRisk: Int, CaseIterable, Codable {
    case low = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4
    
    var displayName: String {
        switch self {
        case .low: return "低风险"
        case .moderate: return "中等风险"
        case .high: return "高风险"
        case .veryHigh: return "极高风险"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .moderate: return "exclamationmark.shield"
        case .high: return "exclamationmark.triangle"
        case .veryHigh: return "exclamationmark.octagon"
        }
    }
}

// 天气服务类
@MainActor
class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()
    
    @Published var currentWeather: WeatherRecord?
    @Published var weatherHistory: [WeatherRecord] = []
    @Published var currentRisk: HeadacheRisk = .low
    @Published var isLocationAuthorized = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var weatherDataSnapshot: WeatherDataSnapshot?
    
    private let weatherService = WeatherKit.WeatherService()
    private let locationManager = CLLocationManager()
    private let userDefaults = UserDefaults.standard
    private let weatherHistoryKey = "WeatherHistory"
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        loadWeatherHistory()
        requestLocationPermission()
    }
    
    // MARK: - 权限管理
    
    private func openAppSettings() {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl) { success in
                    if success {
                        print("✅ 成功打开系统设置")
                    } else {
                        print("❌ 无法打开系统设置")
                    }
                }
            }
    }
    
    func requestLocationPermission() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                isLocationAuthorized = true
                requestCurrentLocationWeather()
            case .denied, .restricted:
                isLocationAuthorized = false
                errorMessage = "位置权限被拒绝，请在系统设置中开启"
                // 跳转到系统设置
                openAppSettings()
            @unknown default:
                break
            }
    }
    
    func recheckLocationPermission() {
        let status = locationManager.authorizationStatus
        print("🔍 重新检查位置权限状态: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            errorMessage = nil
            requestCurrentLocationWeather()
            print("✅ 位置权限已授权")
        case .denied, .restricted:
            isLocationAuthorized = false
            errorMessage = "位置权限被拒绝，请在系统设置中开启"
            print("❌ 位置权限被拒绝")
        case .notDetermined:
            isLocationAuthorized = false
            errorMessage = "位置权限未确定"
            print("⚠️ 位置权限未确定")
        @unknown default:
            break
        }
    }
    
    // MARK: - 天气数据获取
    
    func requestCurrentLocationWeather() {
        guard isLocationAuthorized else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            let currentWeatherRecord = createWeatherRecord(from: weather, location: location.coordinate)
            
            // 更新当前天气
            currentWeather = currentWeatherRecord
            
            // 保存到历史记录
            addWeatherRecord(currentWeatherRecord)
            
            // 分析头痛风险
            await analyzeHeadacheRisk()
            
            // 更新天气数据快照
            updateWeatherDataSnapshot(from: currentWeatherRecord)
            
            print("✅ 天气数据获取成功: \(currentWeatherRecord.condition), 温度: \(currentWeatherRecord.temperature)°C")
            
        } catch {
            errorMessage = "获取天气数据失败: \(error.localizedDescription)"
            print("❌ 天气数据获取失败: \(error)")
        }
        
        isLoading = false
    }
    
    private func createWeatherRecord(from weather: Weather, location: CLLocationCoordinate2D) -> WeatherRecord {
        let currentCondition = mapWeatherKitCondition(weather.currentWeather.condition)
        
        // 计算温度和气压变化
        let temperatureChange = calculateTemperatureChange(current: weather.currentWeather.temperature.value)
        let pressureChange = calculatePressureChange(current: weather.currentWeather.pressure.value)
        
        return WeatherRecord(
            date: Date(),
            location: location,
            temperature: weather.currentWeather.temperature.value,
            humidity: weather.currentWeather.humidity * 100,
            pressure: weather.currentWeather.pressure.value,
            condition: currentCondition.rawValue,
            uvIndex: weather.currentWeather.uvIndex.value,
            windSpeed: weather.currentWeather.wind.speed.value * 3.6, // 转换为km/h
            precipitationChance: (weather.dailyForecast.first?.precipitationChance ?? 0) * 100,
            temperatureChange: temperatureChange,
            pressureChange: pressureChange
        )
    }
    
    // FIXED: Add the missing mapWeatherKitCondition function
    private func mapWeatherKitCondition(_ condition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch condition {
        case .clear:
            return .sunny
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return .cloudy
        case .rain, .drizzle, .heavyRain:
            return .rainy
        case .thunderstorms:
            return .stormy
        case .snow, .heavySnow, .blizzard:
            return .snowy
        case .windy:
            return .windy
        default:
            // For any other conditions, default to cloudy
            return .cloudy
        }
    }
    
    private func calculateTemperatureChange(current: Double) -> Double {
        guard let yesterday = weatherHistory.last else { return 0 }
        return current - yesterday.temperature
    }
    
    private func calculatePressureChange(current: Double) -> Double {
        guard let yesterday = weatherHistory.last else { return 0 }
        return current - yesterday.pressure
    }
    
    // MARK: - 数据存储
    
    private func addWeatherRecord(_ record: WeatherRecord) {
        // 检查是否已存在今天的记录
        let calendar = Calendar.current
        let today = Date()
        
        if let existingIndex = weatherHistory.firstIndex(where: { existing in
            calendar.isDate(existing.date, inSameDayAs: today)
        }) {
            // 更新今天的记录
            weatherHistory[existingIndex] = record
        } else {
            // 添加新记录
            weatherHistory.append(record)
        }
        
        // 保持最近30天的记录
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        weatherHistory = weatherHistory.filter { $0.date >= thirtyDaysAgo }
        
        saveWeatherHistory()
    }
    
    private func saveWeatherHistory() {
        do {
            let data = try JSONEncoder().encode(weatherHistory)
            userDefaults.set(data, forKey: weatherHistoryKey)
        } catch {
            print("❌ 保存天气历史失败: \(error)")
        }
    }
    
    private func loadWeatherHistory() {
        guard let data = userDefaults.data(forKey: weatherHistoryKey) else { return }
        
        do {
            weatherHistory = try JSONDecoder().decode([WeatherRecord].self, from: data)
            print("✅ 加载了 \(weatherHistory.count) 条天气历史记录")
        } catch {
            print("❌ 加载天气历史失败: \(error)")
            weatherHistory = []
        }
    }
    
    // MARK: - 风险分析
    
    func analyzeHeadacheRisk() async {
        guard let current = currentWeather else {
            currentRisk = .low
            return
        }
        
        var riskScore = 0
        
        // 气压变化分析
        if abs(current.pressureChange) > 5 {
            riskScore += 2
        } else if abs(current.pressureChange) > 2 {
            riskScore += 1
        }
        
        // 温度变化分析
        if abs(current.temperatureChange) > 10 {
            riskScore += 2
        } else if abs(current.temperatureChange) > 5 {
            riskScore += 1
        }
        
        // 湿度分析
        if current.humidity > 80 || current.humidity < 30 {
            riskScore += 1
        }
        
        // 天气条件分析
        switch current.condition {
        case WeatherCondition.stormy.rawValue, WeatherCondition.rainy.rawValue:
            riskScore += 2
        case WeatherCondition.cloudy.rawValue, WeatherCondition.foggy.rawValue:
            riskScore += 1
        default:
            break
        }
        
        // 风速分析
        if current.windSpeed > 30 {
            riskScore += 1
        }
        
        // 确定风险级别
        switch riskScore {
        case 0...1:
            currentRisk = .low
        case 2...3:
            currentRisk = .moderate
        case 4...5:
            currentRisk = .high
        default:
            currentRisk = .veryHigh
        }
        
        print("✅ 头痛风险分析完成: \(currentRisk.displayName) (得分: \(riskScore))")
    }
    
    // MARK: - 历史关联分析
    
    func analyzeWeatherHeadacheCorrelation(with headacheRecords: [HeadacheRecord]) -> EnhancedWeatherCorrelationResult {
        // 直接调用增强版分析方法
        performEnhancedCorrelationAnalysis(with: headacheRecords)
    }
    
    // 获取明天的天气预测
    func fetchTomorrowWeatherForecast() async -> WeatherRecord? {
        guard isLocationAuthorized, let location = locationManager.location else { return nil }
        
        do {
            let weather = try await weatherService.weather(for: location)
            guard let tomorrowForecast = weather.dailyForecast.first else { return nil }
            
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            
            return WeatherRecord(
                date: tomorrow,
                location: location.coordinate,
                temperature: tomorrowForecast.highTemperature.value,
                humidity: 0, // Daily forecast might not have detailed humidity
                pressure: 0, // Daily forecast might not have detailed pressure
                condition: mapWeatherKitCondition(tomorrowForecast.condition).rawValue,
                uvIndex: tomorrowForecast.uvIndex.value,
                windSpeed: tomorrowForecast.wind.speed.value * 3.6,
                precipitationChance: tomorrowForecast.precipitationChance * 100
            )
        } catch {
            print("❌ 获取明天天气预报失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 数据快照更新
    
    private func updateWeatherDataSnapshot(from record: WeatherRecord) {
        let snapshot = WeatherDataSnapshot(
            date: record.date,
            temperature: record.temperature,
            humidity: record.humidity,
            pressure: record.pressure,
            condition: record.condition,
            uvIndex: record.uvIndex,
            windSpeed: record.windSpeed,
            precipitationChance: record.precipitationChance,
            temperatureChange: record.temperatureChange,
            pressureChange: record.pressureChange,
            riskLevel: currentRisk
        )
        
        weatherDataSnapshot = snapshot
        print("✅ 天气数据快照已更新")
    }
    
    // MARK: - 增强版相关性分析
    
    func performEnhancedCorrelationAnalysis(with headacheRecords: [HeadacheRecord]) -> EnhancedWeatherCorrelationResult {
        var conditionCorrelations: [String: CorrelationData] = [:]
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter.dayFormatter
        
        // 分析天气与头痛的相关性
        for weather in weatherHistory {
            let weatherDateString = dateFormatter.string(from: weather.date)
            let condition = weather.condition
            
            if conditionCorrelations[condition] == nil {
                conditionCorrelations[condition] = CorrelationData()
            }
            
            conditionCorrelations[condition]!.totalDays += 1
            conditionCorrelations[condition]!.temperatures.append(weather.temperature)
            conditionCorrelations[condition]!.pressures.append(weather.pressure)
            conditionCorrelations[condition]!.humidities.append(weather.humidity)
            
            // 检查这一天是否有头痛记录
            let hasHeadache = headacheRecords.contains { record in
                guard let timestamp = record.timestamp else { return false }
                let recordDateString = dateFormatter.string(from: timestamp)
                return recordDateString == weatherDateString
            }
            
            if hasHeadache {
                conditionCorrelations[condition]!.headacheDays += 1
            }
        }
        
        // 生成相关性结果
        let correlations = conditionCorrelations.map { condition, data in
            WeatherConditionCorrelation(
                condition: condition,
                headacheRate: data.totalDays > 0 ? Double(data.headacheDays) / Double(data.totalDays) * 100 : 0,
                totalDays: data.totalDays,
                headacheDays: data.headacheDays,
                averageTemperature: data.temperatures.isEmpty ? 0 : data.temperatures.reduce(0, +) / Double(data.temperatures.count),
                averagePressure: data.pressures.isEmpty ? 0 : data.pressures.reduce(0, +) / Double(data.pressures.count),
                averageHumidity: data.humidities.isEmpty ? 0 : data.humidities.reduce(0, +) / Double(data.humidities.count)
            )
        }.sorted { $0.headacheRate > $1.headacheRate }
        
        let totalWeatherDays = weatherHistory.count
        let totalHeadacheDays = conditionCorrelations.values.reduce(0) { $0 + $1.headacheDays }
        
        // 计算气压和温度变化的相关性
        let pressureCorrelation = calculatePressureChangeCorrelation(headacheRecords: headacheRecords)
        let temperatureCorrelation = calculateTemperatureChangeCorrelation(headacheRecords: headacheRecords)
        
        return EnhancedWeatherCorrelationResult(
            conditions: correlations,
            analysisDate: Date(),
            totalWeatherDays: totalWeatherDays,
            totalHeadacheDays: totalHeadacheDays,
            pressureChangeCorrelation: pressureCorrelation,
            temperatureChangeCorrelation: temperatureCorrelation,
            highRiskFactors: identifyHighRiskFactors(from: correlations)
        )
    }
    
    private func calculatePressureChangeCorrelation(headacheRecords: [HeadacheRecord]) -> Double {
        var pressureChanges: [Double] = []
        var headacheIntensities: [Double] = []
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter.dayFormatter
        
        for record in headacheRecords {
            guard let timestamp = record.timestamp else { continue }
            let recordDateString = dateFormatter.string(from: timestamp)
            
            if let weather = weatherHistory.first(where: { weather in
                dateFormatter.string(from: weather.date) == recordDateString
            }) {
                pressureChanges.append(abs(weather.pressureChange))
                headacheIntensities.append(Double(record.intensity))
            }
        }
        
        return calculateCorrelation(x: pressureChanges, y: headacheIntensities)
    }
    
    private func calculateTemperatureChangeCorrelation(headacheRecords: [HeadacheRecord]) -> Double {
        var temperatureChanges: [Double] = []
        var headacheIntensities: [Double] = []
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter.dayFormatter
        
        for record in headacheRecords {
            guard let timestamp = record.timestamp else { continue }
            let recordDateString = dateFormatter.string(from: timestamp)
            
            if let weather = weatherHistory.first(where: { weather in
                dateFormatter.string(from: weather.date) == recordDateString
            }) {
                temperatureChanges.append(abs(weather.temperatureChange))
                headacheIntensities.append(Double(record.intensity))
            }
        }
        
        return calculateCorrelation(x: temperatureChanges, y: headacheIntensities)
    }
    
    private func calculateCorrelation(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        
        return denominator != 0 ? numerator / denominator : 0
    }
    
    private func identifyHighRiskFactors(from correlations: [WeatherConditionCorrelation]) -> [HighRiskFactor] {
        var riskFactors: [HighRiskFactor] = []
        
        for correlation in correlations {
            if correlation.headacheRate > 60 {
                riskFactors.append(HighRiskFactor(
                    factor: "\(correlation.conditionEnum?.displayName ?? correlation.condition)天气",
                    riskLevel: correlation.headacheRate,
                    description: "在\(correlation.conditionEnum?.displayName ?? correlation.condition)天气下，头痛发生率为\(String(format: "%.1f", correlation.headacheRate))%",
                    recommendation: generateRecommendation(for: correlation)
                ))
            }
        }
        
        return riskFactors
    }
    
    private func generateRecommendation(for correlation: WeatherConditionCorrelation) -> String {
        guard let condition = correlation.conditionEnum else {
            return "关注天气变化，做好预防措施"
        }
        
        switch condition {
        case .stormy, .rainy:
            return "雨天时注意保持室内环境稳定，避免剧烈活动"
        case .cloudy, .foggy:
            return "阴天时可能光线不足，注意补充维生素D"
        case .windy:
            return "大风天气注意保暖，避免长时间户外活动"
        default:
            return "根据天气情况调整作息和活动安排"
        }
    }
}

// MARK: - 数据模型

struct CorrelationData {
    var totalDays = 0
    var headacheDays = 0
    var temperatures: [Double] = []
    var pressures: [Double] = []
    var humidities: [Double] = []
}

struct WeatherConditionCorrelation: Identifiable {
    let id = UUID()
    let condition: String
    let headacheRate: Double
    let totalDays: Int
    let headacheDays: Int
    let averageTemperature: Double
    let averagePressure: Double
    let averageHumidity: Double
    
    var conditionEnum: WeatherCondition? {
        WeatherCondition(rawValue: condition)
    }
}

struct WeatherCorrelationResult {
    let conditions: [WeatherConditionCorrelation]
    let analysisDate: Date
    let totalWeatherDays: Int
    let totalHeadacheDays: Int
    
    var overallHeadacheRate: Double {
        totalWeatherDays > 0 ? Double(totalHeadacheDays) / Double(totalWeatherDays) * 100 : 0
    }
    
    var highestRiskCondition: WeatherConditionCorrelation? {
        conditions.first
    }
}

// MARK: - CLLocationManagerDelegate
extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task {
            await fetchWeather(for: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = "定位失败: \(error.localizedDescription)"
            print("❌ 定位失败: \(error)")
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            print("🔄 位置权限状态变化: \(manager.authorizationStatus.rawValue)")
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationAuthorized = true
                self.errorMessage = nil
                self.requestCurrentLocationWeather()
                print("✅ 位置权限已授权，开始获取天气")
            case .denied, .restricted:
                self.isLocationAuthorized = false
                self.errorMessage = "位置权限被拒绝，请在系统设置中开启"
                print("❌ 位置权限被拒绝")
            case .notDetermined:
                self.isLocationAuthorized = false
                self.errorMessage = nil
                print("⚠️ 位置权限未确定")
            @unknown default:
                break
            }
        }
    }
}

// MARK: - 新增数据结构

struct WeatherDataSnapshot {
    let date: Date
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let condition: String
    let uvIndex: Int
    let windSpeed: Double
    let precipitationChance: Double
    let temperatureChange: Double
    let pressureChange: Double
    let riskLevel: HeadacheRisk
}

struct EnhancedWeatherCorrelationResult {
    let conditions: [WeatherConditionCorrelation]
    let analysisDate: Date
    let totalWeatherDays: Int
    let totalHeadacheDays: Int
    let pressureChangeCorrelation: Double
    let temperatureChangeCorrelation: Double
    let highRiskFactors: [HighRiskFactor]
    
    var overallHeadacheRate: Double {
        totalWeatherDays > 0 ? Double(totalHeadacheDays) / Double(totalWeatherDays) * 100 : 0
    }
    
    var highestRiskCondition: WeatherConditionCorrelation? {
        conditions.first
    }
}

struct HighRiskFactor: Identifiable {
    let id = UUID()
    let factor: String
    let riskLevel: Double
    let description: String
    let recommendation: String
}

// MARK: - 扩展

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}
