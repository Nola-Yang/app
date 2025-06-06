import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let editingRecord: HeadacheRecord?
    
    @State private var currentStep = 0
    private let totalSteps = 6 // 更新为6步
    
    // 基本信息
    @State private var timestamp: Date = Date()
    @State private var intensity: Double = 5
    @State private var note: String = ""
    
    // 疼痛位置
    @State private var selectedLocations: Set<HeadacheLocation> = []
    
    // 用药信息
    @State private var tookMedicine = false
    @State private var medicineTime = Date()
    @State private var medicineType: MedicineType = .tylenol
    @State private var medicineRelief = false
    
    // 触发因素 (新增)
    @State private var selectedTriggers: Set<HeadacheTrigger> = []
    
    // 疼痛特征 (移除isVascular)
    @State private var hasTinnitus = false
    @State private var hasThrobbing = false
    
    // 时间范围
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var hasEndTime = false
    
    // 状态管理
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isEditing: Bool {
        editingRecord != nil
    }
    
    init(editingRecord: HeadacheRecord? = nil) {
        self.editingRecord = editingRecord
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 进度指示器
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .padding()
                
                TabView(selection: $currentStep) {
                    basicInfoStep().tag(0)
                    locationStep().tag(1)
                    medicineStep().tag(2)
                    triggerStep().tag(3)      // 新增触发因素步骤
                    symptomsStep().tag(4)     // 移动到第4步
                    timeRangeStep().tag(5)    // 移动到第5步
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 导航按钮
                HStack {
                    if currentStep > 0 {
                        Button("上一步") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .disabled(isSaving)
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("下一步") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    } else {
                        Button(isEditing ? "更新" : "保存") {
                            save()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
            .navigationTitle(isEditing ? "编辑记录" : "记录头痛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                if isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("删除", role: .destructive) {
                            deleteRecord()
                        }
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func basicInfoStep() -> some View {
        Form {
            Section {
                DatePicker("记录时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                
                VStack(alignment: .leading) {
                    Text("疼痛强度: \(Int(intensity))")
                    Slider(value: $intensity, in: 1...10, step: 1)
                        .accentColor(.red)
                }
                
                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("基本信息")
            }
        }
    }
    
    @ViewBuilder
    private func locationStep() -> some View {
        Form {
            Section {
                ForEach(HeadacheLocation.allCases, id: \.self) { location in
                    Button(action: {
                        if selectedLocations.contains(location) {
                            selectedLocations.remove(location)
                        } else {
                            selectedLocations.insert(location)
                        }
                    }) {
                        HStack {
                            Text(location.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedLocations.contains(location) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            } header: {
                Text("疼痛位置 (可多选)")
            }
        }
    }
    
    @ViewBuilder
    private func medicineStep() -> some View {
        Form {
            Section {
                Toggle("是否服药", isOn: $tookMedicine)
                
                if tookMedicine {
                    DatePicker("服药时间", selection: $medicineTime, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("药物类型", selection: $medicineType) {
                        ForEach(MedicineType.allCases, id: \.self) { medicine in
                            Text(medicine.displayName).tag(medicine)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("是否缓解", isOn: $medicineRelief)
                }
            } header: {
                Text("用药信息")
            }
        }
    }
    
    @ViewBuilder
    private func triggerStep() -> some View {
        Form {
            Section {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(HeadacheTrigger.allCases, id: \.self) { trigger in
                        SimpleTriggerButton(
                            trigger: trigger,
                            isSelected: selectedTriggers.contains(trigger)
                        ) {
                            if selectedTriggers.contains(trigger) {
                                selectedTriggers.remove(trigger)
                            } else {
                                selectedTriggers.insert(trigger)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("可能的触发因素 (可多选)")
            } footer: {
                Text("选择您认为可能引发这次头痛的因素，有助于找出头痛模式")
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private func symptomsStep() -> some View {
        Form {
            Section {
                // 移除了血管性头痛选项
                Toggle("伴随耳鸣", isOn: $hasTinnitus)
                Toggle("明显血管跳动", isOn: $hasThrobbing)
            } header: {
                Text("疼痛特征")
            }
        }
    }
    
    @ViewBuilder
    private func timeRangeStep() -> some View {
        Form {
            Section {
                DatePicker("开始时间", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                
                Toggle("记录结束时间", isOn: $hasEndTime)
                
                if hasEndTime {
                    DatePicker("结束时间", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                } else {
                    Text("未结束 - 将在后续提醒中询问")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } header: {
                Text("疼痛时间范围")
            } footer: {
                if !hasEndTime {
                    Text("如果头痛还在持续，系统会每3小时提醒你更新状态")
                        .font(.caption)
                }
            }
        }
    }
    
    private func loadData() {
        guard let record = editingRecord else { return }
        
        // 基本信息
        timestamp = record.timestamp ?? Date()
        intensity = Double(record.intensity)
        note = record.note ?? ""
        
        // 疼痛位置
        selectedLocations.removeAll()
        if record.locationForehead { selectedLocations.insert(.forehead) }
        if record.locationLeftSide { selectedLocations.insert(.leftSide) }
        if record.locationRightSide { selectedLocations.insert(.rightSide) }
        if record.locationTemple { selectedLocations.insert(.temple) }
        if record.locationFace { selectedLocations.insert(.face) }
        
        // 用药信息
        tookMedicine = record.tookMedicine
        medicineTime = record.medicineTime ?? Date()
        if let typeString = record.medicineType,
           let type = MedicineType(rawValue: typeString) {
            medicineType = type
        }
        medicineRelief = record.medicineRelief
        
        // 触发因素
        selectedTriggers.removeAll()
        if let triggersString = record.triggers {
            let triggerStrings = triggersString.components(separatedBy: ",")
            for triggerString in triggerStrings {
                if let trigger = HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces)) {
                    selectedTriggers.insert(trigger)
                }
            }
        }
        
        // 疼痛特征 (移除isVascular)
        hasTinnitus = record.hasTinnitus
        hasThrobbing = record.hasThrobbing
        
        // 时间范围
        startTime = record.startTime ?? timestamp
        hasEndTime = record.endTime != nil
        if hasEndTime {
            endTime = record.endTime ?? timestamp
        }
    }
    
    private func save() {
        isSaving = true
        
        DispatchQueue.main.async {
            do {
                let record = editingRecord ?? HeadacheRecord(context: viewContext)
                
                // 保存所有数据
                record.timestamp = timestamp
                record.intensity = Int16(intensity)
                record.note = note.isEmpty ? nil : note
                
                // 疼痛位置
                record.locationForehead = selectedLocations.contains(.forehead)
                record.locationLeftSide = selectedLocations.contains(.leftSide)
                record.locationRightSide = selectedLocations.contains(.rightSide)
                record.locationTemple = selectedLocations.contains(.temple)
                record.locationFace = selectedLocations.contains(.face)
                
                // 用药信息
                record.tookMedicine = tookMedicine
                if tookMedicine {
                    record.medicineTime = medicineTime
                    record.medicineType = medicineType.rawValue
                    record.medicineRelief = medicineRelief
                } else {
                    record.medicineTime = nil
                    record.medicineType = nil
                    record.medicineRelief = false
                }
                
                // 触发因素
                let triggersArray = Array(selectedTriggers).map { $0.rawValue }
                record.triggers = triggersArray.isEmpty ? nil : triggersArray.joined(separator: ",")
                
                // 疼痛特征 (移除isVascular)
                record.hasTinnitus = hasTinnitus
                record.hasThrobbing = hasThrobbing
                
                // 时间范围
                record.startTime = startTime
                record.endTime = hasEndTime ? endTime : nil
                
                // 保存到Core Data
                try viewContext.save()
                
                // 如果没有结束时间，安排通知提醒
                if !hasEndTime && editingRecord == nil {
                    scheduleHeadacheReminders(for: record)
                }
                
                print("✅ 保存成功: 强度=\(record.intensity), 有结束时间=\(hasEndTime)")
                
                isSaving = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
                
            } catch {
                isSaving = false
                errorMessage = "保存失败：\(error.localizedDescription)"
                showError = true
                print("❌ 保存失败：\(error)")
            }
        }
    }
    
    private func deleteRecord() {
        guard let record = editingRecord else { return }
        
        isSaving = true
        
        DispatchQueue.main.async {
            do {
                viewContext.delete(record)
                try viewContext.save()
                
                print("✅ 删除成功")
                
                isSaving = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
                
            } catch {
                isSaving = false
                errorMessage = "删除失败：\(error.localizedDescription)"
                showError = true
                print("❌ 删除失败：\(error)")
            }
        }
    }
    
    private func scheduleHeadacheReminders(for record: HeadacheRecord) {
        NotificationManager.shared.scheduleHeadacheReminders(for: record)
    }
}

// 简化的触发因素按钮组件（如果TriggerButton不可用）
struct SimpleTriggerButton: View {
    let trigger: HeadacheTrigger
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: trigger.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : getTriggerColor(trigger.color))
                
                Text(trigger.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? getTriggerColor(trigger.color) : getTriggerColor(trigger.color).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? getTriggerColor(trigger.color) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getTriggerColor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray": return .gray
        case "brown": return .brown
        case "mint": return .mint
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue
        }
    }
}

#Preview {
    AddEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
