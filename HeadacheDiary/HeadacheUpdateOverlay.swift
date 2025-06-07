//
//  HeadacheUpdateOverlay.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-07.
//

import SwiftUI
import CoreData

// MARK: - 头痛更新覆盖层视图
struct HeadacheUpdateOverlay: View {
    let recordID: String
    let mode: HeadacheUpdateMode
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var record: HeadacheRecord?
    @State private var updatedIntensity: Int = 5
    @State private var updatedNote: String = ""
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Text("更新头痛状态")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("✕") {
                        onDismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.secondary)
                }
                
                if isLoading {
                    // 加载状态
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("加载记录中...")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                } else if let record = record {
                    // 记录信息显示
                    VStack(alignment: .leading, spacing: 16) {
                        // 头痛持续时间显示
                        HStack {
                            Text("开始时间:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let startTime = record.startTime {
                                Text(startTime, style: .time)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let startTime = record.startTime {
                            HStack {
                                Text("持续时间:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDuration(from: startTime, to: Date()))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Divider()
                        
                        // 疼痛强度更新
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("当前疼痛强度")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("原: \(record.intensity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 疼痛强度选择器
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                                ForEach(1...10, id: \.self) { intensity in
                                    Button(action: {
                                        updatedIntensity = intensity
                                    }) {
                                        Text("\(intensity)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                updatedIntensity == intensity ?
                                                Color.blue : Color.gray.opacity(0.2)
                                            )
                                            .foregroundColor(
                                                updatedIntensity == intensity ?
                                                .white : .primary
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                        
                        // 备注更新
                        VStack(alignment: .leading, spacing: 8) {
                            Text("添加备注")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("记录当前感受或变化", text: $updatedNote, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(2...4)
                        }
                        
                        Divider()
                        
                        // 快速操作按钮
                        VStack(spacing: 12) {
                            // 第一行：主要操作
                            HStack(spacing: 12) {
                                Button("头痛已结束") {
                                    endHeadache()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button("保存更新") {
                                    saveUpdates()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            // 第二行：次要操作
                            HStack(spacing: 12) {
                                Button("30分钟后提醒") {
                                    scheduleReminder(minutes: 30)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button("1小时后提醒") {
                                    scheduleReminder(minutes: 60)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } else {
                    // 错误状态
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("无法加载记录")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 150)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding()
        }
        .onAppear {
            loadRecord()
        }
        .alert("操作失败", isPresented: $showingError) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 私有方法
    
    private func loadRecord() {
        isLoading = true
        
        // 使用异步加载避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            var loadedRecord: HeadacheRecord?
            var error: String?
            
            // 首先尝试UUID解析
            if let uuid = UUID(uuidString: recordID) {
                let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let records = try viewContext.fetch(request)
                    loadedRecord = records.first
                } catch {
                    print("❌ 通过UUID加载记录失败: \(error)")
                }
            }
            
            // 如果UUID失败，尝试ObjectID URI解析
            if loadedRecord == nil {
                if let decodedString = recordID.removingPercentEncoding,
                   let url = URL(string: decodedString),
                   let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
                    
                    do {
                        loadedRecord = try viewContext.existingObject(with: objectID) as? HeadacheRecord
                    } catch {
                        print("❌ 通过ObjectID加载记录失败: \(error)")
                    }
                } else {
                    error = "记录ID格式无效"
                }
            }
            
            // 更新UI
            DispatchQueue.main.async {
                self.isLoading = false
                if let record = loadedRecord {
                    self.record = record
                    self.updatedIntensity = Int(record.intensity)
                } else {
                    self.errorMessage = error ?? "加载记录时出现未知错误"
                }
            }
        }
    }
    
    private func saveUpdates() {
        guard let record = record else { return }
        
        do {
            // 更新强度
            record.intensity = Int16(updatedIntensity)
            
            // 更新备注
            if !updatedNote.isEmpty {
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                let newNote = "[\(timestamp)] \(updatedNote)"
                
                if let existingNote = record.note, !existingNote.isEmpty {
                    record.note = "\(existingNote)\n\(newNote)"
                } else {
                    record.note = newNote
                }
            }
            
            // 保存到 Core Data
            try viewContext.save()
            print("✅ 头痛状态更新成功")
            
            // 延迟关闭，让用户看到更新完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDismiss()
            }
            
        } catch {
            print("❌ 保存更新失败: \(error)")
            errorMessage = "保存更新失败：\(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func endHeadache() {
        guard let record = record else { return }
        
        do {
            record.endTime = Date()
            try viewContext.save()
            print("✅ 头痛已结束")
            
            // 取消相关通知
            Task {
                await NotificationManager.shared.cancelHeadacheReminders(for: recordID)
            }
            
            // 发送结束通知
            NotificationCenter.default.post(
                name: .headacheEnded,
                object: nil,
                userInfo: ["recordID": recordID]
            )
            
            onDismiss()
            
        } catch {
            print("❌ 结束头痛失败: \(error)")
            errorMessage = "结束头痛失败：\(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func scheduleReminder(minutes: Int) {
        guard let record = record else { return }
        
        // 先保存当前更新
        saveUpdates()
        
        // 安排提醒
        NotificationManager.shared.scheduleHeadacheReminder(for: record, reminderMinutes: minutes)
        print("✅ 已安排\(minutes)分钟后提醒")
        
        onDismiss()
    }
    
    private func formatDuration(from startTime: Date, to endTime: Date) -> String {
        let interval = endTime.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 预览
#Preview {
    HeadacheUpdateOverlay(
        recordID: "sample-record-id",
        mode: .inlineUpdate
    ) {
        print("关闭覆盖层")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
