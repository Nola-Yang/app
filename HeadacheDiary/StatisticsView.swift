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
                    
                    // 常见位置
                    LocationStatsCard(records: Array(records))
                    
                    // 触发因素统计
                    TriggerStatsCard(records: Array(records))
                    
                    // 用药效果
                    MedicineStatsCard(records: Array(records))
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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("整体概况")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                StatItem(title: "总记录", value: "\(totalCount)次", color: .blue)
                StatItem(title: "平均强度", value: String(format: "%.1f", averageIntensity), color: .orange)
                StatItem(title: "本月", value: "\(thisMonthCount)次", color: monthColor(count: thisMonthCount))
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

// 位置统计卡片
struct LocationStatsCard: View {
    let records: [HeadacheRecord]
    
    private var locationStats: [(String, Int)] {
        var stats: [String: Int] = [:]
        
        for record in records {
            if record.locationForehead { stats["额头", default: 0] += 1 }
            if record.locationLeftSide { stats["左侧", default: 0] += 1 }
            if record.locationRightSide { stats["右侧", default: 0] += 1 }
            if record.locationTemple { stats["太阳穴", default: 0] += 1 }
            if record.locationFace { stats["面部", default: 0] += 1 }
        }
        
        return stats.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("常见位置")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(locationStats, id: \.0) { location, count in
                HStack {
                    Text(location)
                    Spacer()
                    Text("\(count)次")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 触发因素统计卡片
struct TriggerStatsCard: View {
    let records: [HeadacheRecord]
    
    private var triggerStats: [(HeadacheTrigger, Int)] {
        var stats: [HeadacheTrigger: Int] = [:]
        
        for record in records {
            guard let triggersString = record.triggers else { continue }
            let triggerStrings = triggersString.components(separatedBy: ",")
            for triggerString in triggerStrings {
                if let trigger = HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces)) {
                    stats[trigger, default: 0] += 1
                }
            }
        }
        
        return stats.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("常见触发因素")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if triggerStats.isEmpty {
                Text("暂无触发因素数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(triggerStats, id: \.0) { trigger, count in
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: trigger.icon)
                                .foregroundColor(Color(trigger.color))
                                .font(.caption)
                            Text(trigger.displayName)
                        }
                        Spacer()
                        Text("\(count)次")
                            .foregroundColor(.secondary)
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

// 用药统计卡片
struct MedicineStatsCard: View {
    let records: [HeadacheRecord]
    
    private var medicineStats: (total: Int, relief: Int, tylenol: Int, ibuprofen: Int) {
        let medicineRecords = records.filter { $0.tookMedicine }
        let reliefCount = medicineRecords.filter { $0.medicineRelief }.count
        let tylenolCount = medicineRecords.filter { $0.medicineType == MedicineType.tylenol.rawValue }.count
        let ibuprofenCount = medicineRecords.filter { $0.medicineType == MedicineType.ibuprofen.rawValue }.count
        
        return (medicineRecords.count, reliefCount, tylenolCount, ibuprofenCount)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("用药统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack {
                    Text("\(medicineStats.total)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                    Text("用药次数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(medicineStats.total > 0 ? "\(Int(Double(medicineStats.relief) / Double(medicineStats.total) * 100))%" : "0%")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("缓解率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            HStack {
                VStack {
                    Text("\(medicineStats.tylenol)")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    Text("泰诺")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(medicineStats.ibuprofen)")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                    Text("布洛芬")
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
}

#Preview {
    StatisticsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
