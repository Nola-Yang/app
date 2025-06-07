//
//  QuickHeadacheEntryView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-06.
//


import SwiftUI
import CoreData

struct QuickHeadacheEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // 选择状态
    @State private var selectedTrigger: HeadacheTrigger = .noObviousCause  // 默认无明显原因
    @State private var selectedLocations: Set<HeadacheLocation> = []
    @State private var quickNote = ""
    
    // 保存状态
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 编辑模式状态
    @State private var existingRecord: HeadacheRecord?
    @State private var isEditMode = false
    
    // 固定的默认值 - 以天为单位，使用今天的开始时间
    private var todayTimestamp: Date {
        Calendar.current.startOfDay(for: Date())
    }
    private let defaultIntensity: Int16 = 2  // 固定轻微强度
    
    // 快速选择的触发因素选项
    private let quickTriggers: [HeadacheTrigger] = [
        .noObviousCause, .sleepDeprivation, .stress, .weather,
        .screenTime, .hunger, .dehydration, .caffeine
    ]
    
    // 常见的位置选项
    private let quickLocations: [HeadacheLocation] = [
        .forehead, .temple, .leftSide, .rightSide, .face
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题和说明
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: isEditMode ? "pencil.circle" : "clock.badge")
                                .foregroundColor(.orange)
                                .font(.title)
                            Text(isEditMode ? "编辑快速记录" : "快速记录")
                                .font(.title2.bold())
                        }
                        
                        VStack(spacing: 6) {
                            Text(isEditMode ? "修改今天的轻微头痛记录" : "记录今天的轻微头痛")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("强度2级 • 若有若无症状")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // 显示编辑模式提示
                            if isEditMode {
                                Text("今天已有记录，点击保存将更新现有记录")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    
                    VStack(spacing: 20) {
                        // 疼痛位置选择
                        GroupBox {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(quickLocations, id: \.self) { location in
                                    QuickLocationButton(
                                        location: location,
                                        isSelected: selectedLocations.contains(location)
                                    ) {
                                        if selectedLocations.contains(location) {
                                            selectedLocations.remove(location)
                                        } else {
                                            selectedLocations.insert(location)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("疼痛位置 (可选)", systemImage: "location")
                                .foregroundColor(.blue)
                        }
                        
                        // 触发因素选择
                        GroupBox {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(quickTriggers, id: \.self) { trigger in
                                    QuickTriggerButton(
                                        trigger: trigger,
                                        isSelected: selectedTrigger == trigger
                                    ) {
                                        selectedTrigger = trigger
                                    }
                                }
                            }
                        } label: {
                            Label("可能原因", systemImage: "questionmark.circle")
                                .foregroundColor(.gray)
                        }
                        
                        // 备注输入
                        GroupBox {
                            TextField("补充说明 (可选)", text: $quickNote, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } label: {
                            Label("备注", systemImage: "note.text")
                                .foregroundColor(.green)
                        }
                        
                        // 保存按钮
                        Button(action: saveQuickEntry) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("保存中...")
                                } else {
                                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                                    Text(isEditMode ? "更新今天的记录" : "保存今天的记录")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)
                        
                        // 删除按钮（仅编辑模式显示）
                        if isEditMode {
                            Button(action: deleteQuickEntry) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("删除今天的记录")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isSaving)
                        }
                        
                        // 提示信息
                        Text("记录日期：\(formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle(isEditMode ? "编辑快速记录" : "快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                checkForExistingQuickRecord()
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: todayTimestamp)
    }
    
    // 检查今天是否已有快速记录
    private func checkForExistingQuickRecord() {
        let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
        
        // 查找今天的快速记录
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@ AND note CONTAINS[c] %@",
                                      startOfDay as NSDate,
                                      endOfDay as NSDate,
                                      "快速记录")
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            if let existingRecord = results.first {
                // 找到现有记录，进入编辑模式
                self.existingRecord = existingRecord
                self.isEditMode = true
                loadExistingRecordData(existingRecord)
                print("✅ 找到今天的快速记录，进入编辑模式")
            } else {
                // 没有找到记录，保持新建模式
                self.existingRecord = nil
                self.isEditMode = false
                print("✅ 今天没有快速记录，保持新建模式")
            }
        } catch {
            print("❌ 查找现有快速记录失败: \(error)")
        }
    }
    
    // 加载现有记录的数据
    private func loadExistingRecordData(_ record: HeadacheRecord) {
        // 加载位置信息
        selectedLocations.removeAll()
        if record.locationForehead { selectedLocations.insert(.forehead) }
        if record.locationLeftSide { selectedLocations.insert(.leftSide) }
        if record.locationRightSide { selectedLocations.insert(.rightSide) }
        if record.locationTemple { selectedLocations.insert(.temple) }
        if record.locationFace { selectedLocations.insert(.face) }
        
        // 加载触发因素
        if let triggersString = record.triggers,
           let firstTrigger = triggersString.components(separatedBy: ",").first,
           let trigger = HeadacheTrigger(rawValue: firstTrigger.trimmingCharacters(in: .whitespaces)) {
            selectedTrigger = trigger
        }
        
        // 加载备注（去除"快速记录 - "前缀）
        if let note = record.note {
            if note.hasPrefix("快速记录 - 今天的轻微头痛，若有若无；") {
                quickNote = String(note.dropFirst("快速记录 - 今天的轻微头痛，若有若无；".count))
            } else if note.hasPrefix("快速记录 - 今天的轻微头痛，若有若无") {
                quickNote = ""
            } else if note.hasPrefix("快速记录") {
                // 处理其他格式的快速记录备注
                let components = note.components(separatedBy: "；")
                if components.count > 1 {
                    quickNote = components[1]
                } else {
                    quickNote = ""
                }
            }
        }
    }
    
    private func saveQuickEntry() {
        isSaving = true
        
        DispatchQueue.main.async {
            do {
                let record: HeadacheRecord
                
                if let existingRecord = existingRecord {
                    // 编辑模式：更新现有记录
                    record = existingRecord
                    print("✅ 更新现有的快速记录")
                } else {
                    // 新建模式：创建新记录
                    record = HeadacheRecord(context: viewContext)
                    record.timestamp = todayTimestamp
                    record.intensity = defaultIntensity
                    print("✅ 创建新的快速记录")
                }
                
                // 位置信息
                record.locationForehead = selectedLocations.contains(.forehead)
                record.locationLeftSide = selectedLocations.contains(.leftSide)
                record.locationRightSide = selectedLocations.contains(.rightSide)
                record.locationTemple = selectedLocations.contains(.temple)
                record.locationFace = selectedLocations.contains(.face)
                
                // 触发因素
                record.triggers = selectedTrigger.rawValue
                
                // 备注处理
                var finalNote = "快速记录 - 今天的轻微头痛，若有若无"
                if !quickNote.isEmpty {
                    finalNote += "；\(quickNote)"
                }
                record.note = finalNote
                
                // 固定的症状特征
                record.setCustomSymptoms(["若有若无", "轻微不适"])
                
                // 时间信息 - 设置为今天，标记为已完成的记录
                record.startTime = todayTimestamp
                // 设置结束时间为同一天的稍后时间，表示这是一个完整的记录
                record.endTime = Calendar.current.date(byAdding: .hour, value: 1, to: todayTimestamp)
                
                // 用药信息 - 快速记录默认没有用药
                record.tookMedicine = false
                
                try viewContext.save()
                
                print("✅ 快速记录保存成功: 日期=\(todayTimestamp), 强度=\(record.intensity), 触发因素=\(selectedTrigger.displayName), 模式=\(isEditMode ? "编辑" : "新建")")
                
                isSaving = false
                
                // 延迟关闭，给用户反馈
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
                
            } catch {
                isSaving = false
                errorMessage = "保存失败：\(error.localizedDescription)"
                showError = true
                print("❌ 快速记录保存失败：\(error)")
            }
        }
    }
    
    // 删除快速记录
    private func deleteQuickEntry() {
        guard let existingRecord = existingRecord else { return }
        
        isSaving = true
        
        DispatchQueue.main.async {
            do {
                viewContext.delete(existingRecord)
                try viewContext.save()
                
                print("✅ 快速记录删除成功")
                
                isSaving = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
                
            } catch {
                isSaving = false
                errorMessage = "删除失败：\(error.localizedDescription)"
                showError = true
                print("❌ 快速记录删除失败：\(error)")
            }
        }
    }
}

// 快速位置选择按钮
struct QuickLocationButton: View {
    let location: HeadacheLocation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.caption)
                Text(location.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 快速触发因素选择按钮
struct QuickTriggerButton: View {
    let trigger: HeadacheTrigger
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: trigger.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : Color(trigger.color))
                Text(trigger.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(isSelected ? Color(trigger.color) : Color(trigger.color).opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(trigger.color) : Color(trigger.color).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    QuickHeadacheEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
