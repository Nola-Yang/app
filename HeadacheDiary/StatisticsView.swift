//
//  StatisticsView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 总体统计
                    OverallStatsCard(records: Array(records))
                    
                    // 月度趋势
                    MonthlyTrendCard(records: Array(records))
                    
                    // 疼痛位置统计（包括自定义）
                    EnhancedLocationStatsCard(records: Array(records))
                    
                    // 触发因素统计（包括自定义）
                    EnhancedTriggerStatsCard(records: Array(records))
                    
                    // 用药效果统计（包括自定义）
                    EnhancedMedicineStatsCard(records: Array(records))
                    
                    // 症状统计（包括自定义）
                    SymptomsStatsCard(records: Array(records))
                    
                    // 备注分析
                    NotesAnalysisCard(records: Array(records))
                }
                .padding()
            }
            .navigationTitle("统计分析")
        }
    }
}

// 总体统计卡片
struct OverallStatsCard: View {
    let records: [HeadacheRecord]
    
    private var totalCount: Int {
        records.count
    }
    
    private var averageIntensity: Double {
        guard !records.isEmpty else { return 0 }
        let total = records.reduce(0) { $0 + Double($1.intensity) }
        return total / Double(records.count)
    }
    
    private var thisMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return calendar.isDate(timestamp, equalTo: now, toGranularity: .month)
        }.count
    }
    
    private var ongoingCount: Int {
        records.filter { $0.isOngoing }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("整体概况")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                StatItem(title: "总记录", value: "\(totalCount)次", color: .blue)
                StatItem(title: "平均强度", value: String(format: "%.1f", averageIntensity), color: .orange)
                StatItem(title: "本月", value: "\(thisMonthCount)次", color: monthColor(count: thisMonthCount))
                if ongoingCount > 0 {
                    StatItem(title: "进行中", value: "\(ongoingCount)次", color: .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func monthColor(count: Int) -> Color {
        switch count {
        case 0..<5: return .green
        case 5..<10: return .yellow
        case 10..<20: return .orange
        default: return .red
        }
    }
}

// 统计项组件
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 月度趋势卡片
struct MonthlyTrendCard: View {
    let records: [HeadacheRecord]
    
    private var monthlyData: [(String, Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        
        let grouped = Dictionary(grouping: records) { record in
            guard let timestamp = record.timestamp else { return Date() }
            return calendar.dateInterval(of: .month, for: timestamp)!.start
        }
        
        return grouped
            .map { (month, records) in (formatter.string(from: month), records.count) }
            .sorted { $0.0 < $1.0 }
            .suffix(6) // 显示最近6个月
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("近期趋势")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(monthlyData, id: \.0) { month, count in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(colorForCount(count))
                            .frame(width: 30, height: CGFloat(count * 5 + 20))
                            .cornerRadius(4)
                        
                        Text("\(count)")
                            .font(.caption2.bold())
                        
                        Text(month)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0..<5: return .green
        case 5..<10: return .yellow
        case 10..<20: return .orange
        default: return .red
        }
    }
}

// 增强的位置统计卡片（包括自定义位置）
struct EnhancedLocationStatsCard: View {
    let records: [HeadacheRecord]
    
    private var allLocationStats: [(String, Int)] {
        var stats: [String: Int] = [:]
        
        for record in records {
            // 预定义位置
            if record.locationForehead { stats["额头", default: 0] += 1 }
            if record.locationLeftSide { stats["左侧", default: 0] += 1 }
            if record.locationRightSide { stats["右侧", default: 0] += 1 }
            if record.locationTemple { stats["太阳穴", default: 0] += 1 }
            if record.locationFace { stats["面部", default: 0] += 1 }
            
            // 自定义位置
            for customLocation in record.customLocationNames {
                stats[customLocation, default: 0] += 1
            }
        }
        
        return stats.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("疼痛位置分布")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if allLocationStats.isEmpty {
                Text("暂无位置数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(allLocationStats, id: \.0) { location, count in
                    HStack {
                        Text(location)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(count)次")
                                .foregroundColor(.secondary)
                            
                            // 百分比显示
                            Text("(\(Int(Double(count) / Double(records.count) * 100))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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

// 增强的触发因素统计卡片（包括自定义）
struct EnhancedTriggerStatsCard: View {
    let records: [HeadacheRecord]
    
    private var allTriggerStats: [(String, Int, Bool)] {
        var stats: [String: Int] = [:]
        var isCustom: [String: Bool] = [:]
        
        for record in records {
            // 预定义触发因素
            for trigger in record.triggerObjects {
                stats[trigger.displayName, default: 0] += 1
                isCustom[trigger.displayName] = false
            }
            
            // 自定义触发因素
            for customTrigger in record.customTriggerNames {
                stats[customTrigger, default: 0] += 1
                isCustom[customTrigger] = true
            }
        }
        
        return stats.map { (name, count) in (name, count, isCustom[name] ?? false) }
            .sorted { $0.1 > $1.1 }
            .prefix(12)
            .map { ($0.0, $0.1, $0.2) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("触发因素分析")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if allTriggerStats.isEmpty {
                Text("暂无触发因素数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(allTriggerStats, id: \.0) { triggerName, count, isCustomTrigger in
                    HStack {
                        HStack(spacing: 8) {
                            if isCustomTrigger {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                            } else {
                                Image(systemName: getIconForTrigger(triggerName))
                                    .foregroundColor(getColorForTrigger(triggerName))
                                    .font(.caption)
                            }
                            Text(triggerName)
                                .foregroundColor(isCustomTrigger ? .purple : .primary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(count)次")
                                .foregroundColor(.secondary)
                            
                            Text("(\(Int(Double(count) / Double(records.count) * 100))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    private func getIconForTrigger(_ triggerName: String) -> String {
        // 简化版本的图标匹配，实际可以做更完整的映射
        switch triggerName {
        case "吹冷风": return "wind"
        case "睡眠不足": return "bed.double"
        case "社交活动": return "person.2"
        case "压力/焦虑": return "brain.head.profile"
        case "月经期": return "calendar.badge.clock"
        case "补剂漏服(CoQ10等)": return "pills.circle"
        default: return "exclamationmark.triangle"
        }
    }
    
    private func getColorForTrigger(_ triggerName: String) -> Color {
        switch triggerName {
        case "吹冷风": return .blue
        case "睡眠不足": return .purple
        case "社交活动": return .green
        case "压力/焦虑": return .red
        case "月经期": return .pink
        case "补剂漏服(CoQ10等)": return .teal
        default: return .orange
        }
    }
}


struct EnhancedMedicineStatsCard: View {
    let records: [HeadacheRecord]
    
    private var medicineStats: (
        totalEntries: Int,
        totalDosage: Double,
        averageDosage: Double,
        effectiveEntries: Int,
        effectivenessRate: Double,
        medicineBreakdown: [String: (count: Int, dosage: Double, effectiveness: Double)]
    ) {
        var totalEntries = 0
        var totalDosage: Double = 0
        var effectiveEntries = 0
        var medicineBreakdown: [String: (count: Int, dosage: Double, effectiveness: Int)] = [:]
        
        for record in records {
            let entries = record.medicationEntries
            
            for entry in entries {
                totalEntries += 1
                totalDosage += entry.dosage
                
                if entry.relief {
                    effectiveEntries += 1
                }
                
                let medicineName = entry.displayName
                let current = medicineBreakdown[medicineName] ?? (count: 0, dosage: 0, effectiveness: 0)
                medicineBreakdown[medicineName] = (
                    count: current.count + 1,
                    dosage: current.dosage + entry.dosage,
                    effectiveness: current.effectiveness + (entry.relief ? 1 : 0)
                )
            }
        }
        
        let averageDosage = totalEntries > 0 ? totalDosage / Double(totalEntries) : 0
        let effectivenessRate = totalEntries > 0 ? Double(effectiveEntries) / Double(totalEntries) * 100 : 0
        
        // 转换为最终格式
        let finalBreakdown = medicineBreakdown.mapValues { stats in
            let effectiveness = stats.count > 0 ? Double(stats.effectiveness) / Double(stats.count) * 100 : 0
            return (count: stats.count, dosage: stats.dosage, effectiveness: effectiveness)
        }
        
        return (
            totalEntries: totalEntries,
            totalDosage: totalDosage,
            averageDosage: averageDosage,
            effectiveEntries: effectiveEntries,
            effectivenessRate: effectivenessRate,
            medicineBreakdown: finalBreakdown
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("用药统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 总体用药统计
            HStack {
                MetricCard(
                    title: "总用药次数",
                    value: "\(medicineStats.totalEntries)",
                    subtitle: "次",
                    color: .blue
                )
                
                MetricCard(
                    title: "总剂量",
                    value: "\(Int(medicineStats.totalDosage))",
                    subtitle: "mg",
                    color: .purple
                )
                
                MetricCard(
                    title: "平均剂量",
                    value: "\(Int(medicineStats.averageDosage))",
                    subtitle: "mg/次",
                    color: .orange
                )
                
                MetricCard(
                    title: "有效率",
                    value: String(format: "%.0f%%", medicineStats.effectivenessRate),
                    subtitle: "缓解率",
                    color: .green
                )
            }
            
            // 按药物分组的详细统计
            if !medicineStats.medicineBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("各药物详细统计:")
                        .font(.subheadline.bold())
                    
                    ForEach(medicineStats.medicineBreakdown.sorted(by: { $0.value.count > $1.value.count }), id: \.key) { medicine, stats in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(medicine)
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(stats.count)次")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                HStack {
                                    Text("总剂量:")
                                    Text("\(Int(stats.dosage))mg")
                                        .foregroundColor(.purple)
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Text("平均:")
                                    Text("\(Int(stats.dosage / Double(stats.count)))mg")
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Text("有效率:")
                                    Text("\(Int(stats.effectiveness))%")
                                        .foregroundColor(stats.effectiveness >= 70 ? .green : stats.effectiveness >= 40 ? .orange : .red)
                                }
                            }
                            .font(.caption2)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
            
            // 用药趋势洞察
            if medicineStats.totalEntries >= 3 {
                MedicationInsightsView(records: records)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 用药洞察视图
struct MedicationInsightsView: View {
    let records: [HeadacheRecord]
    
    private var insights: [String] {
        var insights: [String] = []
        
        // 分析多次用药模式
        let multiMedicationRecords = records.filter { $0.medicationEntries.count > 1 }
        if !multiMedicationRecords.isEmpty {
            let rate = Double(multiMedicationRecords.count) / Double(records.count) * 100
            insights.append("有 \(Int(rate))% 的头痛需要多次用药")
        }
        
        // 分析高剂量使用
        let allEntries = records.flatMap { $0.medicationEntries }
        let highDosageEntries = allEntries.filter { $0.dosage > 600 }
        if !highDosageEntries.isEmpty {
            let rate = Double(highDosageEntries.count) / Double(allEntries.count) * 100
            insights.append("有 \(Int(rate))% 的用药使用了高剂量 (>600mg)")
        }
        
        // 分析药物切换效果
        let switchingRecords = records.filter { record in
            let entries = record.medicationEntries
            return entries.count > 1 && entries.first?.relief == false && entries.last?.relief == true
        }
        if !switchingRecords.isEmpty {
            insights.append("换药策略在 \(switchingRecords.count) 次头痛中有效")
        }
        
        return insights
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("用药洞察:")
                .font(.caption.bold())
            
            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .padding(.top, 1)
                    Text(insight)
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

// 更新的HeadacheRecordRow，显示增强的用药信息
extension HeadacheRecordRow {
    private var medicationSummary: String? {
        let entries = record.medicationEntries
        guard !entries.isEmpty else { return nil }
        
        if entries.count == 1 {
            let entry = entries[0]
            return "\(entry.displayName) \(entry.dosageText)\(entry.relief ? " ✓" : " ✗")"
        } else {
            let effectiveCount = entries.filter { $0.relief }.count
            let totalDosage = entries.reduce(0) { $0 + $1.dosage }
            return "\(entries.count)次用药，共\(Int(totalDosage))mg，\(effectiveCount)次有效"
        }
    }
    
    // 在body中的用药信息部分替换为：
    private var medicationInfoView: some View {
        Group {
            if let summary = medicationSummary {
                HStack {
                    Image(systemName: "pills")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 新增：详细的用药时间线视图
struct MedicationTimelineView: View {
    let record: HeadacheRecord
    
    private var entries: [MedicationEntry] {
        record.medicationEntries.sorted { $0.time < $1.time }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("用药时间线")
                .font(.headline)
            
            if entries.isEmpty {
                Text("未用药")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        // 时间线指示器
                        VStack {
                            Circle()
                                .fill(entry.relief ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            if index < entries.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2, height: 30)
                            }
                        }
                        
                        // 用药详情
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.time, formatter: timeOnlyFormatter)
                                    .font(.caption.bold())
                                Spacer()
                                Text(entry.dosageText)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Text(entry.displayName)
                                .font(.subheadline)
                            
                            if entry.relief {
                                if let reliefTime = entry.reliefTime {
                                    Text("缓解于 \(reliefTime, formatter: timeOnlyFormatter)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                } else {
                                    Text("有效缓解")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("未缓解")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, index < entries.count - 1 ? 8 : 0)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private let timeOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

// 在MonthlyView中使用MedicationTimelineView
extension MonthlyView {
    private func medicationDetailView(for record: HeadacheRecord) -> some View {
        MedicationTimelineView(record: record)
    }
}

// 新增：症状统计卡片
struct SymptomsStatsCard: View {
    let records: [HeadacheRecord]
    
    private var symptomStats: [(String, Int, Bool)] {
        var stats: [String: Int] = [:]
        var isCustom: [String: Bool] = [:]
        
        for record in records {
            // 预定义症状
            for symptom in record.symptomTags {
                stats[symptom, default: 0] += 1
                isCustom[symptom] = false
            }
            
            // 自定义症状
            for customSymptom in record.customSymptomNames {
                stats[customSymptom, default: 0] += 1
                isCustom[customSymptom] = true
            }
        }
        
        return stats.map { (name, count) in (name, count, isCustom[name] ?? false) }
            .sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("症状分析")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if symptomStats.isEmpty {
                Text("暂无症状数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(symptomStats, id: \.0) { symptomName, count, isCustomSymptom in
                    HStack {
                        HStack(spacing: 8) {
                            if isCustomSymptom {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.teal)
                                    .font(.caption)
                            } else {
                                Image(systemName: symptomName == "耳鸣" ? "ear" : "heart.pulse")
                                    .foregroundColor(symptomName == "耳鸣" ? .orange : .purple)
                                    .font(.caption)
                            }
                            Text(symptomName)
                                .foregroundColor(isCustomSymptom ? .teal : .primary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(count)次")
                                .foregroundColor(.secondary)
                            
                            Text("(\(Int(Double(count) / Double(records.count) * 100))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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

// 新增：备注分析卡片
struct NotesAnalysisCard: View {
    let records: [HeadacheRecord]
    
    private var noteStats: (hasNotes: Int, hasDetailedNotes: Int) {
        let hasNotesCount = records.filter { record in
            ![record.note, record.medicineNote, record.triggerNote, record.symptomNote, record.timeNote]
                .compactMap { $0 }.filter { !$0.isEmpty }.isEmpty
        }.count
        
        let hasDetailedNotesCount = records.filter { record in
            let noteCount = [record.note, record.medicineNote, record.triggerNote, record.symptomNote, record.timeNote]
                .compactMap { $0 }.filter { !$0.isEmpty }.count
            return noteCount >= 2
        }.count
        
        return (hasNotesCount, hasDetailedNotesCount)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("记录详细度")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack {
                    Text("\(noteStats.hasNotes)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                    Text("有备注记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(records.count > 0 ? "\(Int(Double(noteStats.hasNotes) / Double(records.count) * 100))%" : "0%")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("备注完整度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(noteStats.hasDetailedNotes)")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    Text("详细记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            
            Text("详细的备注有助于发现头痛模式和改善治疗效果")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    StatisticsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
