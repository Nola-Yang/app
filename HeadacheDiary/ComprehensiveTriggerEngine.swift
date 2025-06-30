import Foundation
import CoreData
import Combine
import HealthKit

// MARK: - 综合触发因素分析引擎
class ComprehensiveTriggerEngine: ObservableObject {
    static let shared = ComprehensiveTriggerEngine()
    
    @Published var comprehensiveAnalysis: ComprehensiveHeadacheAnalysis?
    @Published var menstrualInsights: MenstrualHeadacheInsights?
    @Published var weatherHealthCorrelations: [WeatherHealthCorrelation] = []
    @Published var predictiveAlerts: [PredictiveAlert] = []
    @Published var isAnalyzing = false
    
    private let healthKitManager = HealthKitManager.shared
    @MainActor
    private lazy var weatherService = WeatherService.shared
    private let healthAnalysisEngine = HealthAnalysisEngine.shared
    @MainActor
    private lazy var weatherWarningManager = WeatherWarningManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // 监听健康数据更新
        healthKitManager.$healthDataSnapshot
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task {
                    await self?.performComprehensiveAnalysis()
                }
            }
            .store(in: &cancellables)
        
        // 监听天气数据更新
        Task { @MainActor in
            weatherService.$weatherDataSnapshot
                .compactMap { $0 }
                .sink { [weak self] _ in
                    Task {
                        await self?.performComprehensiveAnalysis()
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - 综合分析主方法
    
    func performComprehensiveAnalysis() async {
        await MainActor.run { self.isAnalyzing = true }
        
        // Ensure we always reset the loading state, even if an error occurs
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }

        do {
            guard let context = PersistenceController.shared.container.viewContext as CoreData.NSManagedObjectContext? else {
                print("❌ 无法获取CoreData上下文")
                return
            }

            let records = await fetchHeadacheRecords(from: context)
            print("📊 正在分析 \(records.count) 条头痛记录")
            
            // 即使数据较少也进行分析，但提供适当的提示
            _ = records.count < 3 ? "数据收集阶段" : records.count < 10 ? "初步分析" : "详细分析"
            _ = records.count < 3 ? "（数据有限，结果仅供参考）" : records.count < 10 ? "（基础分析）" : ""

            

            // Perform analysis with real data
            let healthCorrelations = await healthAnalysisEngine.analyzeHealthCorrelations(records: records)
            let weatherCorrelations = await MainActor.run {
                weatherService.analyzeWeatherHeadacheCorrelation(with: records)
            }

            let combinedCorrelations = combineCorrelations(health: healthCorrelations, weather: weatherCorrelations)

            let triggerCombinations = await identifyTriggerCombinations(records: records, healthCorrelations: healthCorrelations, weatherCorrelations: weatherCorrelations)
            let predictiveModel = await buildPredictiveModel(records: records, combinedCorrelations: combinedCorrelations)

            let comprehensiveAnalysis = ComprehensiveHeadacheAnalysis(
                totalRecords: records.count,
                analysisDate: Date(),
                menstrualCorrelation: healthCorrelations.first(where: { $0.healthMetric == "月经周期" })?.correlation ?? 0,
                weatherHealthCorrelations: combinedCorrelations,
                primaryTriggerCombinations: triggerCombinations,
                riskPrediction: predictiveModel,
                personalizedInsights: generatePersonalizedInsights(from: (menstrual: healthCorrelations, weatherHealth: combinedCorrelations, triggers: triggerCombinations, prediction: predictiveModel))
            )

            await MainActor.run {
                self.comprehensiveAnalysis = comprehensiveAnalysis
                self.predictiveAlerts = generatePredictiveAlerts(from: predictiveModel)
                print("✅ 综合触发因素分析完成")

                Task {
                    await self.sendPredictiveNotifications()
                }
            }
        }
    }
    
    
    
    private func combineCorrelations(health: [HealthCorrelationResult], weather: EnhancedWeatherCorrelationResult?) -> [WeatherHealthCorrelation] {
        var combined: [WeatherHealthCorrelation] = []

        // This is a simplified combination logic. A more sophisticated approach would be needed for a real app.
        if let weatherCorrelations = weather {
            for weatherCorrelation in weatherCorrelations.conditions {
                for healthCorrelation in health {
                    let combinedCorrelation = (weatherCorrelation.headacheRate + healthCorrelation.correlation) / 2
                    combined.append(WeatherHealthCorrelation(weatherFactor: weatherCorrelation.condition, healthMetric: healthCorrelation.healthMetric, weatherCorrelation: weatherCorrelation.headacheRate, healthCorrelation: healthCorrelation.correlation, combinedCorrelation: combinedCorrelation, significanceLevel: 0.05, insights: "Combined insight"))
                }
            }
        }

        return combined
    }

    // MARK: - 触发因素组合识别
    
    private func identifyTriggerCombinations(records: [HeadacheRecord], healthCorrelations: [HealthCorrelationResult], weatherCorrelations: EnhancedWeatherCorrelationResult?) async -> [TriggerCombination] {
        var combinations: [String: TriggerCombinationData] = [:]

        for record in records {
            guard let timestamp = record.timestamp else { continue }

            var triggerFactors: [String] = []

            // Health Factors
            for correlation in healthCorrelations {
                if correlation.isSignificant && correlation.correlation > 0.5 {
                    triggerFactors.append(correlation.healthMetric)
                }
            }

            // Weather Factors
            if let weather = weatherCorrelations {
                for condition in weather.conditions {
                    if condition.headacheRate > 0.5 {
                        triggerFactors.append(condition.condition)
                    }
                }
            }

            let combinationKey = triggerFactors.sorted().joined(separator: " + ")
            if !combinationKey.isEmpty {
                if combinations[combinationKey] == nil {
                    combinations[combinationKey] = TriggerCombinationData(factors: triggerFactors, occurrences: 0, totalIntensity: 0, dates: [])
                }
                combinations[combinationKey]?.occurrences += 1
                combinations[combinationKey]?.totalIntensity += Double(record.intensity)
                combinations[combinationKey]?.dates.append(timestamp)
            }
        }

        return combinations.map { key, data in
            TriggerCombination(
                combinationKey: key,
                factors: data.factors,
                frequency: data.occurrences,
                averageIntensity: data.totalIntensity / Double(data.occurrences),
                riskScore: calculateCombinationRiskScore(data: data),
                lastOccurrence: data.dates.max() ?? Date()
            )
        }.sorted { $0.riskScore > $1.riskScore }
    }
    
    // MARK: - 预测模型构建
    
    private func buildPredictiveModel(records: [HeadacheRecord], combinedCorrelations: [WeatherHealthCorrelation]) async -> PredictiveModel {
        let weights = calculateWeights(correlations: combinedCorrelations)
        let riskForecast = await generateRiskForecast(records: records, weights: weights)

        return PredictiveModel(
            menstrualWeight: weights.menstrual,
            weatherWeight: weights.weather,
            healthWeight: weights.health,
            timePatternWeight: weights.time,
            riskForecast: riskForecast
        )
    }
    
    // MARK: - 个性化洞察生成
    
    private func generatePersonalizedInsights(from results: (
        menstrual: [HealthCorrelationResult],
        weatherHealth: [WeatherHealthCorrelation],
        triggers: [TriggerCombination],
        prediction: PredictiveModel
    )) -> [PersonalizedInsight] {
        var insights: [PersonalizedInsight] = []

        // Menstrual-related insights with focus on pre-menstrual phase
        if let menstrualCorrelation = results.menstrual.first(where: { $0.healthMetric == "月经周期" }), menstrualCorrelation.correlation > 0.6 {
            insights.append(PersonalizedInsight(
                category: .menstrual,
                title: "月经周期是主要触发因素",
                description: "您的头痛与月经周期高度相关（相关性：\(String(format: "%.2f", menstrualCorrelation.correlation))）。数据显示月经前两天是高风险期。",
                recommendations: [
                    "🔴 重点关注：月经前两天开始预防措施",
                    "在月经前3-4天就开始预防性治疗",
                    "月经前两天避免压力、充足睡眠",
                    "监测雌激素和孕激素水平变化",
                    "考虑补充镁元素和维生素B2",
                    "设置月经前两天的特殊提醒"
                ],
                priority: .high
            ))
        } else if let menstrualCorrelation = results.menstrual.first(where: { $0.healthMetric == "月经周期" }), menstrualCorrelation.correlation > 0.3 {
            insights.append(PersonalizedInsight(
                category: .menstrual,
                title: "月经周期存在一定关联",
                description: "您的头痛与月经周期存在中等程度关联（相关性：\(String(format: "%.2f", menstrualCorrelation.correlation))）。建议重点观察月经前两天。",
                recommendations: [
                    "记录月经前两天的头痛模式",
                    "注意月经前期的生活方式调整",
                    "继续收集数据以确认关联性"
                ],
                priority: .medium
            ))
        }

        // Combined weather and health insights
        for correlation in results.weatherHealth.prefix(2) {
            if correlation.combinedCorrelation > 0.5 {
                insights.append(PersonalizedInsight(
                    category: .environmental,
                    title: "\(correlation.weatherFactor)与\(correlation.healthMetric)的复合影响",
                    description: correlation.insights,
                    recommendations: generateRecommendationsFor(correlation: correlation),
                    priority: correlation.combinedCorrelation > 0.7 ? .high : .medium
                ))
            }
        }

        // Trigger combination insights
        for combination in results.triggers.prefix(3) {
            if combination.riskScore > 0.7 {
                insights.append(PersonalizedInsight(
                    category: .combinedTriggers,
                    title: "高风险触发因素组合",
                    description: "当\(combination.combinationKey)同时出现时，头痛风险显著增加（风险评分：\(String(format: "%.2f", combination.riskScore))）",
                    recommendations: [
                        "当预测到这些因素同时出现时，提前服用预防药物",
                        "加强相关因素的监测和管理",
                        "准备应急处理方案"
                    ],
                    priority: .high
                ))
            }
        }

        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - 预测预警生成
    
    private func generatePredictiveAlerts(from model: PredictiveModel) -> [PredictiveAlert] {
        var alerts: [PredictiveAlert] = []
        
        for (index, dailyRisk) in model.riskForecast.enumerated() {
            let alertDate = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
            
            if dailyRisk.riskScore > 0.7 {
                alerts.append(PredictiveAlert(
                    date: alertDate,
                    riskLevel: .high,
                    riskScore: dailyRisk.riskScore,
                    primaryTriggers: dailyRisk.predictedTriggers,
                    message: "高风险：\(dailyRisk.predictedTriggers.joined(separator: "、"))可能引发头痛",
                    recommendations: generateAlertRecommendations(for: dailyRisk)
                ))
            } else if dailyRisk.riskScore > 0.5 {
                alerts.append(PredictiveAlert(
                    date: alertDate,
                    riskLevel: .medium,
                    riskScore: dailyRisk.riskScore,
                    primaryTriggers: dailyRisk.predictedTriggers,
                    message: "中等风险：注意\(dailyRisk.predictedTriggers.joined(separator: "、"))",
                    recommendations: generateAlertRecommendations(for: dailyRisk)
                ))
            }
        }
        
        return alerts
    }
    
    // MARK: - 辅助方法
    
    private func fetchHeadacheRecords(from context: NSManagedObjectContext) async -> [HeadacheRecord] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)]
                request.fetchLimit = 500
                
                do {
                    let records = try context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    print("❌ 获取头痛记录失败: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func calculateMenstrualCycleDay(for date: Date) -> Int {
        // 基于日期计算模拟的月经周期天数
        let daysSinceReference = Calendar.current.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: date).day ?? 0
        return (daysSinceReference % 28) + 1
    }
    
    private func generateMockWeatherValue(for factor: String, date: Date) -> Double {
        // 生成模拟的天气数据
        let baseSeed = date.timeIntervalSince1970 / 86400
        let seed = Int(baseSeed) % 100
        
        switch factor {
        case "气压变化":
            return Double(seed % 10) + Double.random(in: -2...2)
        case "湿度":
            return Double(30 + seed % 40) + Double.random(in: -5...5)
        case "温度变化":
            return Double(seed % 20) + Double.random(in: -3...3)
        default:
            return Double.random(in: 0...10)
        }
    }
    
    private func generateMockHealthValue(for metric: String, date: Date) -> Double {
        // 生成模拟的健康数据
        let baseSeed = date.timeIntervalSince1970 / 86400
        let seed = Int(baseSeed) % 100
        
        switch metric {
        case "睡眠质量":
            return Double(5 + seed % 5) + Double.random(in: -1...1)
        case "压力水平":
            return Double(3 + seed % 7) + Double.random(in: -1...1)
        case "HRV":
            return Double(30 + seed % 30) + Double.random(in: -5...5)
        default:
            return Double.random(in: 1...10)
        }
    }
    
    private func calculatePearsonCorrelation(x: [Double], y: [Double]) -> Double {
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
    
    // 其他辅助方法的实现...
    private func analyzePhaseTriggers(cyclePatterns: [Int: [HeadachePattern]], days: ClosedRange<Int>, phaseName: String) -> PhasePattern {
        var totalIntensity: Double = 0
        var count = 0
        var commonTriggers: [String: Int] = [:]
        
        for day in days {
            if let patterns = cyclePatterns[day] {
                for pattern in patterns {
                    totalIntensity += pattern.intensity
                    count += 1
                    for trigger in pattern.triggers {
                        commonTriggers[trigger, default: 0] += 1
                    }
                }
            }
        }
        
        return PhasePattern(
            phaseName: phaseName,
            averageIntensity: count > 0 ? totalIntensity / Double(count) : 0,
            frequency: count,
            commonTriggers: Array(commonTriggers.keys).sorted { commonTriggers[$0]! > commonTriggers[$1]! }
        )
    }
    
    private func calculateHormonalCorrelation(cyclePatterns: [Int: [HeadachePattern]]) -> Double {
        // 重点关注月经前两天的激素相关性计算
        let preOnsetDays = Array(26...28)  // 月经前2-4天
        let criticalPreDays = Array(27...28)  // 月经前两天（重点关注）
        let menstrualDays = Array(1...5)
        let otherDays = Array(6...25)
        
        let preOnsetIntensity = calculateAverageIntensity(cyclePatterns: cyclePatterns, days: preOnsetDays)
        let criticalPreIntensity = calculateAverageIntensity(cyclePatterns: cyclePatterns, days: criticalPreDays)
        let menstrualIntensity = calculateAverageIntensity(cyclePatterns: cyclePatterns, days: menstrualDays)
        let otherDaysIntensity = calculateAverageIntensity(cyclePatterns: cyclePatterns, days: otherDays)
        
        // 计算月经前两天的特殊权重
        let criticalPreWeight = 2.0  // 月经前两天权重加倍
        let weightedCriticalIntensity = criticalPreIntensity * criticalPreWeight
        
        // 综合计算激素相关性，重点考虑月经前两天
        let maxHormonalIntensity = max(weightedCriticalIntensity, preOnsetIntensity, menstrualIntensity)
        
        if otherDaysIntensity > 0 {
            let baseCorrelation = (maxHormonalIntensity - otherDaysIntensity) / otherDaysIntensity
            
            // 如果月经前两天有显著头痛，额外增加相关性分数
            if criticalPreIntensity > otherDaysIntensity * 1.5 {
                return min(baseCorrelation + 0.3, 1.0)  // 最大不超过1.0
            }
            
            return baseCorrelation
        }
        
        return 0
    }
    
    private func calculateAverageIntensity(cyclePatterns: [Int: [HeadachePattern]], days: [Int]) -> Double {
        var totalIntensity: Double = 0
        var count = 0
        
        for day in days {
            if let patterns = cyclePatterns[day] {
                for pattern in patterns {
                    totalIntensity += pattern.intensity
                    count += 1
                }
            }
        }
        
        return count > 0 ? totalIntensity / Double(count) : 0
    }
    
    private func extractTriggers(from record: HeadacheRecord) -> [String] {
        // 从记录中提取触发因素
        var triggers: [String] = []
        
        if let note = record.note {
            if note.contains("压力") { triggers.append("压力") }
            if note.contains("睡眠") { triggers.append("睡眠问题") }
            if note.contains("天气") { triggers.append("天气变化") }
            if note.contains("月经") { triggers.append("月经相关") }
        }
        
        return triggers
    }
    
    // 其他必要的辅助方法实现...
    private func calculateCyclePredictability(patterns: [Int: [HeadachePattern]]) -> Double {
        // 计算周期可预测性
        return 0.75 // 简化实现
    }
    
    private func generateMenstrualPreventions(correlation: Double) -> [String] {
        var preventions: [String] = []
        
        if correlation > 0.6 {
            preventions.append("在经前1周开始预防性用药")
            preventions.append("补充镁元素和维生素B2")
            preventions.append("保持规律作息，减少压力")
            preventions.append("记录激素水平变化")
        }
        
        return preventions
    }
    
    private func calculateSignificance(correlation: Double, sampleSize: Int) -> Double {
        // 简化的显著性计算
        if abs(correlation) > 0.7 && sampleSize > 20 {
            return 0.01
        } else if abs(correlation) > 0.5 && sampleSize > 15 {
            return 0.05
        } else {
            return 0.1
        }
    }
    
    private func generateWeatherHealthInsights(weatherFactor: String, healthMetric: String, correlation: Double) -> String {
        if correlation > 0.5 {
            return "\(weatherFactor)变化显著影响\(healthMetric)，进而增加头痛风险"
        } else if correlation < -0.5 {
            return "\(weatherFactor)的改善有助于\(healthMetric)稳定，降低头痛发生率"
        } else {
            return "\(weatherFactor)与\(healthMetric)的关联较弱"
        }
    }
    
    private func calculateCombinationRiskScore(data: TriggerCombinationData) -> Double {
        let frequencyScore = min(Double(data.occurrences) / 10.0, 1.0)
        let intensityScore = (data.totalIntensity / Double(data.occurrences)) / 10.0
        return (frequencyScore + intensityScore) / 2.0
    }
    
    private func calculateWeights(correlations: [WeatherHealthCorrelation]) -> (menstrual: Double, weather: Double, health: Double, time: Double) {
        // Simplified weight calculation based on correlation strength
        let totalCorrelation = correlations.reduce(0) { $0 + abs($1.combinedCorrelation) }
        guard totalCorrelation > 0 else { return (0.25, 0.25, 0.25, 0.25) }

        let menstrualWeight = correlations.filter { $0.healthMetric == "月经周期" }.reduce(0) { $0 + abs($1.combinedCorrelation) } / totalCorrelation
        let weatherWeight = correlations.filter { $0.weatherFactor != "" }.reduce(0) { $0 + abs($1.combinedCorrelation) } / totalCorrelation
        let healthWeight = correlations.filter { $0.healthMetric != "" && $0.healthMetric != "月经周期" }.reduce(0) { $0 + abs($1.combinedCorrelation) } / totalCorrelation
        
        return (menstrualWeight, weatherWeight, healthWeight, 1.0 - menstrualWeight - weatherWeight - healthWeight)
    }

    @MainActor
    private func generateRiskForecast(records: [HeadacheRecord], weights: (menstrual: Double, weather: Double, health: Double, time: Double)) -> [DailyRiskForecast] {
        var forecast: [DailyRiskForecast] = []

        for i in 0..<7 {
            let forecastDate = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
            var riskScore: Double = 0.3 // Base risk
            var triggers: [String] = []

            // Enhanced forecast logic with focus on pre-menstrual days
            if let snapshot = healthKitManager.healthDataSnapshot {
                if let cycleDay = snapshot.cycleDay {
                    // 重点关注月经前两天(周期第27-28天)
                    if cycleDay >= 27 && cycleDay <= 28 {
                        riskScore += 0.6 * weights.menstrual  // 月经前两天风险权重更高
                        triggers.append("月经前两天高风险期")
                    } else if cycleDay >= 25 && cycleDay <= 26 {
                        riskScore += 0.4 * weights.menstrual  // 月经前3-4天中等风险
                        triggers.append("月经前期")
                    } else if cycleDay >= 1 && cycleDay <= 5 {
                        riskScore += 0.3 * weights.menstrual  // 月经期风险
                        triggers.append("月经期")
                    }
                }
            }

            if let weather = weatherService.currentWeather {
                let weatherRisk = weather.pressureChange / 10.0 // Simplified
                riskScore += weatherRisk * weights.weather
                if weatherRisk > 0.5 {
                    triggers.append("气压变化")
                }
            }

            forecast.append(DailyRiskForecast(
                date: forecastDate,
                riskScore: min(riskScore, 1.0),
                predictedTriggers: triggers,
                confidence: 0.7
            ))
        }

        return forecast
    }
    
    private func generateRecommendationsFor(correlation: WeatherHealthCorrelation) -> [String] {
        var recommendations: [String] = []
        
        if correlation.weatherFactor == "气压变化" {
            recommendations.append("关注天气预报，气压变化前准备止痛药")
            recommendations.append("使用气压监测应用")
        }
        
        if correlation.healthMetric == "睡眠质量" {
            recommendations.append("保持规律睡眠时间")
            recommendations.append("改善睡眠环境")
        }
        
        return recommendations
    }
    
    private func generateAlertRecommendations(for forecast: DailyRiskForecast) -> [String] {
        var recommendations: [String] = []
        
        if forecast.predictedTriggers.contains("月经前两天高风险期") {
            recommendations.append("🔴 重点预防：现在是月经前两天高风险期")
            recommendations.append("立即开始预防性用药")
            recommendations.append("避免所有已知触发因素")
            recommendations.append("保持充足睡眠，减少压力")
            recommendations.append("准备止痛药和应急措施")
        } else if forecast.predictedTriggers.contains("月经前期") {
            recommendations.append("月经前期预防措施")
            recommendations.append("考虑预防性用药")
            recommendations.append("减少压力和负荷")
        } else if forecast.predictedTriggers.contains("激素波动期") {
            recommendations.append("考虑预防性用药")
            recommendations.append("减少压力和负荷")
        }
        
        if forecast.predictedTriggers.contains("气压变化") {
            recommendations.append("避免剧烈运动")
            recommendations.append("保持室内环境稳定")
        }
        
        return recommendations
    }
    
    // MARK: - 预测通知发送
    
    private func sendPredictiveNotifications() async {
        // 只发送最高风险的预警通知
        let highRiskAlerts = predictiveAlerts.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
        
        for alert in highRiskAlerts.prefix(2) { // 最多发送2个高风险预警
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "zh_CN")
            
            let title = "头痛风险预警"
            let body = "\(formatter.string(from: alert.date)): \(alert.message)"
            
            // 使用NotificationManager发送预警通知
            await NotificationManager.shared.sendPredictiveAlert(
                title: title,
                body: body,
                alertDate: alert.date,
                riskLevel: alert.riskLevel.rawValue
            )
        }
        
        // 集成天气预警
        await MainActor.run {
            Task {
                await weatherWarningManager.checkAndSendWarnings()
            }
        }
    }
}

// MARK: - 数据结构定义

struct ComprehensiveHeadacheAnalysis {
    let totalRecords: Int
    let analysisDate: Date
    let menstrualCorrelation: Double
    let weatherHealthCorrelations: [WeatherHealthCorrelation]
    let primaryTriggerCombinations: [TriggerCombination]
    let riskPrediction: PredictiveModel
    let personalizedInsights: [PersonalizedInsight]
}

struct MenstrualHeadacheInsights {
    let correlation: Double
    let preMenstrualPatterns: PhasePattern
    let menstrualPatterns: PhasePattern
    let ovulationPatterns: PhasePattern
    let cyclePredictability: Double
    let recommendedPreventions: [String]
}

struct PhasePattern {
    let phaseName: String
    let averageIntensity: Double
    let frequency: Int
    let commonTriggers: [String]
}

struct HeadachePattern {
    let date: Date
    let intensity: Double
    let duration: TimeInterval
    let triggers: [String]
}

struct WeatherHealthCorrelation {
    let weatherFactor: String
    let healthMetric: String
    let weatherCorrelation: Double
    let healthCorrelation: Double
    let combinedCorrelation: Double
    let significanceLevel: Double
    let insights: String
}

struct TriggerCombination {
    let combinationKey: String
    let factors: [String]
    let frequency: Int
    let averageIntensity: Double
    let riskScore: Double
    let lastOccurrence: Date
}

struct TriggerCombinationData {
    let factors: [String]
    var occurrences: Int
    var totalIntensity: Double
    var dates: [Date]
}

struct PredictiveModel {
    let menstrualWeight: Double
    let weatherWeight: Double
    let healthWeight: Double
    let timePatternWeight: Double
    let riskForecast: [DailyRiskForecast]
    
    init(menstrualWeight: Double, weatherWeight: Double, healthWeight: Double, timePatternWeight: Double, riskForecast: [DailyRiskForecast]) {
        self.menstrualWeight = menstrualWeight
        self.weatherWeight = weatherWeight
        self.healthWeight = healthWeight
        self.timePatternWeight = timePatternWeight
        self.riskForecast = riskForecast
    }
}

struct DailyRiskForecast {
    let date: Date
    let riskScore: Double
    let predictedTriggers: [String]
    let confidence: Double
}

struct PersonalizedInsight {
    let category: InsightCategory
    let title: String
    let description: String
    let recommendations: [String]
    let priority: InsightPriority
}

enum InsightCategory {
    case menstrual, environmental, combinedTriggers, lifestyle
}

enum InsightPriority: Int {
    case low = 1, medium = 2, high = 3
}

struct PredictiveAlert: Identifiable {
    let id = UUID()
    let date: Date
    let riskLevel: AlertRiskLevel
    let riskScore: Double
    let primaryTriggers: [String]
    let message: String
    let recommendations: [String]
}

enum AlertRiskLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中等风险"
        case .high: return "高风险"
        case .critical: return "极高风险"
        }
    }
}
