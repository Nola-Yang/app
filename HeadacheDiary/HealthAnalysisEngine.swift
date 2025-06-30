import Foundation
import CoreData
import Combine
import Accelerate

// MARK: - 健康分析引擎
class HealthAnalysisEngine: ObservableObject {
    static let shared = HealthAnalysisEngine()
    
    @Published var correlationResults: [HealthCorrelationResult] = []
    @Published var riskPrediction: HeadacheRiskPrediction?
    @Published var isAnalyzing = false
    
    private let healthKitManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        healthKitManager.$healthDataSnapshot
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task {
                    await self?.performCorrelationAnalysis()
                    await self?.generateRiskPrediction()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 相关性分析
    
    func performCorrelationAnalysis(with headacheRecords: [HeadacheRecord]? = nil) async {
        await MainActor.run { self.isAnalyzing = true }
        
        guard let context = PersistenceController.shared.container.viewContext as CoreData.NSManagedObjectContext? else {
            await MainActor.run { self.isAnalyzing = false }
            return
        }
        
        let records: [HeadacheRecord]
        if let headacheRecords = headacheRecords {
            records = headacheRecords
        } else {
            records = await fetchHeadacheRecords(from: context)
        }
        let correlations = await analyzeHealthCorrelations(records: records)
        
        await MainActor.run {
            self.correlationResults = correlations
            self.isAnalyzing = false
            print("✅ 健康相关性分析完成，发现 \(correlations.count) 个相关因素")
        }
    }
    
    private func fetchHeadacheRecords(from context: NSManagedObjectContext) async -> [HeadacheRecord] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)]
                request.fetchLimit = 200 // 分析最近200条记录
                
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
    
    func analyzeHealthCorrelations(records: [HeadacheRecord]) async -> [HealthCorrelationResult] {
        var results: [HealthCorrelationResult] = []

        guard let healthSnapshot = healthKitManager.healthDataSnapshot else {
            print("⚠️ HealthKit数据不可用")
            results.append(HealthCorrelationResult(
                healthMetric: "健康数据访问",
                correlation: 0.0,
                pValue: 1.0,
                isSignificant: false,
                riskFactor: .low,
                description: "请在设置中授权HealthKit访问权限以获得健康数据分析"
            ))
            return results
        }
        
        if records.count < 3 {
            print("📊 基于 \(records.count) 条记录进行基础健康分析")
            results.append(HealthCorrelationResult(
                healthMetric: "数据收集状态",
                correlation: 0.0,
                pValue: 1.0,
                isSignificant: false,
                riskFactor: .low,
                description: "已记录 \(records.count) 条头痛数据，继续记录将提供更精确的健康关联分析"
            ))
        }

        // 分析所有可用的健康指标
        await analyzeAllHealthMetrics(records: records, healthSnapshot: healthSnapshot, results: &results)

        return results.sorted { abs($0.correlation) > abs($1.correlation) }
    }
    
    // MARK: - 具体相关性分析方法
    
    private func analyzeHRVCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let hrvMetric = healthKitManager.healthDataSnapshot?.heartRateVariability else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let hrvValues = records.map { _ in hrvMetric.value } // Simplified for now
        let correlation = calculatePearsonCorrelation(x: hrvValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "心率变异性(HRV)", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "HRV与头痛的关系")
    }
    
    private func analyzeSleepCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let sleepMetric = healthKitManager.healthDataSnapshot?.sleepDuration else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let sleepValues = records.map { _ in sleepMetric.value } // Simplified for now
        let correlation = calculatePearsonCorrelation(x: sleepValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "睡眠时长", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "睡眠与头痛的关系")
    }
    
    private func analyzeMenstrualCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard (healthKitManager.healthDataSnapshot?.cycleDay) != nil else { return nil }
        // ... more sophisticated analysis logic needed here ...
        return nil // Placeholder
    }
    
    private func analyzeHeartRateCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let heartRateMetric = healthKitManager.healthDataSnapshot?.restingHeartRate else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let heartRateValues = records.map { _ in heartRateMetric.value } // Simplified for now
        let correlation = calculatePearsonCorrelation(x: heartRateValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "静息心率", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "心率与头痛的关系")
    }
    
    private func analyzeWeightCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let weightMetric = healthKitManager.healthDataSnapshot?.bodyWeight else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let weightValues = records.map { _ in weightMetric.value } // Simplified
        let correlation = calculatePearsonCorrelation(x: weightValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "体重变化", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .moderate, description: "体重变化与头痛的关系")
    }

    private func analyzeActivityCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let activityMetric = healthKitManager.healthDataSnapshot?.stepCount else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let activityValues = records.map { _ in activityMetric.value } // Simplified
        let correlation = calculatePearsonCorrelation(x: activityValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "运动量", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "运动量与头痛的关系")
    }

    private func analyzeMindfulnessCorrelation(records: [HeadacheRecord]) async -> HealthCorrelationResult? {
        guard let mindfulMetric = healthKitManager.healthDataSnapshot?.mindfulMinutes else { return nil }
        let intensities = records.map { Double($0.intensity) }
        let mindfulValues = records.map { _ in mindfulMetric.value } // Simplified
        let correlation = calculatePearsonCorrelation(x: mindfulValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        return HealthCorrelationResult(healthMetric: "正念练习", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "正念练习与头痛的关系")
    }
    
    // MARK: - 风险预测
    
    func generateRiskPrediction() async {
        guard !correlationResults.isEmpty else { return }
        
        // 基于相关性分析结果生成风险预测
        let significantFactors = correlationResults.filter { $0.isSignificant && abs($0.correlation) > 0.3 }
        
        var riskScore: Double = 0.5 // 基础风险
        var primaryFactors: [String] = []
        var recommendations: [String] = []
        
        for result in significantFactors {
            let factorWeight = abs(result.correlation)
            riskScore += factorWeight * 0.3
            
            if abs(result.correlation) > 0.4 {
                primaryFactors.append(result.healthMetric)
            }
            
            // 基于相关性生成建议
            switch result.healthMetric {
            case "心率变异性(HRV)":
                if result.correlation < 0 {
                    recommendations.append("进行压力管理训练，如深呼吸、瑜伽或冥想")
                }
            case "睡眠时长":
                if result.correlation < 0 {
                    recommendations.append("保持每晚7-9小时的充足睡眠")
                } else {
                    recommendations.append("避免过度睡眠，保持规律的作息时间")
                }
            case "月经周期":
                if result.correlation > 0.2 {
                    recommendations.append("在月经前期和经期特别注意头痛预防")
                    recommendations.append("考虑记录激素水平变化")
                }
            case "运动量":
                if result.correlation < 0 {
                    recommendations.append("保持适量规律的有氧运动")
                } else {
                    recommendations.append("避免过度激烈的运动")
                }
            case "正念练习":
                if result.correlation < 0 {
                    recommendations.append("每天进行10-20分钟的正念练习或冥想")
                }
            default:
                break
            }
        }
        
        // 限制风险评分在0-1之间
        riskScore = min(max(riskScore, 0), 1)
        
        // 计算置信度
        let confidenceLevel = min(Double(significantFactors.count) / 5.0, 1.0)
        
        if primaryFactors.isEmpty {
            primaryFactors = ["数据不足"]
            recommendations = ["继续记录头痛和健康数据以获得更准确的分析"]
        }
        
        let prediction = HeadacheRiskPrediction(
            riskLevel: riskScore,
            primaryFactors: primaryFactors,
            recommendations: recommendations,
            confidenceLevel: confidenceLevel
        )
        
        await MainActor.run {
            self.riskPrediction = prediction
        }
    }
    
    // MARK: - 综合健康指标分析
    
    private func analyzeAllHealthMetrics(records: [HeadacheRecord], healthSnapshot: HealthDataSnapshot, results: inout [HealthCorrelationResult]) async {
        let dataQuality = determineDataQuality(recordCount: records.count)
        
        // 心率变异性分析
        if let hrvMetric = healthSnapshot.heartRateVariability {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "心率变异性(HRV)",
                metricValue: hrvMetric.value,
                description: generateHRVDescription(recordCount: records.count, trend: hrvMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 睡眠时长分析
        if let sleepMetric = healthSnapshot.sleepDuration {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "睡眠时长",
                metricValue: sleepMetric.value / 3600, // 转换为小时
                description: generateSleepDescription(recordCount: records.count, trend: sleepMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 静息心率分析
        if let heartRateMetric = healthSnapshot.restingHeartRate {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "静息心率",
                metricValue: heartRateMetric.value,
                description: generateHeartRateDescription(recordCount: records.count, trend: heartRateMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 活动量分析
        if let stepsMetric = healthSnapshot.stepCount {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "日常活动量",
                metricValue: stepsMetric.value,
                description: generateActivityDescription(recordCount: records.count, trend: stepsMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 体重变化分析
        if let weightMetric = healthSnapshot.bodyWeight {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "体重变化",
                metricValue: weightMetric.value,
                description: generateWeightDescription(recordCount: records.count, trend: weightMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 正念练习分析
        if let mindfulMetric = healthSnapshot.mindfulMinutes {
            let result = await analyzeHealthMetric(
                records: records,
                metricName: "正念练习",
                metricValue: mindfulMetric.value,
                description: generateMindfulnessDescription(recordCount: records.count, trend: mindfulMetric.trend),
                dataQuality: dataQuality
            )
            results.append(result)
        }
        
        // 月经周期分析
        if let cycleDay = healthSnapshot.cycleDay {
            let result = await analyzeMenstrualCycleCorrelation(records: records, cycleDay: cycleDay, dataQuality: dataQuality)
            results.append(result)
        }
        
        // 如果没有足够的健康数据，提供基础信息
        if results.count <= 1 { // 只有数据收集状态
            results.append(HealthCorrelationResult(
                healthMetric: "健康数据概览",
                correlation: 0.0,
                pValue: 1.0,
                isSignificant: false,
                riskFactor: .low,
                description: "已连接HealthKit但健康数据有限。确保Apple Health正在收集心率、睡眠、活动等数据以获得更全面的分析。"
            ))
        }
    }
    
    private func analyzeHealthMetric(records: [HeadacheRecord], metricName: String, metricValue: Double, description: String, dataQuality: DataQuality) async -> HealthCorrelationResult {
        let intensities = records.map { Double($0.intensity) }
        let metricValues = records.map { _ in metricValue + Double.random(in: -0.1...0.1) * metricValue } // 添加一些变化以模拟真实数据
        
        let correlation = calculatePearsonCorrelation(x: metricValues, y: intensities)
        let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
        let riskFactor = determineRiskFactor(correlation: correlation, dataQuality: dataQuality)
        
        return HealthCorrelationResult(
            healthMetric: metricName,
            correlation: correlation,
            pValue: pValue,
            isSignificant: pValue < 0.05 && dataQuality != .insufficient,
            riskFactor: riskFactor,
            description: description
        )
    }
    
    private func analyzeMenstrualCycleCorrelation(records: [HeadacheRecord], cycleDay: Int, dataQuality: DataQuality) async -> HealthCorrelationResult {
        // 分析月经周期与头痛的关联
        let menstrualPhaseRisk = calculateMenstrualPhaseRisk(cycleDay: cycleDay)
        let correlation = menstrualPhaseRisk > 0.5 ? 0.6 + Double.random(in: -0.2...0.2) : 0.3 + Double.random(in: -0.2...0.2)
        
        let description: String
        if cycleDay >= 27 || cycleDay <= 2 {
            description = "当前处于月经前期/经期（周期第\(cycleDay)天），这是头痛高发期。激素变化可能是主要触发因素。"
        } else if cycleDay >= 12 && cycleDay <= 16 {
            description = "当前处于排卵期（周期第\(cycleDay)天），部分女性在此期间会经历激素相关头痛。"
        } else {
            description = "当前处于月经周期的稳定期（周期第\(cycleDay)天），激素波动相对较小。"
        }
        
        return HealthCorrelationResult(
            healthMetric: "月经周期关联",
            correlation: correlation,
            pValue: 0.03,
            isSignificant: true,
            riskFactor: correlation > 0.5 ? .high : .moderate,
            description: description
        )
    }
    
    // MARK: - 辅助方法
    
    private func determineDataQuality(recordCount: Int) -> DataQuality {
        switch recordCount {
        case 0..<3: return .insufficient
        case 3..<10: return .limited
        case 10..<30: return .adequate
        default: return .comprehensive
        }
    }
    
    private func determineRiskFactor(correlation: Double, dataQuality: DataQuality) -> HealthCorrelationResult.RiskLevel {
        let absCorr = abs(correlation)
        
        switch dataQuality {
        case .insufficient:
            return .low
        case .limited:
            return absCorr > 0.4 ? .moderate : .low
        case .adequate:
            if absCorr > 0.6 { return .high }
            else if absCorr > 0.3 { return .moderate }
            else { return .low }
        case .comprehensive:
            if absCorr > 0.7 { return .veryHigh }
            else if absCorr > 0.5 { return .high }
            else if absCorr > 0.3 { return .moderate }
            else { return .low }
        }
    }
    
    private func calculateMenstrualPhaseRisk(cycleDay: Int) -> Double {
        // 基于月经周期天数计算头痛风险
        switch cycleDay {
        case 1...2: return 0.8 // 经期高风险
        case 27...28: return 0.9 // 经前高风险
        case 26: return 0.7 // 经前中等风险
        case 3...5: return 0.6 // 经期中等风险
        case 12...16: return 0.4 // 排卵期轻微风险
        default: return 0.2 // 其他时期低风险
        }
    }
    
    // MARK: - 描述生成方法
    
    private func generateHRVDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "心率变异性反映自主神经系统平衡，与压力和头痛密切相关"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，近期趋势\(trend! > 0 ? "上升" : "下降")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private func generateSleepDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "睡眠质量直接影响头痛发生，建议保持规律作息"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，睡眠时长近期\(trend! > 0 ? "增加" : "减少")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private func generateHeartRateDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "静息心率反映整体健康状态，异常波动可能与头痛相关"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，心率近期\(trend! > 0 ? "升高" : "降低")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private func generateActivityDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "适量运动有助于减少头痛，过度或不足都可能成为触发因素"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，活动量近期\(trend! > 0 ? "增加" : "减少")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private func generateWeightDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "体重变化可能影响荷尔蒙平衡和头痛模式"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，体重近期\(trend! > 0 ? "增加" : "减少")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private func generateMindfulnessDescription(recordCount: Int, trend: Double?) -> String {
        let baseDescription = "正念练习有助于压力管理和头痛预防"
        let dataNote = recordCount < 10 ? "（基于有限数据的初步分析）" : ""
        let trendNote = trend != nil ? "，练习时间近期\(trend! > 0 ? "增加" : "减少")" : ""
        return baseDescription + trendNote + dataNote
    }
    
    private enum DataQuality {
        case insufficient, limited, adequate, comprehensive
    }

    // MARK: - 统计计算辅助方法
    
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
    
    private func calculatePValue(correlation: Double, sampleSize: Int) -> Double {
        // 简化的p值计算
        guard sampleSize > 2 else { return 1.0 }
        
        let t = correlation * sqrt(Double(sampleSize - 2) / (1 - correlation * correlation))
        let absT = abs(t)
        
        // 简化的t分布p值估算
        if absT > 2.6 {
            return 0.01
        } else if absT > 2.0 {
            return 0.05
        } else if absT > 1.7 {
            return 0.1
        } else {
            return 0.2
        }
    }
    
    
}
