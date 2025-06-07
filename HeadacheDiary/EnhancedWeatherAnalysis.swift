//
//  EnhancedWeatherAnalysis.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//

import Foundation
import CoreData

// MARK: - 数据质量评估
struct DataQualityMetrics {
    let totalDays: Int
    let weatherRecordDays: Int
    let headacheRecordDays: Int
    let overlappingDays: Int // 同时有天气和头痛记录的天数
    let coveragePercentage: Double // 数据覆盖率
    let consistency: Double // 数据一致性评分
    
    var isQualityAcceptable: Bool {
        // 至少需要30天的重叠数据，覆盖率超过70%
        return overlappingDays >= 30 && coveragePercentage >= 0.7
    }
    
    var qualityLevel: DataQualityLevel {
        switch overlappingDays {
        case 0..<14: return .insufficient
        case 14..<30: return .minimal
        case 30..<60: return .acceptable
        case 60..<90: return .good
        default: return .excellent
        }
    }
}

enum DataQualityLevel: Int, CaseIterable {
    case insufficient = 0
    case minimal = 1
    case acceptable = 2
    case good = 3
    case excellent = 4
    
    var displayName: String {
        switch self {
        case .insufficient: return "数据不足"
        case .minimal: return "数据较少"
        case .acceptable: return "数据可用"
        case .good: return "数据充足"
        case .excellent: return "数据丰富"
        }
    }
    
    var description: String {
        switch self {
        case .insufficient: return "需要至少14天的数据才能开始基础分析"
        case .minimal: return "可以进行基础分析，但准确度有限"
        case .acceptable: return "可以进行可靠的相关性分析"
        case .good: return "可以进行详细的模式识别和预测"
        case .excellent: return "可以进行高精度的个性化预测"
        }
    }
    
    var minimumDaysRequired: Int {
        switch self {
        case .insufficient: return 14
        case .minimal: return 30
        case .acceptable: return 60
        case .good: return 90
        case .excellent: return 120
        }
    }
}

// MARK: - 增强的相关性分析
struct EnhancedWeatherCorrelation {
    let weatherFactor: WeatherFactor
    let correlation: Double // -1 到 1 的相关系数
    let confidence: Double // 0 到 1 的置信度
    let sampleSize: Int
    let pValue: Double // 统计显著性
    let effect: CorrelationEffect
    
    var isSignificant: Bool {
        return pValue < 0.05 && sampleSize >= 20
    }
    
    var strength: CorrelationStrength {
        let absCorrelation = abs(correlation)
        switch absCorrelation {
        case 0..<0.3: return .weak
        case 0.3..<0.5: return .moderate
        case 0.5..<0.7: return .strong
        default: return .veryStrong
        }
    }
}

enum WeatherFactor: String, CaseIterable {
    case temperature = "温度"
    case temperatureChange = "温度变化"
    case pressure = "气压"
    case pressureChange = "气压变化"
    case humidity = "湿度"
    case windSpeed = "风速"
    case uvIndex = "紫外线指数"
    case precipitation = "降水概率"
    
    var unit: String {
        switch self {
        case .temperature, .temperatureChange: return "°C"
        case .pressure, .pressureChange: return "hPa"
        case .humidity, .precipitation: return "%"
        case .windSpeed: return "km/h"
        case .uvIndex: return ""
        }
    }
}

enum CorrelationEffect {
    case positive // 正相关：值越高，头痛风险越大
    case negative // 负相关：值越低，头痛风险越大
    case nonLinear // 非线性：极端值增加风险
    case threshold(value: Double) // 阈值效应：超过某值风险增加
}

enum CorrelationStrength: String {
    case weak = "弱相关"
    case moderate = "中等相关"
    case strong = "强相关"
    case veryStrong = "极强相关"
}

// MARK: - 机器学习特征
struct WeatherMLFeatures {
    // 基础天气特征
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let windSpeed: Double
    let uvIndex: Double
    
    // 变化率特征
    let temperatureChange24h: Double
    let pressureChange24h: Double
    let humidityChange24h: Double
    
    // 衍生特征
    let apparentTemperature: Double // 体感温度
    let dewPoint: Double // 露点温度
    let pressureTrend: PressureTrend // 气压趋势
    
    // 时间特征
    let hourOfDay: Int
    let dayOfWeek: Int
    let seasonalFactor: Double // 0-1，季节因子
    
    // 历史特征
    let headacheInLast3Days: Bool
    let averageIntensityLast7Days: Double
    let medicationUseLast7Days: Int
    
    func toArray() -> [Double] {
        return [
            temperature, humidity, pressure, windSpeed, Double(uvIndex),
            temperatureChange24h, pressureChange24h, humidityChange24h,
            apparentTemperature, dewPoint, Double(pressureTrend.rawValue),
            Double(hourOfDay), Double(dayOfWeek), seasonalFactor,
            headacheInLast3Days ? 1.0 : 0.0, averageIntensityLast7Days, Double(medicationUseLast7Days)
        ]
    }
}

enum PressureTrend: Int {
    case rapidlyFalling = -2
    case falling = -1
    case steady = 0
    case rising = 1
    case rapidlyRising = 2
}

// MARK: - 增强的风险预测模型
class EnhancedRiskPredictionModel {
    private let minimumDataPoints = 30
    private let confidenceThreshold = 0.7
    
    // 多模型集成预测
    func predictHeadacheRisk(
        features: WeatherMLFeatures,
        historicalData: [HeadacheWeatherDataPoint],
        personalFactors: PersonalFactors
    ) -> RiskPrediction {
        
        // 检查数据质量
        let dataQuality = assessDataQuality(historicalData)
        guard dataQuality.isQualityAcceptable else {
            return RiskPrediction(
                riskLevel: .unknown,
                confidence: 0,
                primaryFactors: [],
                recommendation: "需要更多数据才能进行准确预测，请继续记录至少\(dataQuality.qualityLevel.minimumDaysRequired - dataQuality.overlappingDays)天"
            )
        }
        
        // 1. 统计模型预测
        let statisticalPrediction = statisticalModel(features: features, historicalData: historicalData)
        
        // 2. 模式匹配预测
        let patternPrediction = patternMatchingModel(features: features, historicalData: historicalData)
        
        // 3. 阈值模型预测
        let thresholdPrediction = thresholdModel(features: features, personalThresholds: personalFactors.thresholds)
        
        // 4. 时间序列预测
        let timeSeriesPrediction = timeSeriesModel(features: features, historicalData: historicalData)
        
        // 集成预测结果
        let ensemblePrediction = ensemblePredict([
            (statisticalPrediction, 0.3),
            (patternPrediction, 0.25),
            (thresholdPrediction, 0.25),
            (timeSeriesPrediction, 0.2)
        ])
        
        // 生成个性化建议
        let recommendation = generateRecommendation(
            prediction: ensemblePrediction,
            features: features,
            personalFactors: personalFactors
        )
        
        return RiskPrediction(
            riskLevel: ensemblePrediction.riskLevel,
            confidence: ensemblePrediction.confidence,
            primaryFactors: ensemblePrediction.factors,
            recommendation: recommendation
        )
    }
    
    // 统计模型：基于历史数据的贝叶斯推断
    private func statisticalModel(
        features: WeatherMLFeatures,
        historicalData: [HeadacheWeatherDataPoint]
    ) -> ModelPrediction {
        
        // 计算在相似天气条件下的头痛概率
        let similarDays = findSimilarWeatherDays(
            currentFeatures: features,
            historicalData: historicalData,
            threshold: 0.8
        )
        
        guard similarDays.count >= 5 else {
            return ModelPrediction(riskLevel: .unknown, confidence: 0, factors: [])
        }
        
        let headacheRate = Double(similarDays.filter { $0.hadHeadache }.count) / Double(similarDays.count)
        let confidence = min(Double(similarDays.count) / 20.0, 1.0) // 20个相似天气样本达到最高置信度
        
        let riskLevel: HeadacheRisk
        switch headacheRate {
        case 0..<0.2: riskLevel = .low
        case 0.2..<0.4: riskLevel = .moderate
        case 0.4..<0.6: riskLevel = .high
        default: riskLevel = .veryHigh
        }
        
        // 识别主要因素
        let factors = identifySignificantFactors(similarDays: similarDays, currentFeatures: features)
        
        return ModelPrediction(riskLevel: riskLevel, confidence: confidence, factors: factors)
    }
    
    // 模式匹配模型：查找历史上的相似模式
    private func patternMatchingModel(
        features: WeatherMLFeatures,
        historicalData: [HeadacheWeatherDataPoint]
    ) -> ModelPrediction {
        
        // 提取最近7天的天气模式
        let recentPattern = extractWeatherPattern(from: historicalData, days: 7)
        
        // 在历史数据中查找相似模式
        let matchingPatterns = findMatchingPatterns(
            pattern: recentPattern,
            in: historicalData,
            minSimilarity: 0.7
        )
        
        guard matchingPatterns.count >= 3 else {
            return ModelPrediction(riskLevel: .unknown, confidence: 0, factors: [])
        }
        
        // 分析匹配模式后的头痛发生率
        let headacheAfterPattern = matchingPatterns.filter { $0.followedByHeadache }.count
        let patternHeadacheRate = Double(headacheAfterPattern) / Double(matchingPatterns.count)
        
        let confidence = min(Double(matchingPatterns.count) / 10.0, 1.0)
        
        let riskLevel: HeadacheRisk
        switch patternHeadacheRate {
        case 0..<0.25: riskLevel = .low
        case 0.25..<0.5: riskLevel = .moderate
        case 0.5..<0.75: riskLevel = .high
        default: riskLevel = .veryHigh
        }
        
        return ModelPrediction(
            riskLevel: riskLevel,
            confidence: confidence * 0.9, // 模式匹配通常略低置信度
            factors: recentPattern.significantFactors
        )
    }
    
    // 阈值模型：基于个人化阈值
    private func thresholdModel(
        features: WeatherMLFeatures,
        personalThresholds: PersonalThresholds
    ) -> ModelPrediction {
        
        var riskScore = 0.0
        var triggeredFactors: [RiskFactor] = []
        
        // 检查各项阈值
        if abs(features.pressureChange24h) > personalThresholds.pressureChangeThreshold {
            riskScore += 0.3
            triggeredFactors.append(RiskFactor(
                factor: .pressureChange,
                value: features.pressureChange24h,
                contribution: 0.3
            ))
        }
        
        if abs(features.temperatureChange24h) > personalThresholds.temperatureChangeThreshold {
            riskScore += 0.25
            triggeredFactors.append(RiskFactor(
                factor: .temperatureChange,
                value: features.temperatureChange24h,
                contribution: 0.25
            ))
        }
        
        if features.humidity > personalThresholds.humidityThreshold {
            riskScore += 0.2
            triggeredFactors.append(RiskFactor(
                factor: .humidity,
                value: features.humidity,
                contribution: 0.2
            ))
        }
        
        if features.pressure < personalThresholds.lowPressureThreshold {
            riskScore += 0.25
            triggeredFactors.append(RiskFactor(
                factor: .pressure,
                value: features.pressure,
                contribution: 0.25
            ))
        }
        
        let riskLevel: HeadacheRisk
        switch riskScore {
        case 0..<0.3: riskLevel = .low
        case 0.3..<0.5: riskLevel = .moderate
        case 0.5..<0.7: riskLevel = .high
        default: riskLevel = .veryHigh
        }
        
        let confidence = triggeredFactors.isEmpty ? 0.5 : min(riskScore + 0.3, 1.0)
        
        return ModelPrediction(
            riskLevel: riskLevel,
            confidence: confidence,
            factors: triggeredFactors
        )
    }
    
    // 时间序列模型：ARIMA-like预测
    private func timeSeriesModel(
        features: WeatherMLFeatures,
        historicalData: [HeadacheWeatherDataPoint]
    ) -> ModelPrediction {
        
        guard historicalData.count >= 30 else {
            return ModelPrediction(riskLevel: .unknown, confidence: 0, factors: [])
        }
        
        // 提取时间序列特征
        let timeSeries = extractTimeSeries(from: historicalData)
        
        // 计算移动平均和趋势
        let ma7 = movingAverage(timeSeries, window: 7)
        let trend = calculateTrend(timeSeries)
        
        // 季节性分析
        let seasonality = analyzeSeasonality(timeSeries)
        
        // 预测下一个时间点
        let prediction = ma7.last ?? 0.5
        let adjustedPrediction = prediction + trend * 0.1 + seasonality * 0.2
        
        let riskLevel: HeadacheRisk
        switch adjustedPrediction {
        case 0..<0.3: riskLevel = .low
        case 0.3..<0.5: riskLevel = .moderate
        case 0.5..<0.7: riskLevel = .high
        default: riskLevel = .veryHigh
        }
        
        let confidence = min(0.6 + (Double(historicalData.count) / 100.0) * 0.3, 0.9)
        
        return ModelPrediction(
            riskLevel: riskLevel,
            confidence: confidence,
            factors: [] // 时间序列模型不提供具体因素
        )
    }
    
    // 集成预测
    private func ensemblePredict(_ predictions: [(ModelPrediction, Double)]) -> EnsemblePrediction {
        var weightedRisk = 0.0
        var totalWeight = 0.0
        var allFactors: [RiskFactor] = []
        
        for (prediction, weight) in predictions {
            if prediction.confidence > 0 {
                weightedRisk += Double(prediction.riskLevel.rawValue) * weight * prediction.confidence
                totalWeight += weight * prediction.confidence
                allFactors.append(contentsOf: prediction.factors)
            }
        }
        
        guard totalWeight > 0 else {
            return EnsemblePrediction(
                riskLevel: .unknown,
                confidence: 0,
                factors: []
            )
        }
        
        let averageRisk = weightedRisk / totalWeight
        let riskLevel: HeadacheRisk
        
        switch Int(round(averageRisk)) {
        case 1: riskLevel = .low
        case 2: riskLevel = .moderate
        case 3: riskLevel = .high
        case 4: riskLevel = .veryHigh
        default: riskLevel = .unknown
        }
        
        // 聚合和排序风险因素
        let aggregatedFactors = aggregateRiskFactors(allFactors)
            .sorted { $0.contribution > $1.contribution }
            .prefix(5)
            .map { $0 }
        
        let confidence = totalWeight / predictions.reduce(0) { $0 + $1.1 }
        
        return EnsemblePrediction(
            riskLevel: riskLevel,
            confidence: confidence,
            factors: aggregatedFactors
        )
    }
    
    // 辅助方法
    private func assessDataQuality(_ data: [HeadacheWeatherDataPoint]) -> DataQualityMetrics {
        let totalDays = Set(data.map { Calendar.current.startOfDay(for: $0.date) }).count
        let weatherDays = data.filter { $0.hasWeatherData }.count
        let headacheDays = data.filter { $0.hadHeadache }.count
        let overlappingDays = data.filter { $0.hasWeatherData && $0.recordExists }.count
        
        let coverage = totalDays > 0 ? Double(overlappingDays) / Double(totalDays) : 0
        let consistency = calculateDataConsistency(data)
        
        return DataQualityMetrics(
            totalDays: totalDays,
            weatherRecordDays: weatherDays,
            headacheRecordDays: headacheDays,
            overlappingDays: overlappingDays,
            coveragePercentage: coverage,
            consistency: consistency
        )
    }
    
    private func findSimilarWeatherDays(
        currentFeatures: WeatherMLFeatures,
        historicalData: [HeadacheWeatherDataPoint],
        threshold: Double
    ) -> [HeadacheWeatherDataPoint] {
        
        return historicalData.filter { dataPoint in
            guard dataPoint.hasWeatherData else { return false }
            let similarity = calculateWeatherSimilarity(
                features1: currentFeatures,
                features2: dataPoint.weatherFeatures
            )
            return similarity >= threshold
        }
    }
    
    private func calculateWeatherSimilarity(
        features1: WeatherMLFeatures,
        features2: WeatherMLFeatures
    ) -> Double {
        // 使用加权欧几里得距离
        let weights = [
            0.15, // temperature
            0.10, // humidity
            0.20, // pressure
            0.05, // windSpeed
            0.05, // uvIndex
            0.15, // temperatureChange24h
            0.20, // pressureChange24h
            0.10  // humidityChange24h
        ]
        
        let features1Array = features1.toArray()
        let features2Array = features2.toArray()
        
        var weightedDistance = 0.0
        for i in 0..<min(weights.count, features1Array.count) {
            let diff = features1Array[i] - features2Array[i]
            weightedDistance += weights[i] * diff * diff
        }
        
        // 转换为相似度（0-1）
        return exp(-sqrt(weightedDistance))
    }
    
    private func generateRecommendation(
        prediction: EnsemblePrediction,
        features: WeatherMLFeatures,
        personalFactors: PersonalFactors
    ) -> String {
        
        guard prediction.confidence > confidenceThreshold else {
            return "预测置信度较低，建议继续记录数据以提高准确性"
        }
        
        var recommendations: [String] = []
        
        // 基于风险级别的建议
        switch prediction.riskLevel {
        case .low:
            recommendations.append("今日头痛风险较低，适合正常活动")
        case .moderate:
            recommendations.append("今日有中等头痛风险，建议适度休息")
        case .high:
            recommendations.append("今日头痛风险较高，建议准备药物并避免触发因素")
        case .veryHigh:
            recommendations.append("今日头痛风险很高，建议采取预防措施并准备应急药物")
        }
        
        // 基于具体因素的建议
        for factor in prediction.factors.prefix(3) {
            switch factor.factor {
            case .pressureChange:
                if factor.value > 0 {
                    recommendations.append("气压上升中，注意通风")
                } else {
                    recommendations.append("气压下降中，建议减少剧烈运动")
                }
            case .temperatureChange:
                recommendations.append("温度变化较大，注意保暖或降温")
            case .humidity:
                if factor.value > 80 {
                    recommendations.append("湿度较高，保持室内干燥")
                }
            default:
                break
            }
        }
        
        // 个性化建议
        if let lastHeadache = personalFactors.lastHeadacheDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastHeadache, to: Date()).day ?? 0
            if daysSince < 3 {
                recommendations.append("近期有头痛记录，请特别注意休息")
            }
        }
        
        return recommendations.joined(separator: "。")
    }
    
    private func calculateDataConsistency(_ data: [HeadacheWeatherDataPoint]) -> Double {
        // 计算数据的一致性分数
        guard data.count > 7 else { return 0.5 }
        
        let sortedData = data.sorted { $0.date < $1.date }
        var gaps: [Int] = []
        
        for i in 1..<sortedData.count {
            let daysBetween = Calendar.current.dateComponents(
                [.day],
                from: sortedData[i-1].date,
                to: sortedData[i].date
            ).day ?? 0
            
            if daysBetween > 1 {
                gaps.append(daysBetween - 1)
            }
        }
        
        if gaps.isEmpty { return 1.0 }
        
        let averageGap = Double(gaps.reduce(0, +)) / Double(gaps.count)
        return max(0, 1.0 - (averageGap / 7.0)) // 7天以上的间隔显著降低一致性
    }
}

// MARK: - 数据模型
struct HeadacheWeatherDataPoint {
    let date: Date
    let hadHeadache: Bool
    let headacheIntensity: Int?
    let hasWeatherData: Bool
    let weatherFeatures: WeatherMLFeatures
    let recordExists: Bool // 是否有记录（用于区分没头痛和没记录）
}

struct PersonalFactors {
    let age: Int?
    let gender: String?
    let averageHeadachesPerMonth: Double
    let commonTriggers: [String]
    let medicationHistory: [MedicationRecord]
    let lastHeadacheDate: Date?
    let thresholds: PersonalThresholds
}

struct PersonalThresholds {
    let pressureChangeThreshold: Double
    let temperatureChangeThreshold: Double
    let humidityThreshold: Double
    let lowPressureThreshold: Double
    
    static var defaults: PersonalThresholds {
        return PersonalThresholds(
            pressureChangeThreshold: 3.0,
            temperatureChangeThreshold: 8.0,
            humidityThreshold: 80.0,
            lowPressureThreshold: 1005.0
        )
    }
}

struct MedicationRecord {
    let date: Date
    let medicationType: String
    let wasEffective: Bool
}

struct ModelPrediction {
    let riskLevel: HeadacheRisk
    let confidence: Double
    let factors: [RiskFactor]
}

struct EnsemblePrediction {
    let riskLevel: HeadacheRisk
    let confidence: Double
    let factors: [RiskFactor]
}

struct RiskFactor: Identifiable {
    let id = UUID()
    let factor: WeatherFactor
    let value: Double
    let contribution: Double // 0-1, 对风险的贡献度
}

struct RiskPrediction {
    let riskLevel: HeadacheRisk
    let confidence: Double
    let primaryFactors: [RiskFactor]
    let recommendation: String
}

struct WeatherPattern {
    let duration: Int // 天数
    let averageTemperature: Double
    let averagePressure: Double
    let temperatureTrend: Double // 斜率
    let pressureTrend: Double // 斜率
    let significantFactors: [RiskFactor]
}

struct PatternMatch {
    let pattern: WeatherPattern
    let similarity: Double
    let followedByHeadache: Bool
}

// MARK: - 扩展HeadacheRisk
extension HeadacheRisk {
    static let unknown = HeadacheRisk(rawValue: 0) ?? .low
}

// MARK: - 辅助函数
private func extractWeatherPattern(from data: [HeadacheWeatherDataPoint], days: Int) -> WeatherPattern {
    let recentData = Array(data.suffix(days))
    guard !recentData.isEmpty else {
        return WeatherPattern(
            duration: 0,
            averageTemperature: 20,
            averagePressure: 1013,
            temperatureTrend: 0,
            pressureTrend: 0,
            significantFactors: []
        )
    }
    
    let temperatures = recentData.compactMap { $0.hasWeatherData ? $0.weatherFeatures.temperature : nil }
    let pressures = recentData.compactMap { $0.hasWeatherData ? $0.weatherFeatures.pressure : nil }
    
    let avgTemp = temperatures.isEmpty ? 20.0 : temperatures.reduce(0, +) / Double(temperatures.count)
    let avgPressure = pressures.isEmpty ? 1013.0 : pressures.reduce(0, +) / Double(pressures.count)
    
    // 计算趋势
    let tempTrend = calculateLinearTrend(temperatures)
    let pressureTrend = calculateLinearTrend(pressures)
    
    return WeatherPattern(
        duration: days,
        averageTemperature: avgTemp,
        averagePressure: avgPressure,
        temperatureTrend: tempTrend,
        pressureTrend: pressureTrend,
        significantFactors: []
    )
}

private func calculateLinearTrend(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    
    let n = Double(values.count)
    let sumX = (0..<values.count).reduce(0.0) { $0 + Double($1) }
    let sumY = values.reduce(0, +)
    let sumXY = (0..<values.count).reduce(0.0) { sum, i in
        sum + Double(i) * values[i]
    }
    let sumXX = (0..<values.count).reduce(0.0) { sum, i in
        sum + Double(i) * Double(i)
    }
    
    let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
    return slope
}

private func findMatchingPatterns(
    pattern: WeatherPattern,
    in data: [HeadacheWeatherDataPoint],
    minSimilarity: Double
) -> [PatternMatch] {
    var matches: [PatternMatch] = []
    
    // 滑动窗口查找相似模式
    for i in 0..<(data.count - pattern.duration) {
        let windowData = Array(data[i..<(i + pattern.duration)])
        let windowPattern = extractWeatherPattern(from: windowData, days: pattern.duration)
        
        let similarity = calculatePatternSimilarity(pattern1: pattern, pattern2: windowPattern)
        
        if similarity >= minSimilarity {
            // 检查模式后是否有头痛
            let followedByHeadache = i + pattern.duration < data.count &&
                data[i + pattern.duration].hadHeadache
            
            matches.append(PatternMatch(
                pattern: windowPattern,
                similarity: similarity,
                followedByHeadache: followedByHeadache
            ))
        }
    }
    
    return matches
}

private func calculatePatternSimilarity(pattern1: WeatherPattern, pattern2: WeatherPattern) -> Double {
    let tempDiff = abs(pattern1.averageTemperature - pattern2.averageTemperature) / 20.0
    let pressureDiff = abs(pattern1.averagePressure - pattern2.averagePressure) / 20.0
    let tempTrendDiff = abs(pattern1.temperatureTrend - pattern2.temperatureTrend) / 5.0
    let pressureTrendDiff = abs(pattern1.pressureTrend - pattern2.pressureTrend) / 5.0
    
    let totalDiff = tempDiff + pressureDiff + tempTrendDiff + pressureTrendDiff
    return max(0, 1.0 - totalDiff / 4.0)
}

private func extractTimeSeries(from data: [HeadacheWeatherDataPoint]) -> [Double] {
    return data.map { $0.hadHeadache ? 1.0 : 0.0 }
}

private func movingAverage(_ series: [Double], window: Int) -> [Double] {
    guard series.count >= window else { return series }
    
    var result: [Double] = []
    for i in 0...(series.count - window) {
        let windowSum = series[i..<(i + window)].reduce(0, +)
        result.append(windowSum / Double(window))
    }
    return result
}

private func calculateTrend(_ series: [Double]) -> Double {
    return calculateLinearTrend(series)
}

private func analyzeSeasonality(_ series: [Double]) -> Double {
    // 简化的季节性分析
    let month = Calendar.current.component(.month, from: Date())
    
    // 基于月份的季节性因子
    switch month {
    case 12, 1, 2: return 0.1 // 冬季
    case 3, 4, 5: return 0.2 // 春季
    case 6, 7, 8: return -0.1 // 夏季
    case 9, 10, 11: return 0.15 // 秋季
    default: return 0
    }
}

private func identifySignificantFactors(
    similarDays: [HeadacheWeatherDataPoint],
    currentFeatures: WeatherMLFeatures
) -> [RiskFactor] {
    
    var factors: [RiskFactor] = []
    
    // 分析每个天气因素的影响
    let headacheDays = similarDays.filter { $0.hadHeadache }
    let nonHeadacheDays = similarDays.filter { !$0.hadHeadache }
    
    guard !headacheDays.isEmpty && !nonHeadacheDays.isEmpty else { return [] }
    
    // 温度分析
    let avgTempHeadache = headacheDays.compactMap { $0.hasWeatherData ? $0.weatherFeatures.temperature : nil }
        .reduce(0, +) / Double(headacheDays.count)
    let avgTempNoHeadache = nonHeadacheDays.compactMap { $0.hasWeatherData ? $0.weatherFeatures.temperature : nil }
        .reduce(0, +) / Double(nonHeadacheDays.count)
    
    if abs(avgTempHeadache - avgTempNoHeadache) > 2 {
        factors.append(RiskFactor(
            factor: .temperature,
            value: currentFeatures.temperature,
            contribution: min(abs(avgTempHeadache - avgTempNoHeadache) / 10, 0.3)
        ))
    }
    
    // 气压变化分析
    let avgPressureChangeHeadache = headacheDays.compactMap { $0.hasWeatherData ? $0.weatherFeatures.pressureChange24h : nil }
        .reduce(0, +) / Double(headacheDays.count)
    
    if abs(avgPressureChangeHeadache) > 2 {
        factors.append(RiskFactor(
            factor: .pressureChange,
            value: currentFeatures.pressureChange24h,
            contribution: min(abs(avgPressureChangeHeadache) / 10, 0.4)
        ))
    }
    
    return factors.sorted { $0.contribution > $1.contribution }
}

private func aggregateRiskFactors(_ factors: [RiskFactor]) -> [RiskFactor] {
    var aggregated: [WeatherFactor: (totalContribution: Double, totalValue: Double, count: Int)] = [:]
    
    for factor in factors {
        let current = aggregated[factor.factor] ?? (0, 0, 0)
        aggregated[factor.factor] = (
            current.totalContribution + factor.contribution,
            current.totalValue + factor.value,
            current.count + 1
        )
    }
    
    return aggregated.map { factor, data in
        RiskFactor(
            factor: factor,
            value: data.totalValue / Double(data.count),
            contribution: data.totalContribution / Double(data.count)
        )
    }
}

// MARK: - 个性化阈值学习
class PersonalThresholdLearner {
    
    func learnPersonalThresholds(from historicalData: [HeadacheWeatherDataPoint]) -> PersonalThresholds {
        guard historicalData.count >= 30 else { return PersonalThresholds.defaults }
        
        let headacheDays = historicalData.filter { $0.hadHeadache && $0.hasWeatherData }
        guard headacheDays.count >= 10 else { return PersonalThresholds.defaults }
        
        // 分析压力变化阈值
        let pressureChanges = headacheDays.map { abs($0.weatherFeatures.pressureChange24h) }
        let pressureChangeThreshold = calculateOptimalThreshold(
            values: pressureChanges,
            percentile: 0.75
        )
        
        // 分析温度变化阈值
        let tempChanges = headacheDays.map { abs($0.weatherFeatures.temperatureChange24h) }
        let tempChangeThreshold = calculateOptimalThreshold(
            values: tempChanges,
            percentile: 0.75
        )
        
        // 分析湿度阈值
        let humidities = headacheDays.map { $0.weatherFeatures.humidity }
        let humidityThreshold = calculateOptimalThreshold(
            values: humidities,
            percentile: 0.75
        )
        
        // 分析低压阈值
        let pressures = headacheDays.map { $0.weatherFeatures.pressure }
        let lowPressureThreshold = calculateOptimalThreshold(
            values: pressures,
            percentile: 0.25,
            isLowerBetter: true
        )
        
        return PersonalThresholds(
            pressureChangeThreshold: max(pressureChangeThreshold, 2.0),
            temperatureChangeThreshold: max(tempChangeThreshold, 5.0),
            humidityThreshold: min(max(humidityThreshold, 60.0), 90.0),
            lowPressureThreshold: max(lowPressureThreshold, 990.0)
        )
    }
    
    private func calculateOptimalThreshold(
        values: [Double],
        percentile: Double,
        isLowerBetter: Bool = false
    ) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        
        if isLowerBetter {
            return sorted[sorted.count - 1 - index]
        } else {
            return sorted[index]
        }
    }
}

// MARK: - 预测结果可视化
struct PredictionVisualization {
    let prediction: RiskPrediction
    let dataQuality: DataQualityMetrics
    let historicalAccuracy: Double?
    
    func generateVisualizationData() -> VisualizationData {
        return VisualizationData(
            riskGauge: RiskGaugeData(
                value: Double(prediction.riskLevel.rawValue) / 4.0,
                color: prediction.riskLevel.color,
                label: prediction.riskLevel.displayName
            ),
            confidenceBar: ConfidenceBarData(
                value: prediction.confidence,
                threshold: 0.7,
                label: "预测置信度: \(Int(prediction.confidence * 100))%"
            ),
            factorsChart: prediction.primaryFactors.map { factor in
                FactorChartData(
                    name: factor.factor.rawValue,
                    value: factor.contribution,
                    actualValue: "\(factor.value.formatted(.number.precision(.fractionLength(1))))\(factor.factor.unit)"
                )
            },
            dataQualityIndicator: DataQualityIndicatorData(
                level: dataQuality.qualityLevel,
                overlappingDays: dataQuality.overlappingDays,
                requiredDays: dataQuality.qualityLevel.minimumDaysRequired
            ),
            accuracyMetric: historicalAccuracy.map { accuracy in
                AccuracyMetricData(
                    value: accuracy,
                    label: "历史预测准确率: \(Int(accuracy * 100))%"
                )
            }
        )
    }
}

struct VisualizationData {
    let riskGauge: RiskGaugeData
    let confidenceBar: ConfidenceBarData
    let factorsChart: [FactorChartData]
    let dataQualityIndicator: DataQualityIndicatorData
    let accuracyMetric: AccuracyMetricData?
}

struct RiskGaugeData {
    let value: Double // 0-1
    let color: String
    let label: String
}

struct ConfidenceBarData {
    let value: Double // 0-1
    let threshold: Double
    let label: String
}

struct FactorChartData {
    let name: String
    let value: Double // 贡献度 0-1
    let actualValue: String
}

struct DataQualityIndicatorData {
    let level: DataQualityLevel
    let overlappingDays: Int
    let requiredDays: Int
}

struct AccuracyMetricData {
    let value: Double // 0-1
    let label: String
}

// MARK: - 预测准确性追踪
class PredictionAccuracyTracker {
    private let userDefaults = UserDefaults.standard
    private let accuracyKey = "WeatherPredictionAccuracy"
    
    struct PredictionRecord: Codable {
        let date: Date
        let predictedRisk: Int
        let actualHeadache: Bool?
        let confidence: Double
    }
    
    func recordPrediction(date: Date, risk: HeadacheRisk, confidence: Double) {
        var records = loadRecords()
        let record = PredictionRecord(
            date: date,
            predictedRisk: risk.rawValue,
            actualHeadache: nil,
            confidence: confidence
        )
        records.append(record)
        saveRecords(records)
    }
    
    func updateActualOutcome(date: Date, hadHeadache: Bool) {
        var records = loadRecords()
        if let index = records.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            let record = records[index]
            records[index] = PredictionRecord(
                date: record.date,
                predictedRisk: record.predictedRisk,
                actualHeadache: hadHeadache,
                confidence: record.confidence
            )
            saveRecords(records)
        }
    }
    
    func calculateAccuracy() -> Double {
        let records = loadRecords()
        let completedRecords = records.filter { $0.actualHeadache != nil }
        
        guard completedRecords.count >= 10 else { return 0 }
        
        let correct = completedRecords.filter { record in
            let predictedHeadache = record.predictedRisk >= 3 // High or Very High
            return predictedHeadache == record.actualHeadache
        }.count
        
        return Double(correct) / Double(completedRecords.count)
    }
    
    private func loadRecords() -> [PredictionRecord] {
        guard let data = userDefaults.data(forKey: accuracyKey) else { return [] }
        return (try? JSONDecoder().decode([PredictionRecord].self, from: data)) ?? []
    }
    
    private func saveRecords(_ records: [PredictionRecord]) {
        // 只保留最近90天的记录
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let recentRecords = records.filter { $0.date > cutoffDate }
        
        if let data = try? JSONEncoder().encode(recentRecords) {
            userDefaults.set(data, forKey: accuracyKey)
        }
    }
}
