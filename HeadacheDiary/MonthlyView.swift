//
//  MonthlyView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI
import CoreData

struct MonthlyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var showAdd = false
    @State private var selectedRecord: HeadacheRecord?
    @State private var refreshID = UUID()
    @State private var expandedMonths: Set<String> = [] // 追踪展开的月份
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedRecords, id: \.monthKey) { monthGroup in
                    Section {
                        // 月份标题 - 可点击展开/收起
                        MonthHeaderExpandable(
                            month: monthGroup.month,
                            count: monthGroup.records.count,
                            isExpanded: expandedMonths.contains(monthGroup.monthKey)
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if expandedMonths.contains(monthGroup.monthKey) {
                                    expandedMonths.remove(monthGroup.monthKey)
                                } else {
                                    expandedMonths.insert(monthGroup.monthKey)
                                }
                            }
                        }
                        
                        // 只有展开时才显示记录
                        if expandedMonths.contains(monthGroup.monthKey) {
                            ForEach(monthGroup.records, id: \.objectID) { record in
                                HeadacheRecordRow(record: record)
                                    .onTapGesture {
                                        selectedRecord = record
                                    }
                            }
                            .onDelete { offsets in
                                deleteItems(offsets: offsets, from: monthGroup.records)
                            }
                        }
                    }
                }
            }
            .id(refreshID)
            .refreshable {
                refreshID = UUID()
                viewContext.refreshAllObjects()
            }
            .navigationTitle("头痛日记")
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
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            refreshID = UUID()
                            viewContext.refreshAllObjects()
                        }
                    }
            }
            .sheet(item: $selectedRecord) { record in
                AddEntryView(editingRecord: record)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            refreshID = UUID()
                            viewContext.refreshAllObjects()
                        }
                        selectedRecord = nil
                    }
            }
            .onAppear {
                refreshID = UUID()
                // 默认展开当前月份
                let currentMonthKey = monthKeyForDate(Date())
                expandedMonths.insert(currentMonthKey)
            }
        }
    }
    
    private var groupedRecords: [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            guard let timestamp = record.timestamp else {
                return calendar.dateInterval(of: .month, for: Date())!.start
            }
            return calendar.dateInterval(of: .month, for: timestamp)!.start
        }
        
        return grouped.map { (month, records) in
            MonthGroup(month: month, records: Array(records), monthKey: monthKeyForDate(month))
        }.sorted { $0.month > $1.month }
    }
    
    private func monthKeyForDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    private func deleteItems(offsets: IndexSet, from records: [HeadacheRecord]) {
        withAnimation {
            offsets.map { records[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
                refreshID = UUID()
            } catch {
                let nsError = error as NSError
                print("删除失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct MonthGroup {
    let month: Date
    let records: [HeadacheRecord]
    let monthKey: String
}

// 可展开的月份标题
struct MonthHeaderExpandable: View {
    let month: Date
    let count: Int
    let isExpanded: Bool
    let onTap: () -> Void
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }
    
    private var headerColor: Color {
        switch count {
        case 0..<5:
            return .green
        case 5..<10:
            return .yellow
        case 10..<20:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption.bold())
                
                Text(monthFormatter.string(from: month))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(count)次")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(headerColor)
                        .clipShape(Capsule())
                    
                    Circle()
                        .fill(headerColor)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // 整个区域都可点击
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 头痛记录行组件
struct HeadacheRecordRow: View {
    @ObservedObject var record: HeadacheRecord
    @State private var refreshTrigger = UUID()
    
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
                if record.hasTinnitus {
                    SymptomTag(text: "耳鸣", color: .orange)
                }
                if record.hasThrobbing {
                    SymptomTag(text: "跳动", color: .purple)
                }
            }
            .id(refreshTrigger)
            
            // 备注
            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 持续时间 - 只有设置了结束时间才显示
            if let startTime = record.startTime, let endTime = record.endTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(durationText(from: startTime, to: endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let startTime = record.startTime, record.endTime == nil {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("进行中...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            DispatchQueue.main.async {
                refreshTrigger = UUID()
            }
        }
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

// 支持组件
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
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
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
    MonthlyView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
