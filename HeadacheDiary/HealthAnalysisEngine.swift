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

        guard let healthSnapshot = healthKitManager.healthDataSnapshot, records.count >= 3 else {
            print("⚠️ 健康数据或头痛记录不足，当前记录数：\(records.count)")
            // 即使数据不足，也返回一些基础的分析结果
            if records.count > 0 {
                results.append(HealthCorrelationResult(
                    healthMetric: "数据收集",
                    correlation: 0.0,
                    pValue: 1.0,
                    isSignificant: false,
                    riskFactor: .low,
                    description: "数据样本较小，需要更多记录进行准确分析"
                ))
            }
            return results
        }

        if let hrvMetric = healthSnapshot.heartRateVariability {
            let intensities = records.map { Double($0.intensity) }
            let hrvValues = records.map { _ in hrvMetric.value } // Simplified for now
            let correlation = calculatePearsonCorrelation(x: hrvValues, y: intensities)
            let pValue = calculatePValue(correlation: correlation, sampleSize: intensities.count)
            results.append(HealthCorrelationResult(healthMetric: "心率变异性(HRV)", correlation: correlation, pValue: pValue, isSignificant: pValue < 0.05, riskFactor: .high, description: "HRV与头痛的关系"))
        }

        // ... similar logic for other health metrics ...

        return results.sorted { $0.correlation > $1.correlation }
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
        guard let cycleDay = healthKitManager.healthDataSnapshot?.cycleDay else { return nil }
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
            print("✅ 头痛风险预测生成完成，风险评分: \(riskScore)")
        }
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