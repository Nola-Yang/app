//
//  WeatherService+EnhancedAnalysis.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//

import Foundation
import SwiftUI
import Combine

extension WeatherService {
    
    // MARK: - 增强的相关性分析
    
    func performEnhancedCorrelationAnalysis(
        with headacheRecords: [HeadacheRecord],
        minimumDataPoints: Int = 30
    ) -> EnhancedWeatherCorrelationResult {
        
        // 准备数据点
        let dataPoints = prepareEnhancedDataPoints(headacheRecords: headacheRecords)
        
        // 评估数据质量
        let dataQuality = assessDataQuality(dataPoints)
        
        guard dataQuality.overlappingDays >= minimumDataPoints else {
            return EnhancedWeatherCorrelationResult(
                correlations: [],
                dataQuality: dataQuality,
                analysisDate: Date(),
                insights: ["需要至少\(minimumDataPoints)天的数据才能进行可靠的相关性分析"]
            )
        }
        
        // 计算各种天气因素的相关性
        var correlations: [EnhancedWeatherCorrelation] = []
        
        for factor in WeatherFactor.allCases {
            if let correlation = calculateEnhancedCorrelation(
                for: factor,
                dataPoints: dataPoints
            ) {
                correlations.append(correlation)
            }
        }
        
        // 生成洞察
        let insights = generateCorrelationInsights(
            correlations: correlations,
            dataPoints: dataPoints
        )
        
        return EnhancedWeatherCorrelationResult(
            correlations: correlations.sorted { abs($0.correlation) > abs($1.correlation) },
            dataQuality: dataQuality,
            analysisDate: Date(),
            insights: insights
        )
    }
    
    private func prepareEnhancedDataPoints(
        headacheRecords: [HeadacheRecord]
    ) -> [HeadacheWeatherDataPoint] {
        
        var dataPoints: [HeadacheWeatherDataPoint] = []
        let calendar = Calendar.current
        
        // 获取最近90天的数据
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate)!
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            // 查找当天的头痛记录
            let dayRecords = headacheRecords.filter { record in
                guard let timestamp = record.timestamp else { return false }
                return timestamp >= dayStart && timestamp < dayEnd
            }
            
            // 查找当天的天气记录
            let weatherRecord = weatherHistory.first { weather in
                calendar.isDate(weather.date, inSameDayAs: currentDate)
            }
            
            // 创建数据点
            if let weather = weatherRecord {
                let features = createMLFeatures(from: weather, historicalData: dataPoints)
                
                let dataPoint = HeadacheWeatherDataPoint(
                    date: currentDate,
                    hadHeadache: !dayRecords.isEmpty,
                    headacheIntensity: dayRecords.first.map { Int($0.intensity) },
                    hasWeatherData: true,
                    weatherFeatures: features,
                    recordExists: true
                )
                
                dataPoints.append(dataPoint)
            } else {
                // 即使没有天气数据，也记录头痛信息
                let dataPoint = HeadacheWeatherDataPoint(
                    date: currentDate,
                    hadHeadache: !dayRecords.isEmpty,
                    headacheIntensity: dayRecords.first.map { Int($0.intensity) },
                    hasWeatherData: false,
                    weatherFeatures: createDefaultMLFeatures(),
                    recordExists: true
                )
                
                dataPoints.append(dataPoint)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dataPoints
    }
    
    private func createMLFeatures(
        from weather: WeatherRecord,
        historicalData: [HeadacheWeatherDataPoint]
    ) -> WeatherMLFeatures {
        
        // 计算24小时前的变化
        let yesterday = historicalData.last { dataPoint in
            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: weather.date)!
            return Calendar.current.isDate(dataPoint.date, inSameDayAs: dayBefore)
        }
        
        let humidityChange = yesterday?.hasWeatherData == true ?
            weather.humidity - yesterday!.weatherFeatures.humidity : 0
        
        // 计算衍生特征
        let apparentTemp = calculateApparentTemperature(
            temp: weather.temperature,
            humidity: weather.humidity,
            windSpeed: weather.windSpeed
        )
        
        let dewPoint = calculateDewPoint(
            temp: weather.temperature,
            humidity: weather.humidity
        )
        
        let pressureTrend = determinePressureTrend(change: weather.pressureChange)
        
        // 历史特征
        let recentHeadaches = historicalData.suffix(3).filter { $0.hadHeadache }
        let last7Days = historicalData.suffix(7)
        let avgIntensity = last7Days
            .compactMap { $0.headacheIntensity }
            .reduce(0, +) / max(last7Days.count, 1)
        
        return WeatherMLFeatures(
            temperature: weather.temperature,
            humidity: weather.humidity,
            pressure: weather.pressure,
            windSpeed: weather.windSpeed,
            uvIndex: Double(weather.uvIndex),
            temperatureChange24h: weather.temperatureChange,
            pressureChange24h: weather.pressureChange,
            humidityChange24h: humidityChange,
            apparentTemperature: apparentTemp,
            dewPoint: dewPoint,
            pressureTrend: pressureTrend,
            hourOfDay: Calendar.current.component(.hour, from: weather.date),
            dayOfWeek: Calendar.current.component(.weekday, from: weather.date),
            seasonalFactor: calculateSeasonalFactor(date: weather.date),
            headacheInLast3Days: !recentHeadaches.isEmpty,
            averageIntensityLast7Days: Double(avgIntensity),
            medicationUseLast7Days: 0 // 需要从头痛记录中计算
        )
    }
    
    private func createDefaultMLFeatures() -> WeatherMLFeatures {
        return WeatherMLFeatures(
            temperature: 20,
            humidity: 50,
            pressure: 1013,
            windSpeed: 10,
            uvIndex: 5,
            temperatureChange24h: 0,
            pressureChange24h: 0,
            humidityChange24h: 0,
            apparentTemperature: 20,
            dewPoint: 10,
            pressureTrend: .steady,
            hourOfDay: 12,
            dayOfWeek: 1,
            seasonalFactor: 0.5,
            headacheInLast3Days: false,
            averageIntensityLast7Days: 0,
            medicationUseLast7Days: 0
        )
    }
    
    private func calculateEnhancedCorrelation(
        for factor: WeatherFactor,
        dataPoints: [HeadacheWeatherDataPoint]
    ) -> EnhancedWeatherCorrelation? {
        
        let validData = dataPoints.filter { $0.hasWeatherData }
        guard validData.count >= 20 else { return nil }
        
        // 提取因素值
        let values: [Double] = validData.map { dataPoint in
            switch factor {
            case .temperature:
                return dataPoint.weatherFeatures.temperature
            case .temperatureChange:
                return dataPoint.weatherFeatures.temperatureChange24h
            case .pressure:
                return dataPoint.weatherFeatures.pressure
            case .pressureChange:
                return dataPoint.weatherFeatures.pressureChange24h
            case .humidity:
                return dataPoint.weatherFeatures.humidity
            case .windSpeed:
                return dataPoint.weatherFeatures.windSpeed
            case .uvIndex:
                return dataPoint.weatherFeatures.uvIndex
            case .precipitation:
                return 0 // 需要从天气记录中获取
            }
        }
        
        let headaches = validData.map { $0.hadHeadache ? 1.0 : 0.0 }
        
        // 计算相关系数
        let correlation = calculatePearsonCorrelation(values, headaches)
        let pValue = calculatePValue(correlation: correlation, sampleSize: validData.count)
        
        // 确定效应类型
        let effect = determineCorrelationEffect(
            factor: factor,
            values: values,
            headaches: headaches,
            correlation: correlation
        )
        
        // 计算置信度
        let confidence = calculateConfidence(
            correlation: correlation,
            pValue: pValue,
            sampleSize: validData.count
        )
        
        return EnhancedWeatherCorrelation(
            weatherFactor: factor,
            correlation: correlation,
            confidence: confidence,
            sampleSize: validData.count,
            pValue: pValue,
            effect: effect
        )
    }
    
    private func calculatePearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        
        return denominator == 0 ? 0 : numerator / denominator
    }
    
    private func calculatePValue(correlation: Double, sampleSize: Int) -> Double {
        guard sampleSize > 2 else { return 1.0 }
        
        // t统计量
        let t = correlation * sqrt(Double(sampleSize - 2)) / sqrt(1 - correlation * correlation)
        let df = Double(sampleSize - 2)
        
        // 使用近似方法计算p值
        let p = 2 * (1 - cumulativeNormalDistribution(abs(t) / sqrt(df)))
        return min(1.0, max(0.0, p))
    }
    
    private func cumulativeNormalDistribution(_ x: Double) -> Double {
        return 0.5 * (1 + erf(x / sqrt(2)))
    }
    
    private func erf(_ x: Double) -> Double {
        // 误差函数的近似计算
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911
        
        let sign = x >= 0 ? 1.0 : -1.0
        let x_abs = abs(x)
        
        let t = 1.0 / (1.0 + p * x_abs)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x_abs * x_abs)
        
        return sign * y
    }
    
    private func determineCorrelationEffect(
        factor: WeatherFactor,
        values: [Double],
        headaches: [Double],
        correlation: Double
    ) -> CorrelationEffect {
        
        // 对于某些因素，检查是否存在阈值效应
        switch factor {
        case .pressure:
            // 低压阈值效应
            let lowPressureThreshold = 1005.0
            let belowThreshold = zip(values, headaches).filter { $0.0 < lowPressureThreshold }
            let aboveThreshold = zip(values, headaches).filter { $0.0 >= lowPressureThreshold }
            
            if !belowThreshold.isEmpty && !aboveThreshold.isEmpty {
                let belowRate = belowThreshold.map { $0.1 }.reduce(0, +) / Double(belowThreshold.count)
                let aboveRate = aboveThreshold.map { $0.1 }.reduce(0, +) / Double(aboveThreshold.count)
                
                if belowRate > aboveRate * 1.5 {
                    return .threshold(value: lowPressureThreshold)
                }
            }
            
        case .humidity:
            // 高湿度阈值效应
            let highHumidityThreshold = 80.0
            let aboveThreshold = zip(values, headaches).filter { $0.0 > highHumidityThreshold }
            let belowThreshold = zip(values, headaches).filter { $0.0 <= highHumidityThreshold }
            
            if !aboveThreshold.isEmpty && !belowThreshold.isEmpty {
                let aboveRate = aboveThreshold.map { $0.1 }.reduce(0, +) / Double(aboveThreshold.count)
                let belowRate = belowThreshold.map { $0.1 }.reduce(0, +) / Double(belowThreshold.count)
                
                if aboveRate > belowRate * 1.5 {
                    return .threshold(value: highHumidityThreshold)
                }
            }
            
        case .temperature:
            // 温度可能有非线性关系（极端值）
            let extremeValues = values.filter { $0 < 5 || $0 > 35 }
            let normalValues = values.filter { $0 >= 5 && $0 <= 35 }
            
            if !extremeValues.isEmpty && !normalValues.isEmpty {
                let extremeIndices = values.enumerated().compactMap { $0.1 < 5 || $0.1 > 35 ? $0.0 : nil }
                let normalIndices = values.enumerated().compactMap { $0.1 >= 5 && $0.1 <= 35 ? $0.0 : nil }
                
                let extremeRate = extremeIndices.map { headaches[$0] }.reduce(0, +) / Double(extremeIndices.count)
                let normalRate = normalIndices.map { headaches[$0] }.reduce(0, +) / Double(normalIndices.count)
                
                if extremeRate > normalRate * 1.5 {
                    return .nonLinear
                }
            }
            
        default:
            break
        }
        
        // 默认基于相关系数判断
        if abs(correlation) < 0.1 {
            return .nonLinear
        } else if correlation > 0 {
            return .positive
        } else {
            return .negative
        }
    }
    
    private func calculateConfidence(
        correlation: Double,
        pValue: Double,
        sampleSize: Int
    ) -> Double {
        // 基于样本量的基础置信度
        let sampleConfidence = min(Double(sampleSize) / 50.0, 1.0)
        
        // 基于p值的置信度调整
        let pValueConfidence = 1.0 - pValue
        
        // 基于相关系数强度的调整
        let correlationStrength = abs(correlation)
        
        // 综合置信度
        return sampleConfidence * 0.4 + pValueConfidence * 0.4 + correlationStrength * 0.2
    }
    
    private func assessDataQuality(_ dataPoints: [HeadacheWeatherDataPoint]) -> DataQualityMetrics {
        let totalDays = dataPoints.count
        let weatherDays = dataPoints.filter { $0.hasWeatherData }.count
        let headacheDays = dataPoints.filter { $0.hadHeadache }.count
        let overlappingDays = dataPoints.filter { $0.hasWeatherData && $0.recordExists }.count
        
        let coverage = totalDays > 0 ? Double(overlappingDays) / Double(totalDays) : 0
        let consistency = calculateDataConsistency(dataPoints)
        
        return DataQualityMetrics(
            totalDays: totalDays,
            weatherRecordDays: weatherDays,
            headacheRecordDays: headacheDays,
            overlappingDays: overlappingDays,
            coveragePercentage: coverage,
            consistency: consistency
        )
    }
    
    private func calculateDataConsistency(_ data: [HeadacheWeatherDataPoint]) -> Double {
        guard data.count > 7 else { return 0.5 }
        
        // 检查数据连续性
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
        return max(0, 1.0 - (averageGap / 7.0))
    }
    
    private func generateCorrelationInsights(
        correlations: [EnhancedWeatherCorrelation],
        dataPoints: [HeadacheWeatherDataPoint]
    ) -> [String] {
        
        var insights: [String] = []
        
        // 找出最强相关性
        let significantCorrelations = correlations.filter { $0.isSignificant }
        
        if let strongest = significantCorrelations.first {
            let direction = strongest.correlation > 0 ? "增加" : "降低"
            insights.append("\(strongest.weatherFactor.rawValue)\(direction)与头痛风险显著相关（相关系数: \(String(format: "%.2f", strongest.correlation))）")
        }
        
        // 阈值效应洞察
        for correlation in significantCorrelations {
            if case .threshold(let value) = correlation.effect {
                insights.append("\(correlation.weatherFactor.rawValue)超过\(Int(value))\(correlation.weatherFactor.unit)时头痛风险显著增加")
            }
        }
        
        // 非线性关系洞察
        let nonLinearFactors = correlations.filter {
            if case .nonLinear = $0.effect { return true }
            return false
        }
        
        if !nonLinearFactors.isEmpty {
            let factorNames = nonLinearFactors.map { $0.weatherFactor.rawValue }.joined(separator: "、")
            insights.append("\(factorNames)与头痛的关系较为复杂，可能存在极端值效应")
        }
        
        // 数据质量洞察
        let quality = assessDataQuality(dataPoints)
        if quality.overlappingDays < 30 {
            insights.append("数据量尚不充足，建议继续记录以提高分析准确性")
        } else if quality.coveragePercentage < 0.7 {
            insights.append("数据覆盖率较低，建议保持每日记录习惯")
        }
        
        // 季节性洞察
        if dataPoints.count >= 60 {
            let seasonalPattern = analyzeSeasonalPattern(dataPoints)
            if let pattern = seasonalPattern {
                insights.append(pattern)
            }
        }
        
        return insights
    }
    
    private func analyzeSeasonalPattern(_ dataPoints: [HeadacheWeatherDataPoint]) -> String? {
        let calendar = Calendar.current
        var seasonalCounts: [Int: (headaches: Int, total: Int)] = [:]
        
        for dataPoint in dataPoints {
            let month = calendar.component(.month, from: dataPoint.date)
            let season: Int
            switch month {
            case 12, 1, 2: season = 0 // 冬季
            case 3, 4, 5: season = 1 // 春季
            case 6, 7, 8: season = 2 // 夏季
            case 9, 10, 11: season = 3 // 秋季
            default: continue
            }
            
            let current = seasonalCounts[season] ?? (0, 0)
            seasonalCounts[season] = (
                current.headaches + (dataPoint.hadHeadache ? 1 : 0),
                current.total + 1
            )
        }
        
        // 计算各季节头痛率
        let seasonNames = ["冬季", "春季", "夏季", "秋季"]
        var seasonalRates: [(season: String, rate: Double)] = []
        
        for (season, counts) in seasonalCounts {
            if counts.total >= 10 {
                let rate = Double(counts.headaches) / Double(counts.total)
                seasonalRates.append((seasonNames[season], rate))
            }
        }
        
        guard !seasonalRates.isEmpty else { return nil }
        
        // 找出头痛率最高的季节
        if let highest = seasonalRates.max(by: { $0.rate < $1.rate }) {
            let average = seasonalRates.map { $0.rate }.reduce(0, +) / Double(seasonalRates.count)
            if highest.rate > average * 1.3 {
                return "\(highest.season)头痛发生率较高（\(Int(highest.rate * 100))%），建议在该季节加强预防"
            }
        }
        
        return nil
    }
    
    private func calculateApparentTemperature(
        temp: Double,
        humidity: Double,
        windSpeed: Double
    ) -> Double {
        // 热指数计算（高温时）
        if temp >= 27 && humidity >= 40 {
            let heatIndex = -8.78469475556 + 1.61139411 * temp + 2.33854883889 * humidity
                - 0.14611605 * temp * humidity - 0.012308094 * temp * temp
                - 0.0164248277778 * humidity * humidity + 0.002211732 * temp * temp * humidity
                + 0.00072546 * temp * humidity * humidity - 0.000003582 * temp * temp * humidity * humidity
            return heatIndex
        }
        // 风寒指数计算（低温时）
        else if temp <= 10 && windSpeed > 4.8 {
            let windChill = 13.12 + 0.6215 * temp - 11.37 * pow(windSpeed * 0.277778, 0.16)
                + 0.3965 * temp * pow(windSpeed * 0.277778, 0.16)
            return windChill
        }
        
        return temp
    }
    
    private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        let alpha = ((a * temp) / (b + temp)) + log(humidity / 100.0)
        return (b * alpha) / (a - alpha)
    }
    
    private func determinePressureTrend(change: Double) -> PressureTrend {
        if change > 3 {
            return .rapidlyRising
        } else if change > 1 {
            return .rising
        } else if change < -3 {
            return .rapidlyFalling
        } else if change < -1 {
            return .falling
        } else {
            return .steady
        }
    }
    
    private func calculateSeasonalFactor(date: Date) -> Double {
        let month = Calendar.current.component(.month, from: date)
        // 返回0-1的季节因子，冬季较高
        switch month {
        case 12, 1, 2: return 0.8 // 冬季
        case 3, 4, 5: return 0.6 // 春季
        case 6, 7, 8: return 0.3 // 夏季
        case 9, 10, 11: return 0.7 // 秋季
        default: return 0.5
        }
    }
}

// MARK: - 增强的相关性分析结果
struct EnhancedWeatherCorrelationResult {
    let correlations: [EnhancedWeatherCorrelation]
    let dataQuality: DataQualityMetrics
    let analysisDate: Date
    let insights: [String]
    
    var hasSignificantCorrelations: Bool {
        correlations.contains { $0.isSignificant }
    }
    
    var strongestCorrelation: EnhancedWeatherCorrelation? {
        correlations.filter { $0.isSignificant }
            .max { abs($0.correlation) < abs($1.correlation) }
    }
    
    var summary: String {
        if correlations.isEmpty {
            return "数据不足，无法进行相关性分析"
        } else if !hasSignificantCorrelations {
            return "未发现显著的天气相关性，可能需要更多数据"
        } else {
            let count = correlations.filter { $0.isSignificant }.count
            return "发现\(count)个显著的天气相关因素"
        }
    }
}
