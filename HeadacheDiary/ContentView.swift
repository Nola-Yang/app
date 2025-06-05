//
//  ContentView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            ListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("列表")
                }
            
            MonthlyView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("月份")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("统计")
                }
        }
    }
}

struct ListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var showAdd = false
    @State private var selectedRecord: HeadacheRecord?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(records) { record in
                    HeadacheRecordRow(record: record)
                        .onTapGesture {
                            selectedRecord = record
                        }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("全部记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedRecord) { record in
                AddEntryView(editingRecord: record)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { records[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

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
                    
                    // 用药效果
                    MedicineStatsCard(records: Array(records))
                }
                .padding()
            }
            .navigationTitle("统计分析")
        }
    }
}

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

// 保留原有的HeadacheRecordRow
struct HeadacheRecordRow: View {
    let record: HeadacheRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 时间和强度
            HStack {
                if let date = record.timestamp {
                    Text(date, formatter: itemFormatter)
                        .font(.headline)
                }
                Spacer()
                IntensityBadge(intensity: Int(record.intensity))
            }
            
            // 疼痛位置
            if !selectedLocations.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(selectedLocations.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 用药信息
            if record.tookMedicine {
                HStack {
                    Image(systemName: "pills")
                        .foregroundColor(.green)
                        .font(.caption)
                    if let medicineType = record.medicineType {
                        let medicine = MedicineType(rawValue: medicineType)
                        Text(medicine?.displayName ?? "未知药物")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if record.medicineRelief {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            
            // 症状标签
            HStack {
                if record.isVascular {
                    SymptomTag(text: "血管性", color: .red)
                }
                if record.hasTinnitus {
                    SymptomTag(text: "耳鸣", color: .orange)
                }
                if record.hasThrobbing {
                    SymptomTag(text: "跳动", color: .purple)
                }
            }
            
            // 备注
            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 持续时间
            if let startTime = record.startTime, let endTime = record.endTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(durationText(from: startTime, to: endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var selectedLocations: [String] {
        var locations: [String] = []
        if record.locationForehead { locations.append("额头") }
        if record.locationLeftSide { locations.append("左侧") }
        if record.locationRightSide { locations.append("右侧") }
        if record.locationTemple { locations.append("太阳穴") }
        if record.locationFace { locations.append("面部") }
        return locations
    }
    
    private func durationText(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

struct IntensityBadge: View {
    let intensity: Int
    
    var body: some View {
        Text("\(intensity)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(intensityColor)
            .clipShape(Circle())
    }
    
    private var intensityColor: Color {
        switch intensity {
        case 1...3:
            return .green
        case 4...6:
            return .yellow
        case 7...8:
            return .orange
        case 9...10:
            return .red
        default:
            return .gray
        }
    }
}

struct SymptomTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
