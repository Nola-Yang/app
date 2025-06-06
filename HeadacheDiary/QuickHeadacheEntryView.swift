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
                            Image(systemName: "clock.badge")
                                .foregroundColor(.orange)
                                .font(.title)
                            Text("快速记录")
                                .font(.title2.bold())
                        }
                        
                        VStack(spacing: 6) {
                            Text("记录今天的轻微头痛")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("强度2级 • 若有若无症状")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("保存今天的记录")
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
                        
                        // 提示信息
                        Text("记录日期：\(formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("快速记录")
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
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: todayTimestamp)
    }
    
    private func saveQuickEntry() {
        isSaving = true
        
        DispatchQueue.main.async {
            do {
                let record = HeadacheRecord(context: viewContext)
                
                // 以天为单位的时间戳（今天的开始时间）
                record.timestamp = todayTimestamp
                record.intensity = defaultIntensity
                
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
                
                print("✅ 快速记录保存成功: 日期=\(todayTimestamp), 强度=\(record.intensity), 触发因素=\(selectedTrigger.displayName)")
                
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
