//
//  SettingsView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var customOptionsManager = CustomOptionsManager.shared
    @State private var showDataExport = false
    @State private var showNotificationSettings = false
    @State private var showCustomOptionsManagement = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // 自定义选项管理
                Section {
                    NavigationLink(destination: CustomOptionsManagementView()) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("自定义选项管理")
                                Text("管理您的个人化选项")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("通知设置")
                                Text("管理头痛提醒通知")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("个人化设置")
                }
                
                // 数据管理
                Section {
                    Button(action: { showDataExport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("导出数据")
                                    .foregroundColor(.primary)
                                Text("导出头痛记录为CSV文件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: DataAnalysisView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("高级分析")
                                Text("深度数据分析和趋势")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("数据管理")
                }
                
                // 应用信息
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("关于应用")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text("健康提醒")
                            Text("记录详细信息有助于医生诊断")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("应用信息")
                }
                
                // 快捷统计
                Section {
                    QuickStatsView()
                } header: {
                    Text("快速统计")
                }
            }
            .navigationTitle("设置")
        }
        .sheet(isPresented: $showDataExport) {
            DataExportView()
        }
    }
}

// 自定义选项管理视图
struct CustomOptionsManagementView: View {
    @StateObject private var customOptionsManager = CustomOptionsManager.shared
    @State private var selectedCategory: CustomOptionCategory = .location
    @State private var showAddOption = false
    @State private var newOptionText = ""
    
    var body: some View {
        VStack {
            // 分类选择器
            Picker("选择分类", selection: $selectedCategory) {
                ForEach(CustomOptionCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // 自定义选项列表
            List {
                ForEach(customOptionsManager.getCustomOptions(for: selectedCategory), id: \.id) { option in
                    HStack {
                        Image(systemName: selectedCategory.icon)
                            .foregroundColor(.blue)
                        Text(option.text)
                        Spacer()
                        Text(option.createdAt, formatter: dateFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteOptions)
                
                // 添加新选项
                Button(action: { showAddOption = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        Text("添加新的\(selectedCategory.displayName)")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("自定义选项管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddOption) {
            AddCustomOptionView(
                title: "添加\(selectedCategory.displayName)",
                text: $newOptionText,
                onSave: {
                    customOptionsManager.addCustomOption(text: newOptionText.trimmingCharacters(in: .whitespacesAndNewlines), category: selectedCategory)
                    newOptionText = ""
                    showAddOption = false
                },
                onCancel: {
                    newOptionText = ""
                    showAddOption = false
                }
            )
        }
    }
    
    private func deleteOptions(offsets: IndexSet) {
        let optionsToDelete = offsets.map { customOptionsManager.getCustomOptions(for: selectedCategory)[$0] }
        for option in optionsToDelete {
            customOptionsManager.removeCustomOption(option)
        }
    }
}

// 通知设置视图
struct NotificationSettingsView: View {
    @State private var notificationsEnabled = true
    @State private var reminderInterval: Double = 3
    @State private var maxReminders: Double = 8
    @State private var quietHoursEnabled = false
    @State private var quietStartTime = Date()
    @State private var quietEndTime = Date()
    
    var body: some View {
        Form {
            Section {
                Toggle("启用头痛提醒", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    VStack(alignment: .leading) {
                        Text("提醒间隔: \(Int(reminderInterval))小时")
                        Slider(value: $reminderInterval, in: 1...6, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("最大提醒次数: \(Int(maxReminders))次")
                        Slider(value: $maxReminders, in: 3...12, step: 1)
                    }
                }
            } header: {
                Text("头痛提醒设置")
            } footer: {
                Text("当头痛未设置结束时间时，系统会定期提醒您更新状态")
            }
            
            Section {
                Toggle("启用免打扰时间", isOn: $quietHoursEnabled)
                
                if quietHoursEnabled {
                    DatePicker("开始时间", selection: $quietStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("结束时间", selection: $quietEndTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("免打扰设置")
            } footer: {
                Text("在免打扰时间段内不会发送提醒通知")
            }
            
            Section {
                Button("测试通知") {
                    sendTestNotification()
                }
                .foregroundColor(.blue)
                
                Button("清除所有待发送通知") {
                    NotificationManager.shared.cancelAllHeadacheReminders()
                }
                .foregroundColor(.red)
            } header: {
                Text("通知管理")
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "头痛日记测试"
        content.body = "这是一条测试通知"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("测试通知发送失败: \(error)")
            }
        }
    }
}

// 数据导出视图
struct DataExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var includeCustomOptions = true
    @State private var includeNotes = true
    @State private var isExporting = false
    @State private var exportCompleted = false
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("导出格式", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("导出设置")
                }
                
                Section {
                    Toggle("包含自定义选项", isOn: $includeCustomOptions)
                    Toggle("包含详细备注", isOn: $includeNotes)
                } header: {
                    Text("数据选项")
                }
                
                Section {
                    HStack {
                        Text("总记录数")
                        Spacer()
                        Text("\(records.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("有备注记录")
                        Spacer()
                        Text("\(recordsWithNotes)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("自定义选项记录")
                        Spacer()
                        Text("\(recordsWithCustomOptions)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("数据概览")
                }
                
                Section {
                    Button(action: exportData) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("导出中...")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("开始导出")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isExporting || records.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("导出完成", isPresented: $exportCompleted) {
                Button("确定") { dismiss() }
            } message: {
                Text("数据已成功导出到文件应用")
            }
        }
    }
    
    private var recordsWithNotes: Int {
        records.filter { record in
            ![record.note, record.medicineNote, record.triggerNote, record.symptomNote, record.timeNote]
                .compactMap { $0 }.filter { !$0.isEmpty }.isEmpty
        }.count
    }
    
    private var recordsWithCustomOptions: Int {
        records.filter { record in
            ![record.customLocations, record.customMedicines, record.customTriggers, record.customSymptoms]
                .compactMap { $0 }.filter { !$0.isEmpty }.isEmpty
        }.count
    }
    
    private func exportData() {
        isExporting = true
        
        DispatchQueue.global(qos: .background).async {
            let exportedData: String
            
            switch exportFormat {
            case .csv:
                exportedData = generateCSV()
            case .json:
                exportedData = generateJSON()
            }
            
            DispatchQueue.main.async {
                saveToFile(data: exportedData, format: exportFormat)
                isExporting = false
                exportCompleted = true
            }
        }
    }
    
    private func generateCSV() -> String {
        var csv = "日期,时间,强度,疼痛位置,自定义位置,用药,药物类型,自定义药物,药物缓解,触发因素,自定义触发因素,症状,自定义症状,持续时间,备注"
        
        if includeNotes {
            csv += ",用药备注,触发因素备注,症状备注,时间备注"
        }
        
        csv += "\n"
        
        for record in records {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let date = record.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? ""
            let time = record.timestamp?.formatted(date: .omitted, time: .shortened) ?? ""
            let intensity = "\(record.intensity)"
            let locations = record.locationNames.joined(separator: "; ")
            let customLocations = includeCustomOptions ? record.customLocationNames.joined(separator: "; ") : ""
            let medicine = record.tookMedicine ? "是" : "否"
            let medicineType = record.medicineName ?? ""
            let customMedicines = includeCustomOptions ? record.customMedicineNames.joined(separator: "; ") : ""
            let medicineRelief = record.medicineRelief ? "是" : "否"
            let triggers = record.triggerNames.joined(separator: "; ")
            let customTriggers = includeCustomOptions ? record.customTriggerNames.joined(separator: "; ") : ""
            let symptoms = record.symptomTags.joined(separator: "; ")
            let customSymptoms = includeCustomOptions ? record.customSymptomNames.joined(separator: "; ") : ""
            let duration = record.durationText ?? ""
            let note = record.note ?? ""
            
            var row = "\(date),\(time),\(intensity),\(locations),\(customLocations),\(medicine),\(medicineType),\(customMedicines),\(medicineRelief),\(triggers),\(customTriggers),\(symptoms),\(customSymptoms),\(duration),\(note)"
            
            if includeNotes {
                let medicineNote = record.medicineNote ?? ""
                let triggerNote = record.triggerNote ?? ""
                let symptomNote = record.symptomNote ?? ""
                let timeNote = record.timeNote ?? ""
                row += ",\(medicineNote),\(triggerNote),\(symptomNote),\(timeNote)"
            }
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func generateJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let exportRecords = records.map { record in
            ExportRecord(
                timestamp: record.timestamp,
                intensity: record.intensity,
                note: record.note,
                locations: record.locationNames,
                customLocations: includeCustomOptions ? record.customLocationNames : [],
                tookMedicine: record.tookMedicine,
                medicineType: record.medicineName,
                customMedicines: includeCustomOptions ? record.customMedicineNames : [],
                medicineRelief: record.medicineRelief,
                triggers: record.triggerNames,
                customTriggers: includeCustomOptions ? record.customTriggerNames : [],
                symptoms: record.symptomTags,
                customSymptoms: includeCustomOptions ? record.customSymptomNames : [],
                startTime: record.startTime,
                endTime: record.endTime,
                medicineNote: includeNotes ? record.medicineNote : nil,
                triggerNote: includeNotes ? record.triggerNote : nil,
                symptomNote: includeNotes ? record.symptomNote : nil,
                timeNote: includeNotes ? record.timeNote : nil
            )
        }
        
        do {
            let data = try encoder.encode(exportRecords)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "导出失败: \(error.localizedDescription)"
        }
    }
    
    private func saveToFile(data: String, format: ExportFormat) {
        let fileName = "headache_diary_\(Date().formatted(date: .abbreviated, time: .omitted)).\(format.rawValue.lowercased())"
        
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL, atomically: true, encoding: .utf8)
                print("文件已保存到: \(fileURL)")
            } catch {
                print("保存文件失败: \(error)")
            }
        }
    }
}

// 导出记录数据模型
struct ExportRecord: Codable {
    let timestamp: Date?
    let intensity: Int16
    let note: String?
    let locations: [String]
    let customLocations: [String]
    let tookMedicine: Bool
    let medicineType: String?
    let customMedicines: [String]
    let medicineRelief: Bool
    let triggers: [String]
    let customTriggers: [String]
    let symptoms: [String]
    let customSymptoms: [String]
    let startTime: Date?
    let endTime: Date?
    let medicineNote: String?
    let triggerNote: String?
    let symptomNote: String?
    let timeNote: String?
}

// 快速统计视图
struct QuickStatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                StatCard(title: "总记录", value: "\(records.count)", color: .blue)
                StatCard(title: "本周", value: "\(thisWeekCount)", color: .green)
            }
            
            HStack {
                StatCard(title: "自定义选项", value: "\(CustomOptionsManager.shared.customOptions.count)", color: .purple)
                StatCard(title: "进行中", value: "\(ongoingCount)", color: .orange)
            }
        }
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
    
    private var ongoingCount: Int {
        records.filter { $0.isOngoing }.count
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// 关于页面
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("头痛日记")
                            .font(.title2.bold())
                        Text("个人化头痛管理工具")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical)
            }
            
            Section("功能特色") {
                FeatureRow(icon: "slider.horizontal.3", title: "自定义选项", description: "无限扩展的个人化选项")
                FeatureRow(icon: "note.text", title: "多层级备注", description: "详细记录每个维度的信息")
                FeatureRow(icon: "chart.bar", title: "智能分析", description: "深度数据分析和模式识别")
                FeatureRow(icon: "bell", title: "智能提醒", description: "进行中头痛的自动跟踪")
            }
            
            Section("使用建议") {
                Text("• 详细记录有助于发现头痛模式")
                Text("• 自定义选项让记录更个性化")
                Text("• 定期查看统计分析寻找规律")
                Text("• 导出数据可作为就医参考")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    SettingsView()
}

struct AddCustomOptionView: View {
    let title: String
    @Binding var text: String
    let onSave: ()->Void
    let onCancel: ()->Void

    var body: some View {
        NavigationView {
            Form {
                TextField("输入内容", text: $text)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
