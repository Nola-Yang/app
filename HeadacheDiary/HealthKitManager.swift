import Foundation
import HealthKit
import Combine
import CoreData

// MARK: - 健康数据类型定义
struct HealthDataSnapshot {
    let dateRange: DateInterval
    let heartRateVariability: HealthMetric<Double>?
    let restingHeartRate: HealthMetric<Double>?
    let sleepDuration: HealthMetric<TimeInterval>?
    let deepSleepPercentage: HealthMetric<Double>?
    let menstrualFlowLevel: HealthMetric<Int>?
    let cycleDay: Int?
    let basalBodyTemperature: HealthMetric<Double>?
    let bodyWeight: HealthMetric<Double>?
    let stepCount: HealthMetric<Double>?
    let activeEnergyBurned: HealthMetric<Double>?
    let mindfulMinutes: HealthMetric<Double>?
    let bloodOxygen: HealthMetric<Double>?
    let respiratoryRate: HealthMetric<Double>?
}

struct HealthMetric<T> {
    let value: T
    let trend: Double? // 与前一周期比较的变化趋势
    let variability: Double? // 周期内的变异性
}

// MARK: - 健康相关性分析结果
struct HealthCorrelationResult {
    let healthMetric: String
    let correlation: Double  // -1 to 1
    let pValue: Double      // 统计显著性
    let isSignificant: Bool // p < 0.05
    let riskFactor: RiskLevel
    let description: String
    
    enum RiskLevel {
        case low, moderate, high, veryHigh
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .veryHigh: return "red"
            }
        }
    }
}

// MARK: - 健康风险预测
struct HeadacheRiskPrediction {
    let riskLevel: Double    // 0-1 头痛风险评分
    let primaryFactors: [String]  // 主要风险因素
    let recommendations: [String] // 预防建议
    let confidenceLevel: Double   // 预测可信度
}

// MARK: - HealthKit数据管理器
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isAuthorized = false
    @Published var healthDataSnapshot: HealthDataSnapshot?
    @Published var correlationResults: [HealthCorrelationResult] = []
    @Published var riskPrediction: HeadacheRiskPrediction?
    @Published var isAnalyzing = false
    
    // 健康数据类型
    private let healthTypesToRead: Set<HKObjectType> = [
        // 心率相关
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        
        // 睡眠数据
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        
        // 生殖健康
        HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
        HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
        
        // 身体指标
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        
        // 正念和健康
        HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        
        // 生理指标
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
    ]
    
    private let healthTypesToWrite: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .headache)!
    ]
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - 权限管理
    
    func requestHealthKitPermissions() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit不可用")
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: healthTypesToWrite, read: healthTypesToRead)
            await MainActor.run {
                self.isAuthorized = true
                print("✅ HealthKit权限获取成功")
            }
            return true
        } catch {
            print("❌ HealthKit权限请求失败: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        let typesToCheck = Array(healthTypesToRead)
        let allAuthorized = typesToCheck.allSatisfy { type in
            healthStore.authorizationStatus(for: type) == .sharingAuthorized
        }
        
        DispatchQueue.main.async {
            self.isAuthorized = allAuthorized
        }
    }
    
    // MARK: - 健康数据获取
    
    func fetchRecentHealthData(days: Int = 30) async {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return
        }

        await MainActor.run { self.isAnalyzing = true }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let dateInterval = DateInterval(start: startDate, end: endDate)

        async let hrvData = fetchHRVData(from: startDate, to: endDate)
        async let heartRateData = fetchRestingHeartRate(from: startDate, to: endDate)
        async let sleepData = fetchSleepData(from: startDate, to: endDate)
        async let menstrualData = fetchMenstrualData(from: startDate, to: endDate)
        async let bodyTempData = fetchBasalBodyTemperature(from: startDate, to: endDate)
        async let weightData = fetchBodyWeight(from: startDate, to: endDate)
        async let stepData = fetchStepCount(from: startDate, to: endDate)
        async let activeEnergyData = fetchActiveEnergy(from: startDate, to: endDate)
        async let mindfulData = fetchMindfulMinutes(from: startDate, to: endDate)
        async let oxygenData = fetchOxygenSaturation(from: startDate, to: endDate)
        async let respiratoryData = fetchRespiratoryRate(from: startDate, to: endDate)

        let results = await (
            hrv: hrvData,
            heartRate: heartRateData,
            sleep: sleepData,
            menstrual: menstrualData,
            bodyTemp: bodyTempData,
            weight: weightData,
            steps: stepData,
            activeEnergy: activeEnergyData,
            mindful: mindfulData,
            oxygen: oxygenData,
            respiratory: respiratoryData
        )

        let snapshot = HealthDataSnapshot(
            dateRange: dateInterval,
            heartRateVariability: processHealthMetric(samples: results.hrv, unit: HKUnit(from: "ms")),
            restingHeartRate: processHealthMetric(samples: results.heartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute())),
            sleepDuration: processSleepDuration(samples: results.sleep),
            deepSleepPercentage: processDeepSleepPercentage(samples: results.sleep),
            menstrualFlowLevel: processMenstrualFlow(samples: results.menstrual),
            cycleDay: calculateCycleDay(from: results.menstrual),
            basalBodyTemperature: processHealthMetric(samples: results.bodyTemp, unit: .degreeCelsius()),
            bodyWeight: processHealthMetric(samples: results.weight, unit: .gramUnit(with: .kilo)),
            stepCount: processHealthMetric(samples: results.steps, unit: .count()),
            activeEnergyBurned: processHealthMetric(samples: results.activeEnergy, unit: .kilocalorie()),
            mindfulMinutes: processMindfulMinutes(samples: results.mindful),
            bloodOxygen: processHealthMetric(samples: results.oxygen, unit: .percent()),
            respiratoryRate: processHealthMetric(samples: results.respiratory, unit: .count().unitDivided(by: .minute()))
        )

        await MainActor.run {
            self.healthDataSnapshot = snapshot
            self.isAnalyzing = false
            print("✅ 健康数据获取完成")
        }
    }

    private func processHealthMetric<T: HKQuantitySample>(samples: [T], unit: HKUnit) -> HealthMetric<Double>? {
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let average = values.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count))
        
        // Simplified trend calculation (comparing first and last half averages)
        let half = values.count / 2
        let firstHalfAverage = values.prefix(half).reduce(0, +) / Double(half)
        let secondHalfAverage = values.suffix(half).reduce(0, +) / Double(half)
        let trend = (secondHalfAverage - firstHalfAverage) / firstHalfAverage
        
        return HealthMetric(value: average, trend: trend, variability: standardDeviation)
    }

    private func processSleepDuration(samples: [HKCategorySample]) -> HealthMetric<TimeInterval>? {
        guard !samples.isEmpty else { return nil }
        let sleepDurations = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }.map { $0.endDate.timeIntervalSince($0.startDate) }
        let average = sleepDurations.reduce(0, +) / Double(sleepDurations.count)
        let standardDeviation = sqrt(sleepDurations.map { pow($0 - average, 2) }.reduce(0, +) / Double(sleepDurations.count))

        let half = sleepDurations.count / 2
        let firstHalfAverage = sleepDurations.prefix(half).reduce(0, +) / Double(half)
        let secondHalfAverage = sleepDurations.suffix(half).reduce(0, +) / Double(half)
        let trend = (secondHalfAverage - firstHalfAverage) / firstHalfAverage

        return HealthMetric(value: average, trend: trend, variability: standardDeviation)
    }

    private func processDeepSleepPercentage(samples: [HKCategorySample]) -> HealthMetric<Double>? {
        guard !samples.isEmpty else { return nil }
        var dailyDeepSleep = [Date: TimeInterval]()
        var dailyTotalSleep = [Date: TimeInterval]()

        for sample in samples {
            let day = Calendar.current.startOfDay(for: sample.startDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                dailyDeepSleep[day, default: 0] += duration
            }
            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                dailyTotalSleep[day, default: 0] += duration
            }
        }

        let percentages = dailyTotalSleep.keys.compactMap { day -> Double? in
            guard let total = dailyTotalSleep[day], total > 0, let deep = dailyDeepSleep[day] else { return nil }
            return (deep / total) * 100
        }
        
        guard !percentages.isEmpty else { return nil }

        let average = percentages.reduce(0, +) / Double(percentages.count)
        let standardDeviation = sqrt(percentages.map { pow($0 - average, 2) }.reduce(0, +) / Double(percentages.count))
        
        let half = percentages.count / 2
        let firstHalfAverage = percentages.prefix(half).reduce(0, +) / Double(half)
        let secondHalfAverage = percentages.suffix(half).reduce(0, +) / Double(half)
        let trend = (secondHalfAverage - firstHalfAverage) / firstHalfAverage

        return HealthMetric(value: average, trend: trend, variability: standardDeviation)
    }

    private func processMenstrualFlow(samples: [HKCategorySample]) -> HealthMetric<Int>? {
        guard !samples.isEmpty else { return nil }
        let flowLevels = samples.map { $0.value }
        let average = flowLevels.reduce(0, +) / flowLevels.count
        
        return HealthMetric(value: average, trend: nil, variability: nil)
    }

    private func processMindfulMinutes(samples: [HKCategorySample]) -> HealthMetric<Double>? {
        guard !samples.isEmpty else { return nil }
        let mindfulMinutes = samples.map { $0.endDate.timeIntervalSince($0.startDate) / 60 }
        let average = mindfulMinutes.reduce(0, +) / Double(mindfulMinutes.count)
        let standardDeviation = sqrt(mindfulMinutes.map { pow($0 - average, 2) }.reduce(0, +) / Double(mindfulMinutes.count))

        let half = mindfulMinutes.count / 2
        let firstHalfAverage = mindfulMinutes.prefix(half).reduce(0, +) / Double(half)
        let secondHalfAverage = mindfulMinutes.suffix(half).reduce(0, +) / Double(half)
        let trend = (secondHalfAverage - firstHalfAverage) / firstHalfAverage

        return HealthMetric(value: average, trend: trend, variability: standardDeviation)
    }
    
    // MARK: - 具体数据获取方法
    
    private func fetchHRVData(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ HRV数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 静息心率数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(from startDate: Date, to endDate: Date) async -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 200, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 睡眠数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let categorySamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: categorySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchMenstrualData(from startDate: Date, to endDate: Date) async -> [HKCategorySample] {
        guard let menstrualType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: menstrualType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 月经数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let categorySamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: categorySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchBasalBodyTemperature(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let tempType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 基础体温数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchBodyWeight(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 体重数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchStepCount(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 步数数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveEnergy(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: energyType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 活跃卡路里数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchMindfulMinutes(from startDate: Date, to endDate: Date) async -> [HKCategorySample] {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 正念数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let categorySamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: categorySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchOxygenSaturation(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let oxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 血氧数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRespiratoryRate(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("❌ 呼吸频率数据获取失败: \(error)")
                    continuation.resume(returning: [])
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - 数据处理辅助方法
    
    private func calculateSleepDuration(from sleepSamples: [HKCategorySample]) -> TimeInterval? {
        let today = Calendar.current.startOfDay(for: Date())
        let recentSleep = sleepSamples.filter { sample in
            sample.startDate >= today.addingTimeInterval(-24 * 3600)
        }
        
        var totalDuration: TimeInterval = 0
        for sample in recentSleep {
            if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                totalDuration += sample.endDate.timeIntervalSince(sample.startDate)
            }
        }
        
        return totalDuration > 0 ? totalDuration : nil
    }
    
    private func calculateDeepSleepPercentage(from sleepSamples: [HKCategorySample]) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        let recentSleep = sleepSamples.filter { sample in
            sample.startDate >= today.addingTimeInterval(-24 * 3600)
        }
        
        var totalSleep: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        
        for sample in recentSleep {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                totalSleep += duration
            }
            if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                deepSleep += duration
            }
        }
        
        return totalSleep > 0 ? (deepSleep / totalSleep) * 100 : nil
    }
    
    private func calculateCycleDay(from menstrualSamples: [HKCategorySample]) -> Int? {
        guard let lastPeriodStart = menstrualSamples.first(where: { $0.value > 0 })?.startDate else {
            return nil
        }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: lastPeriodStart, to: Date()).day ?? 0
        return daysSinceStart + 1
    }
    
    private func calculateMindfulMinutes(from mindfulSamples: [HKCategorySample]) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        let recentMindful = mindfulSamples.filter { sample in
            sample.startDate >= today.addingTimeInterval(-7 * 24 * 3600) // 过去7天
        }
        
        let totalSeconds = recentMindful.reduce(0) { total, sample in
            total + sample.endDate.timeIntervalSince(sample.startDate)
        }
        
        return totalSeconds > 0 ? totalSeconds / 60 : nil // 转换为分钟
    }
    
    // MARK: - 头痛记录同步到健康应用
    
    func syncHeadacheToHealthKit(_ record: HeadacheRecord) async -> Bool {
        guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache),
              let startTime = record.startTime else {
            return false
        }
        
        let endTime = record.endTime ?? Date()
        let severity: HKCategoryValueSeverity
        
        switch record.intensity {
        case 1...3:
            severity = .mild
        case 4...6:
            severity = .moderate
        case 7...8:
            severity = .severe
        default:
            severity = .unspecified
        }
        
        let headacheSample = HKCategorySample(
            type: headacheType,
            value: severity.rawValue,
            start: startTime,
            end: endTime
        )
        
        return await withCheckedContinuation { continuation in
            healthStore.save(headacheSample) { success, error in
                if let error = error {
                    print("❌ 头痛记录同步到HealthKit失败: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ 头痛记录已同步到HealthKit")
                    continuation.resume(returning: true)
                }
            }
        }
    }
}