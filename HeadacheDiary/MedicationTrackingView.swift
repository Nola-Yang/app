//
//  MedicationTrackingView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI

struct MedicationTrackingView: View {
    @Binding var medicationEntries: [MedicationEntry]
    @ObservedObject private var customOptionsManager = HeadacheCustomOptionsManager.shared
    
    @State private var showAddMedication = false
    @State private var editingEntry: MedicationEntry?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部标题
            HStack {
                Text("用药记录")
                    .font(.headline)
                Spacer()
                Button(action: { showAddMedication = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加用药")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
            }
            
            if medicationEntries.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "pills")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("暂无用药记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("点击\"添加用药\"记录服药时间、剂量和效果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // 用药列表
                VStack(spacing: 12) {
                    ForEach(Array(medicationEntries.enumerated()), id: \.element.id) { index, entry in
                        MedicationEntryRow(
                            entry: entry,
                            entryNumber: index + 1,
                            onEdit: { editingEntry = entry },
                            onDelete: { deleteMedicationEntry(entry) }
                        )
                    }
                }
                
                // 总结信息
                MedicationSummaryView(entries: medicationEntries)
            }
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationEntryView(
                onSave: { newEntry in
                    addMedicationEntry(newEntry)
                    showAddMedication = false
                },
                onCancel: { showAddMedication = false }
            )
        }
        .sheet(item: $editingEntry) { entry in
            AddMedicationEntryView(
                editingEntry: entry,
                onSave: { updatedEntry in
                    updateMedicationEntry(updatedEntry)
                    editingEntry = nil
                },
                onCancel: { editingEntry = nil }
            )
        }
    }
    
    private func addMedicationEntry(_ entry: MedicationEntry) {
        medicationEntries.append(entry)
        medicationEntries.sort { $0.time < $1.time }
    }
    
    private func updateMedicationEntry(_ updatedEntry: MedicationEntry) {
        if let index = medicationEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
            medicationEntries[index] = updatedEntry
            medicationEntries.sort { $0.time < $1.time }
        }
    }
    
    private func deleteMedicationEntry(_ entry: MedicationEntry) {
        medicationEntries.removeAll { $0.id == entry.id }
    }
}

// 单个用药记录行
struct MedicationEntryRow: View {
    let entry: MedicationEntry
    let entryNumber: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：序号、时间、药物和剂量
            HStack {
                // 序号标识
                Text("\(entryNumber)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(entry.relief ? Color.green : Color.orange))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.displayName)
                            .font(.subheadline.bold())
                        Text(entry.dosageText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Text(entry.time, formatter: timeFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 效果指示器
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.relief ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(entry.relief ? .green : .red)
                            .font(.caption)
                        Text(entry.relief ? "有效" : "无效")
                            .font(.caption2)
                            .foregroundColor(entry.relief ? .green : .red)
                    }
                    
                    if entry.relief, let reliefTime = entry.reliefTime {
                        Text("缓解于 \(reliefTime, formatter: timeFormatter)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 第二行：备注（如果有）
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28) // 与序号对齐
            }
            
            // 操作按钮
            HStack {
                Spacer()
                
                Button("编辑", action: onEdit)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Button("删除") { showDeleteAlert = true }
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.leading, 28)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(entry.relief ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("确定要删除这条用药记录吗？")
        }
    }
}

// 用药总结视图
struct MedicationSummaryView: View {
    let entries: [MedicationEntry]
    
    private var totalDosage: Double {
        entries.reduce(0) { $0 + $1.dosage }
    }
    
    private var effectiveEntries: [MedicationEntry] {
        entries.filter { $0.relief }
    }
    
    private var dosageByMedicine: [String: Double] {
        var dosages: [String: Double] = [:]
        for entry in entries {
            dosages[entry.displayName, default: 0] += entry.dosage
        }
        return dosages
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("用药总结")
                .font(.subheadline.bold())
            
            // 基本统计
            HStack {
                SummaryCard(
                    title: "总用药次数",
                    value: "\(entries.count)次",
                    color: .blue
                )
                
                SummaryCard(
                    title: "总剂量",
                    value: "\(Int(totalDosage))mg",
                    color: .purple
                )
                
                SummaryCard(
                    title: "有效次数",
                    value: "\(effectiveEntries.count)次",
                    color: .green
                )
            }
            
            // 按药物分组的剂量
            if dosageByMedicine.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("各药物剂量:")
                        .font(.caption.bold())
                    
                    ForEach(dosageByMedicine.sorted(by: { $0.value > $1.value }), id: \.key) { medicine, dosage in
                        HStack {
                            Text(medicine)
                                .font(.caption)
                            Spacer()
                            Text("\(Int(dosage))mg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            
            // 有效用药时间线
            if !effectiveEntries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("有效用药时间线:")
                        .font(.caption.bold())
                    
                    ForEach(Array(effectiveEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(entry.time, formatter: timeFormatter)")
                                .font(.caption)
                            Text(entry.displayName)
                                .font(.caption)
                            Text(entry.dosageText)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// 总结卡片组件
struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// 添加/编辑用药记录的视图
struct AddMedicationEntryView: View {
    let editingEntry: MedicationEntry?
    let onSave: (MedicationEntry) -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var customOptionsManager = HeadacheCustomOptionsManager.shared
    
    @State private var selectedTime = Date()
    @State private var selectedMedicineType: MedicineType = .tylenol
    @State private var useCustomMedicine = false
    @State private var customMedicineName = ""
    @State private var selectedCustomMedicine = ""
    @State private var dosage: Double = 500
    @State private var hasRelief = false
    @State private var reliefTime = Date()
    @State private var hasReliefTime = false
    @State private var note = ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private var isEditing: Bool {
        editingEntry != nil
    }
    
    private var isValid: Bool {
        if useCustomMedicine {
            return !selectedCustomMedicine.isEmpty && dosage > 0
        } else {
            return dosage > 0
        }
    }
    
    init(editingEntry: MedicationEntry? = nil, onSave: @escaping (MedicationEntry) -> Void, onCancel: @escaping () -> Void) {
        self.editingEntry = editingEntry
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("服药时间", selection: $selectedTime, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("服药时间")
                }
                
                Section {
                    Toggle("使用自定义药物", isOn: $useCustomMedicine)
                    
                    if useCustomMedicine {
                        // 自定义药物选择
                        let savedMedicines = customOptionsManager.getCustomOptions(for: .medicine)
                        if !savedMedicines.isEmpty {
                            Picker("选择药物", selection: $selectedCustomMedicine) {
                                Text("选择药物").tag("")
                                ForEach(savedMedicines, id: \.id) { option in
                                    Text(option.text).tag(option.text)
                                }
                            }
                        } else {
                            TextField("输入药物名称", text: $selectedCustomMedicine)
                        }
                    } else {
                        Picker("药物类型", selection: $selectedMedicineType) {
                            ForEach(MedicineType.allCases, id: \.self) { medicine in
                                Text(medicine.displayName).tag(medicine)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                } header: {
                    Text("药物选择")
                }
                
                Section {
                    HStack {
                        Text("剂量")
                        Spacer()
                        TextField("剂量", value: $dosage, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        Text("mg")
                    }
                    
                    // 常用剂量快捷按钮
                    VStack(alignment: .leading, spacing: 8) {
                        Text("常用剂量:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([200, 400, 500, 600, 800, 1000], id: \.self) { commonDosage in
                                Button("\(commonDosage)mg") {
                                    dosage = Double(commonDosage)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dosage == Double(commonDosage) ? Color.blue : Color(.systemGray5))
                                .foregroundColor(dosage == Double(commonDosage) ? .white : .primary)
                                .cornerRadius(6)
                            }
                        }
                    }
                } header: {
                    Text("剂量 (mg)")
                } footer: {
                    Text("请输入准确的服药剂量，这有助于分析用药效果")
                }
                
                Section {
                    Toggle("是否缓解", isOn: $hasRelief)
                    
                    if hasRelief {
                        Toggle("记录缓解时间", isOn: $hasReliefTime)
                        
                        if hasReliefTime {
                            DatePicker("缓解时间", selection: $reliefTime, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                } header: {
                    Text("用药效果")
                }
                
                Section {
                    TextField("用药备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("备注")
                } footer: {
                    Text("记录用药方式、副作用、特殊情况等")
                }
            }
            .navigationTitle(isEditing ? "编辑用药记录" : "添加用药记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "更新" : "保存") {
                        saveMedicationEntry()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadData()
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadData() {
        guard let entry = editingEntry else { return }
        
        selectedTime = entry.time
        useCustomMedicine = entry.isCustomMedicine
        
        if entry.isCustomMedicine {
            selectedCustomMedicine = entry.medicineType
        } else {
            selectedMedicineType = MedicineType(rawValue: entry.medicineType) ?? .tylenol
        }
        
        dosage = entry.dosage
        hasRelief = entry.relief
        hasReliefTime = entry.reliefTime != nil
        
        if let reliefTime = entry.reliefTime {
            self.reliefTime = reliefTime
        }
        
        note = entry.note ?? ""
    }
    
    private func saveMedicationEntry() {
        // 验证输入
        if useCustomMedicine && selectedCustomMedicine.isEmpty {
            alertMessage = "请选择或输入药物名称"
            showAlert = true
            return
        }
        
        if dosage <= 0 {
            alertMessage = "请输入有效的剂量"
            showAlert = true
            return
        }
        
        // 创建用药记录
        let medicineType = useCustomMedicine ? selectedCustomMedicine : selectedMedicineType.rawValue
        let finalReliefTime = hasRelief && hasReliefTime ? reliefTime : nil
        
        let finalEntry: MedicationEntry
        
        if let editingEntry = editingEntry {
            // 编辑模式：保持原有ID，更新其他信息
            finalEntry = editingEntry.updated(
                time: selectedTime,
                medicineType: medicineType,
                dosage: dosage,
                isCustomMedicine: useCustomMedicine,
                relief: hasRelief,
                reliefTime: finalReliefTime,
                note: note.isEmpty ? nil : note
            )
        } else {
            // 新建模式：创建新记录
            finalEntry = MedicationEntry(
                time: selectedTime,
                medicineType: medicineType,
                dosage: dosage,
                isCustomMedicine: useCustomMedicine,
                relief: hasRelief,
                reliefTime: finalReliefTime,
                note: note.isEmpty ? nil : note
            )
        }
        
        onSave(finalEntry)
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    struct MedicationTrackingPreview: View {
        @State private var entries: [MedicationEntry] = [
            MedicationEntry(
                time: Date().addingTimeInterval(-7200),
                medicineType: MedicineType.tylenol.rawValue,
                dosage: 500,
                isCustomMedicine: false,
                relief: false,
                note: "饭后服用"
            ),
            MedicationEntry(
                time: Date().addingTimeInterval(-3600),
                medicineType: "阿司匹林",
                dosage: 300,
                isCustomMedicine: true,
                relief: true,
                reliefTime: Date().addingTimeInterval(-1800),
                note: "30分钟后开始缓解"
            )
        ]
        
        var body: some View {
            MedicationTrackingView(medicationEntries: $entries)
                .padding()
        }
    }
    
    return MedicationTrackingPreview()
}
