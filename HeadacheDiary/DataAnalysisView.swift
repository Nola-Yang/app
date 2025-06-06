//
//  DataAnalysisView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import SwiftUI
import CoreData

struct DataAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var selectedTimeRange: TimeRange = .lastMonth
    @State private var showDetailedReport = false
    
    enum TimeRange: String, CaseIterable {
        case lastWeek = "最近一周"
        case lastMonth = "最近一月"
        case last3Months = "最近三月"
        case lastYear = "最近一年"
        case allTime = "全部时间"
        
        var days: Int {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .last3Months: return 90
            case .lastYear: return 365
            case .allTime: return Int.max
            }
        }
    }
    
    private var filteredRecords: [HeadacheRecord] {
        if selectedTimeRange == .allTime {
            return Array(records)
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return timestamp >= cutoffDate
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 时间范围选择器
                TimeRangePicker(selectedRange: $selectedTimeRange)
                
                // 核心指标
                CoreMetricsCard(records: filteredRecords)
                
                // 频率趋势分析
                FrequencyTrendCard(records: filteredRecords, timeRange: selectedTimeRange)
                
                // 强度分布分析
                IntensityDistributionCard(records: filteredRecords)
                
                // 触发因素关联分析
                TriggerCorrelationCard(records: filteredRecords)
                
                // 用药效果分析
                MedicationEffectivenessCard(records: filteredRecords)
                
                // 时间模式分析
                TimePatternCard(records: filteredRecords)
                
                // 个人化洞察
                PersonalInsightsCard(records: filteredRecords)
                
                // 生成详细报告按钮
                Button(action: { showDetailedReport = true }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("生成详细报告")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("高级分析")
        .sheet(isPresented: $showDetailedReport) {
            DetailedReportView(records: filteredRecords, timeRange: selectedTimeRange)
        }
    }
}

// 时间范围选择器
struct TimeRangePicker: View {
    @Binding var selectedRange: DataAnalysisView.TimeRange
    
    var body: some View {
        VStack(spacing: 12) {
            Text("分析时间范围")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DataAnalysisView.TimeRange.allCases, id: \.self) { range in
                        Button(action: { selectedRange = range }) {
                            Text(range.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedRange == range ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedRange == range ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 核心指标卡片
struct CoreMetricsCard: View {
    let records: [HeadacheRecord]
    
    private var averageIntensity: Double {
        guard !records.isEmpty else { return 0 }
        return Double(records.reduce(0) { $0 + $1.intensity }) / Double(records.count)
    }
    
    private var averageDuration: Double {
        let recordsWithDuration = records.filter { $0.durationText != nil }
        guard !recordsWithDuration.isEmpty else { return 0 }
        
        let totalMinutes = recordsWithDuration.compactMap { record -> Double? in
            guard let start = record.startTime, let end = record.endTime else { return nil }
            return end.timeIntervalSince(start) / 60.0
        }.reduce(0, +)
        
        return totalMinutes / Double(recordsWithDuration.count)
    }
    
    private var medicationSuccessRate: Double {
        let medicatedRecords = records.filter { $0.tookMedicine }
        guard !medicatedRecords.isEmpty else { return 0 }
        let successCount = medicatedRecords.filter { $0.medicineRelief }.count
        return Double(successCount) / Double(medicatedRecords.count) * 100
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("核心指标")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                MetricCard(
                    title: "平均强度",
                    value: String(format: "%.1f", averageIntensity),
                    subtitle: "1-10级",
                    color: intensityColor(averageIntensity)
                )
                
                MetricCard(
                    title: "平均持续",
                    value: durationText(averageDuration),
                    subtitle: "小时",
                    color: .blue
                )
                
                MetricCard(
                    title: "用药缓解率",
                    value: String(format: "%.0f%%", medicationSuccessRate),
                    subtitle: "有效性",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func intensityColor(_ intensity: Double) -> Color {
        switch intensity {
        case 0..<3: return .green
        case 3..<6: return .yellow
        case 6..<8: return .orange
        default: return .red
        }
    }
    
    private func durationText(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return "\(hours)h\(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct MetricCard: View {
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
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// 频率趋势分析
struct FrequencyTrendCard: View {
    let records: [HeadacheRecord]
    let timeRange: DataAnalysisView.TimeRange
    
    var body: some View {
        VStack(spacing: 12) {
            Text("频率趋势")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if records.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                FrequencyChart(records: records, timeRange: timeRange)
            }
            
            HStack {
                VStack {
                    Text("\(records.count)")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                    Text("总次数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(String(format: "%.1f", averagePerWeek))
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    Text("次/周")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(trendDirection)
                        .font(.title3.bold())
                        .foregroundColor(trendColor)
                    Text("趋势")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var averagePerWeek: Double {
        guard !records.isEmpty, timeRange.days > 0 else { return 0 }
        let weeks = Double(min(timeRange.days, 365)) / 7.0
        return Double(records.count) / weeks
    }
    
    private var trendDirection: String {
        guard records.count > 1 else { return "—" }
        
        let sortedRecords = records.sorted { record1, record2 in
            (record1.timestamp ?? Date.distantPast) < (record2.timestamp ?? Date.distantPast)
        }
        
        let midPoint = sortedRecords.count / 2
        let firstHalf = Array(sortedRecords[0..<midPoint])
        let secondHalf = Array(sortedRecords[midPoint...])
        
        let firstHalfAverage = Double(firstHalf.count)
        let secondHalfAverage = Double(secondHalf.count)
        
        if secondHalfAverage > firstHalfAverage * 1.2 {
            return "↗"
        } else if secondHalfAverage < firstHalfAverage * 0.8 {
            return "↘"
        } else {
            return "→"
        }
    }
    
    private var trendColor: Color {
        switch trendDirection {
        case "↗": return .red
        case "↘": return .green
        default: return .blue
        }
    }
}

// 简化的频率图表
struct FrequencyChart: View {
    let records: [HeadacheRecord]
    let timeRange: DataAnalysisView.TimeRange
    
    private var chartData: [(String, Int)] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .lastWeek:
            return (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                let dayName = DateFormatter().shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                let count = records.filter { record in
                    guard let timestamp = record.timestamp else { return false }
                    return calendar.isDate(timestamp, inSameDayAs: date)
                }.count
                return (dayName, count)
            }.reversed()
            
        case .lastMonth:
            return (0..<4).map { weekOffset in
                let startOfWeek = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now)!
                let count = records.filter { record in
                    guard let timestamp = record.timestamp else { return false }
                    let weekAgo = calendar.date(byAdding: .weekOfYear, value: -weekOffset-1, to: now)!
                    return timestamp >= weekAgo && timestamp < startOfWeek
                }.count
                return ("W\(4-weekOffset)", count)
            }.reversed()
            
        default:
            let months = min(timeRange.days / 30, 12)
            return (0..<months).map { monthOffset in
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
                let monthName = DateFormatter().shortMonthSymbols[calendar.component(.month, from: date) - 1]
                let count = records.filter { record in
                    guard let timestamp = record.timestamp else { return false }
                    return calendar.isDate(timestamp, equalTo: date, toGranularity: .month)
                }.count
                return (monthName, count)
            }.reversed()
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(chartData, id: \.0) { label, count in
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 25, height: max(CGFloat(count * 8), 4))
                        .cornerRadius(4)
                    
                    Text("\(count)")
                        .font(.caption2.bold())
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 120)
    }
}

// 强度分布分析
struct IntensityDistributionCard: View {
    let records: [HeadacheRecord]
    
    private var intensityDistribution: [Int: Int] {
        var distribution: [Int: Int] = [:]
        for i in 1...10 {
            distribution[i] = 0
        }
        
        for record in records {
            let intensity = Int(record.intensity)
            distribution[intensity] = (distribution[intensity] ?? 0) + 1
        }
        
        return distribution
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("强度分布")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(1...10, id: \.self) { intensity in
                    let count = intensityDistribution[intensity] ?? 0
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(intensityColor(intensity))
                            .frame(width: 20, height: max(CGFloat(count * 10), 2))
                            .cornerRadius(2)
                        
                        Text("\(intensity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 80)
            
            HStack {
                IntensityRangeStat(range: "轻度 (1-3)", count: (1...3).reduce(0) { $0 + (intensityDistribution[$1] ?? 0) }, color: .green)
                IntensityRangeStat(range: "中度 (4-6)", count: (4...6).reduce(0) { $0 + (intensityDistribution[$1] ?? 0) }, color: .yellow)
                IntensityRangeStat(range: "重度 (7-10)", count: (7...10).reduce(0) { $0 + (intensityDistribution[$1] ?? 0) }, color: .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func intensityColor(_ intensity: Int) -> Color {
        switch intensity {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }
}

struct IntensityRangeStat: View {
    let range: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(range)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// 触发因素关联分析
struct TriggerCorrelationCard: View {
    let records: [HeadacheRecord]
    
    private var triggerIntensityCorrelation: [(String, Double)] {
        var triggerIntensities: [String: [Int]] = [:]
        
        for record in records {
            let intensity = Int(record.intensity)
            
            // 预定义触发因素
            for trigger in record.triggerObjects {
                triggerIntensities[trigger.displayName, default: []].append(intensity)
            }
            
            // 自定义触发因素
            for trigger in record.customTriggerNames {
                triggerIntensities[trigger, default: []].append(intensity)
            }
        }
        
        return triggerIntensities.compactMap { trigger, intensities in
            guard intensities.count >= 2 else { return nil }
            let averageIntensity = Double(intensities.reduce(0, +)) / Double(intensities.count)
            return (trigger, averageIntensity)
        }.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("触发因素关联分析")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if triggerIntensityCorrelation.isEmpty {
                Text("需要更多数据来分析触发因素关联性")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    Text("高强度头痛相关触发因素 (前5位)")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(triggerIntensityCorrelation, id: \.0) { trigger, averageIntensity in
                        HStack {
                            Text(trigger)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", averageIntensity))
                                .font(.caption.bold())
                                .foregroundColor(intensityColor(averageIntensity))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func intensityColor(_ intensity: Double) -> Color {
        switch intensity {
        case 0..<3: return .green
        case 3..<6: return .yellow
        case 6..<8: return .orange
        default: return .red
        }
    }
}

// 用药效果分析
struct MedicationEffectivenessCard: View {
    let records: [HeadacheRecord]
    
    private var medicationStats: [(String, Int, Int, Double)] {
        var medicineEffectiveness: [String: (total: Int, successful: Int)] = [:]
        
        for record in records.filter({ $0.tookMedicine }) {
            // 预定义药物
            if let medicineName = record.medicineName {
                let current = medicineEffectiveness[medicineName] ?? (0, 0)
                medicineEffectiveness[medicineName] = (
                    current.total + 1,
                    current.successful + (record.medicineRelief ? 1 : 0)
                )
            }
            
            // 自定义药物
            for medicine in record.customMedicineNames {
                let current = medicineEffectiveness[medicine] ?? (0, 0)
                medicineEffectiveness[medicine] = (
                    current.total + 1,
                    current.successful + (record.medicineRelief ? 1 : 0)
                )
            }
        }
        
        return medicineEffectiveness.compactMap { medicine, stats in
            guard stats.total >= 2 else { return nil }
            let effectiveness = Double(stats.successful) / Double(stats.total) * 100
            return (medicine, stats.total, stats.successful, effectiveness)
        }.sorted { $0.3 > $1.3 }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("用药效果分析")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if medicationStats.isEmpty {
                Text("需要更多用药数据来分析效果")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(medicationStats, id: \.0) { medicine, total, successful, effectiveness in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(medicine)
                                .font(.caption.bold())
                            Text("使用\(total)次，成功\(successful)次")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", effectiveness))
                            .font(.caption.bold())
                            .foregroundColor(effectivenessColor(effectiveness))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func effectivenessColor(_ effectiveness: Double) -> Color {
        switch effectiveness {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// 时间模式分析
struct TimePatternCard: View {
    let records: [HeadacheRecord]
    
    private var hourlyDistribution: [Int: Int] {
        var distribution: [Int: Int] = [:]
        
        for record in records {
            guard let timestamp = record.timestamp else { continue }
            let hour = Calendar.current.component(.hour, from: timestamp)
            distribution[hour, default: 0] += 1
        }
        
        return distribution
    }
    
    private var weekdayDistribution: [Int: Int] {
        var distribution: [Int: Int] = [:]
        
        for record in records {
            guard let timestamp = record.timestamp else { continue }
            let weekday = Calendar.current.component(.weekday, from: timestamp)
            distribution[weekday, default: 0] += 1
        }
        
        return distribution
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("时间模式分析")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("高发时段:")
                    .font(.subheadline.bold())
                
                if let peakHour = hourlyDistribution.max(by: { $0.value < $1.value }) {
                    Text("• \(timeRange(for: peakHour.key)) - \(peakHour.value)次")
                        .font(.caption)
                }
                
                Text("高发星期:")
                    .font(.subheadline.bold())
                
                if let peakWeekday = weekdayDistribution.max(by: { $0.value < $1.value }) {
                    Text("• \(weekdayName(for: peakWeekday.key)) - \(peakWeekday.value)次")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func timeRange(for hour: Int) -> String {
        switch hour {
        case 0..<6: return "深夜 (0-6点)"
        case 6..<12: return "上午 (6-12点)"
        case 12..<18: return "下午 (12-18点)"
        default: return "晚上 (18-24点)"
        }
    }
    
    private func weekdayName(for weekday: Int) -> String {
        let weekdayNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return weekdayNames[weekday]
    }
}

// 个人化洞察卡片
struct PersonalInsightsCard: View {
    let records: [HeadacheRecord]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("个人化洞察")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                if records.count >= 10 {
                    if let insights = generateInsights() {
                        ForEach(insights, id: \.self) { insight in
                            HStack(alignment: .top) {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(insight)
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    Text("记录更多头痛数据后，系统将为您提供个性化洞察")
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
    
    private func generateInsights() -> [String]? {
        guard records.count >= 10 else { return nil }
        
        var insights: [String] = []
        
        // 分析平均强度
        let averageIntensity = Double(records.reduce(0) { $0 + $1.intensity }) / Double(records.count)
        if averageIntensity > 7 {
            insights.append("您的头痛强度偏高，建议咨询医生制定更有效的治疗方案")
        } else if averageIntensity < 4 {
            insights.append("您的头痛强度相对较轻，当前的管理方法效果良好")
        }
        
        // 分析用药效果
        let medicatedRecords = records.filter { $0.tookMedicine }
        if !medicatedRecords.isEmpty {
            let successRate = Double(medicatedRecords.filter { $0.medicineRelief }.count) / Double(medicatedRecords.count)
            if successRate < 0.6 {
                insights.append("当前用药缓解率较低，可考虑调整用药方案或咨询医生")
            } else if successRate > 0.8 {
                insights.append("您的用药效果很好，继续保持当前的用药策略")
            }
        }
        
        // 分析频率趋势
        if records.count > 20 {
            let recentRecords = records.prefix(10)
            let olderRecords = records.suffix(10)
            
            if recentRecords.count > olderRecords.count * 1.5 {
                insights.append("最近头痛频率有所增加，注意观察新的触发因素")
            } else if recentRecords.count < olderRecords.count * 0.7 {
                insights.append("头痛频率在减少，您的管理策略很有效")
            }
        }
        
        return insights.isEmpty ? nil : insights
    }
}

// 详细报告视图
struct DetailedReportView: View {
    let records: [HeadacheRecord]
    let timeRange: DataAnalysisView.TimeRange
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("头痛分析报告")
                        .font(.title.bold())
                    
                    Text("分析期间: \(timeRange.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("报告生成时间: \(Date().formatted(date: .complete, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // 这里可以添加更详细的报告内容
                    Text("详细分析内容将在此显示...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 50)
                }
                .padding()
            }
            .navigationTitle("详细报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("分享") {
                        // 实现分享功能
                    }
                }
            }
        }
    }
}

#Preview {
    DataAnalysisView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
