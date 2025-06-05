import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let editingRecord: HeadacheRecord?
    
    @State private var currentStep = 0
    private let totalSteps = 5
    
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
    
    // 疼痛特征
    @State private var isVascular = false
    @State private var hasTinnitus = false
    @State private var hasThrobbing = false
    
    // 时间范围
    @State private var startTime = Date()
    @State private var endTime = Date()
    
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
                    // 步骤 1: 基本信息
                    basicInfoStep()
                        .tag(0)
                    
                    // 步骤 2: 疼痛位置
                    locationStep()
                        .tag(1)
                    
                    // 步骤 3: 用药信息
                    medicineStep()
                        .tag(2)
                    
                    // 步骤 4: 疼痛特征
                    symptomsStep()
                        .tag(3)
                    
                    // 步骤 5: 时间范围
                    timeRangeStep()
                        .tag(4)
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
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("下一步") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(isEditing ? "更新" : "保存") {
                            save()
                        }
                        .buttonStyle(.borderedProminent)
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
                if let record = editingRecord {
                    loadExistingData(from: record)
                }
            }
        }
    }
    
    @ViewBuilder
    private func basicInfoStep() -> some View {
        Form {
            Section("基本信息") {
                DatePicker("记录时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                
                VStack(alignment: .leading) {
                    Text("疼痛强度: \(Int(intensity))")
                    Slider(value: $intensity, in: 1...10, step: 1)
                        .accentColor(.red)
                }
                
                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }
    
    @ViewBuilder
    private func locationStep() -> some View {
        Form {
            Section("疼痛位置 (可多选)") {
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
            }
        }
    }
    
    @ViewBuilder
    private func medicineStep() -> some View {
        Form {
            Section("用药信息") {
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
            }
        }
    }
    
    @ViewBuilder
    private func symptomsStep() -> some View {
        Form {
            Section("疼痛特征") {
                Toggle("血管性疼痛", isOn: $isVascular)
                Toggle("伴随耳鸣", isOn: $hasTinnitus)
                Toggle("明显血管跳动", isOn: $hasThrobbing)
            }
        }
    }
    
    @ViewBuilder
    private func timeRangeStep() -> some View {
        Form {
            Section("疼痛时间范围") {
                DatePicker("开始时间", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                DatePicker("结束时间", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
            }
        }
    }
    
    private func loadExistingData(from record: HeadacheRecord) {
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
        
        // 疼痛特征
        isVascular = record.isVascular
        hasTinnitus = record.hasTinnitus
        hasThrobbing = record.hasThrobbing
        
        // 时间范围
        startTime = record.startTime ?? timestamp
        endTime = record.endTime ?? timestamp
    }
    
    private func save() {
        let record = editingRecord ?? HeadacheRecord(context: viewContext)
        
        // 基本信息
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
        
        // 疼痛特征
        record.isVascular = isVascular
        record.hasTinnitus = hasTinnitus
        record.hasThrobbing = hasThrobbing
        
        // 时间范围
        record.startTime = startTime
        record.endTime = endTime
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save record: \(error)")
        }
    }
    
    private func deleteRecord() {
        guard let record = editingRecord else { return }
        
        viewContext.delete(record)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to delete record: \(error)")
        }
    }
}

#Preview {
    AddEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
