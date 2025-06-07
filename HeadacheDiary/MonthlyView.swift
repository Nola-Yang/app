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
    @State private var showQuickAdd = false  // 新增：快速记录
    @State private var selectedRecord: HeadacheRecord?
    @State private var refreshID = UUID()
    @State private var expandedMonths: Set<String> = [] // 追踪展开的月份
    @State private var showMedicationSafetyGuide = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 快速操作栏
                quickActionBar
                
                List {
                    // 用药警告部分 - 显示在顶部
                    if !Array(records).isEmpty {
                        Section {
                            MedicationWarningView(records: Array(records))
                                .onTapGesture {
                                    // 点击警告卡片时显示用药安全指南
                                    showMedicationSafetyGuide = true
                                }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    
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
                    Menu {
                        Button(action: { showAdd = true }) {
                            Label("详细记录", systemImage: "note.text.badge.plus")
                        }
                        Button(action: { showQuickAdd = true }) {
                            Label("快速记录轻微头痛", systemImage: "clock.badge")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
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
            .sheet(isPresented: $showQuickAdd) {
                QuickHeadacheEntryView()
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
            .sheet(isPresented: $showMedicationSafetyGuide) {
                MedicationSafetyGuideView()
            }
            .onAppear {
                refreshID = UUID()
                // 默认展开当前月份
                let currentMonthKey = monthKeyForDate(Date())
                expandedMonths.insert(currentMonthKey)
            }
        }
    }
    
    // 新增：快速操作栏
    @ViewBuilder
    private var quickActionBar: some View {
        HStack(spacing: 16) {
            // 快速记录按钮
            Button(action: { showQuickAdd = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge")
                        .font(.title3)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("快速记录")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                        Text("轻微头痛")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // 统计信息
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(todayCount)")
                        .font(.headline.bold())
                        .foregroundColor(todayCount > 0 ? .orange : .secondary)
                    Text("今天")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(thisWeekMildCount)")
                        .font(.headline.bold())
                        .foregroundColor(thisWeekMildCount > 3 ? .orange : thisWeekMildCount > 0 ? .green : .secondary)
                    Text("本周轻微")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(thisWeekCount)")
                        .font(.headline.bold())
                        .foregroundColor(thisWeekCount > 3 ? .red : thisWeekCount > 0 ? .orange : .secondary)
                    Text("本周总计")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(ongoingCount)")
                        .font(.headline.bold())
                        .foregroundColor(ongoingCount > 0 ? .red : .secondary)
                    Text("进行中")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // 统计计算属性
    private var todayCount: Int {
        let calendar = Calendar.current
        let today = Date()
        return records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: today)
        }.count
    }
    
    private var thisWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        return records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return timestamp >= weekAgo
        }.count
    }
    
    // 新增：本周轻微头痛次数
    private var thisWeekMildCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        return records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            let isThisWeek = timestamp >= weekAgo
            let isMild = record.intensity <= 3 || (record.note?.contains("快速记录") == true)
            return isThisWeek && isMild
        }.count
    }
    
    private var ongoingCount: Int {
        records.filter { $0.isOngoing }.count
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
                
                // 显示记录类型标识
                if record.note?.contains("快速记录") == true {
                    Text("快速")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                
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
            
            // 用药信息 - 更新为显示新的用药记录
            if !record.medicationEntries.isEmpty {
                medicationInfoView
            } else if record.tookMedicine {
                // 兼容旧的用药记录显示
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
            
            // 触发因素 - 更新显示新的触发因素
            if !allTriggers.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(allTriggers.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
                // 显示自定义症状中的若有若无
                if record.customSymptomNames.contains("若有若无") {
                    SymptomTag(text: "若有若无", color: .gray)
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
    
    // 新的用药信息视图
    @ViewBuilder
    private var medicationInfoView: some View {
        let entries = record.medicationEntries
        if entries.count == 1 {
            let entry = entries[0]
            HStack {
                Image(systemName: "pills")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("\(entry.displayName) \(entry.dosageText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if entry.relief {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        } else {
            let effectiveCount = entries.filter { $0.relief }.count
            let totalDosage = entries.reduce(0) { $0 + $1.dosage }
            HStack {
                Image(systemName: "pills")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("\(entries.count)次用药，共\(Int(totalDosage))mg")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if effectiveCount > 0 {
                    Text("(\(effectiveCount)次有效)")
                        .font(.caption)
                        .foregroundColor(effectiveCount == entries.count ? .green : .orange)
                }
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
    
    private var allTriggers: [String] {
        var triggers: [String] = []
        
        // 预定义触发因素
        if let triggersString = record.triggers {
            let triggerStrings = triggersString.components(separatedBy: ",")
            let triggerNames = triggerStrings.compactMap { triggerString in
                HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces))?.displayName
            }
            triggers.append(contentsOf: triggerNames)
        }
        
        // 自定义触发因素
        triggers.append(contentsOf: record.customTriggerNames)
        
        return triggers
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

struct TriggerTag: View {
    let trigger: HeadacheTrigger
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trigger.icon)
                .font(.caption2)
            Text(trigger.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(trigger.color).opacity(0.2))
        .foregroundColor(Color(trigger.color))
        .clipShape(Capsule())
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
