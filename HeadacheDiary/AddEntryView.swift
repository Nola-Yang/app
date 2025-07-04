import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customOptionsManager = HeadacheCustomOptionsManager.shared
    @ObservedObject private var weatherService = WeatherService.shared  // 天气服务
    
    let editingRecord: HeadacheRecord?
    
    @State private var currentStep = 0
    private let totalSteps = 7  // 增加天气信息步骤
    
    // 基本信息
    @State private var timestamp: Date = Date()
    @State private var intensity: Double = 5
    @State private var note: String = ""
    
    // 疼痛位置 - 修改为使用 Set 和分离临时选项
    @State private var selectedLocations: Set<HeadacheLocation> = []
    @State private var selectedCustomLocations: Set<String> = []  // 从设置中选择的
    @State private var temporaryCustomLocations: [String] = []    // 临时添加的
    @State private var newCustomLocation: String = ""
    
    // 用药信息
    @State private var tookMedicine = false
    @State private var medicineTime = Date()
    @State private var medicineType: MedicineType = .tylenol
    @State private var medicineRelief = false
    @State private var selectedCustomMedicines: Set<String> = []  // 从设置中选择的
    @State private var temporaryCustomMedicines: [String] = []    // 临时添加的
    @State private var newCustomMedicine: String = ""
    @State private var medicineNote: String = ""
    
    // 触发因素
    @State private var selectedTriggers: Set<HeadacheTrigger> = []
    @State private var selectedCustomTriggers: Set<String> = []   // 从设置中选择的
    @State private var temporaryCustomTriggers: [String] = []     // 临时添加的
    @State private var newCustomTrigger: String = ""
    @State private var triggerNote: String = ""
    
    // 疼痛特征
    @State private var hasTinnitus = false
    @State private var hasThrobbing = false
    @State private var selectedCustomSymptoms: Set<String> = []   // 从设置中选择的
    @State private var temporaryCustomSymptoms: [String] = []     // 临时添加的
    @State private var newCustomSymptom: String = ""
    @State private var symptomNote: String = ""
    
    // 时间范围
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var hasEndTime = false
    @State private var timeNote: String = ""
    
    // 新增：天气信息
    @State private var autoDetectWeather = true
    @State private var weatherNote: String = ""
    @State private var manualWeatherCondition: WeatherCondition = .sunny
    @State private var manualTemperature: Double = 20
    @State private var manualHumidity: Double = 50
    
    // 状态管理
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var medicationEntries: [MedicationEntry] = []
    
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
                    triggerStep().tag(3)
                    symptomsStep().tag(4)
                    timeRangeStep().tag(5)
                    weatherStep().tag(6)  // 新增：天气信息步骤
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 修改后的导航按钮 - 增加保存并完成选项
                VStack(spacing: 12) {
                    // 主要导航按钮行
                    HStack {
                        // 上一步按钮
                        if currentStep > 0 {
                            Button("上一步") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .disabled(isSaving)
                        }
                        
                        Spacer()
                        
                        // 下一步或最终保存按钮
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
                    
                    // 保存并完成按钮 - 在非最后一步显示
                    if currentStep < totalSteps - 1 {
                        Button(action: {
                            save()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("保存并完成")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
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
                if editingRecord == nil {
                      startTime = timestamp
                      endTime   = timestamp
                }

                loadData()
                // 请求获取当前天气
                if !isEditing {
                    weatherService.requestCurrentLocationWeather()
                }
            }
            .onChange(of: timestamp) { newTimestamp in
                if startTime != newTimestamp {
                    startTime = newTimestamp
                    if !hasEndTime {
                        endTime = newTimestamp
                    }
                }
            }
            .onChange(of: startTime) { newStart in
                if timestamp != newStart {
                  timestamp = newStart
                }
            }
            
            .alert("保存失败", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 新增：天气信息步骤
    @ViewBuilder
    private func weatherStep() -> some View {
        Form {
            Section {
                Toggle("自动检测天气", isOn: $autoDetectWeather)
                
                if autoDetectWeather {
                    // 显示当前天气信息
                    if let currentWeather = weatherService.currentWeather {
                        currentWeatherDisplay(currentWeather)
                    } else if weatherService.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在获取天气数据...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let error = weatherService.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("天气获取失败")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("重新获取") {
                                weatherService.requestCurrentLocationWeather()
                            }
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        }
                    } else {
                        Text("无法获取天气数据，可以手动输入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 手动输入天气信息
                    manualWeatherInput()
                }
            } header: {
                Text("天气信息")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("天气数据有助于分析头痛与天气变化的关联性")
                    if autoDetectWeather && weatherService.currentWeather != nil {
                        Text("✅ 将自动关联当前天气数据到此次头痛记录")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            
            // 天气相关备注
            Section {
                TextField("天气相关备注", text: $weatherNote, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("天气备注")
            } footer: {
                Text("记录天气对头痛的影响，如：气压变化、温度骤降等")
            }
            
            // 新增：智能天气建议
            if let currentWeather = weatherService.currentWeather, autoDetectWeather {
                weatherInsightSection(currentWeather)
            }
        }
    }
    
    @ViewBuilder
    private func currentWeatherDisplay(_ weather: WeatherRecord) -> some View {
        VStack(spacing: 12) {
            HStack {
                if let condition = WeatherCondition(rawValue: weather.condition) {
                    Image(systemName: condition.icon)
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text(condition.displayName)
                        .font(.headline)
                }
                Spacer()
                Text("\(weather.temperature.formatted(.number.precision(.fractionLength(0))))°C")
                    .font(.title2.bold())
                    .foregroundColor(.blue)
            }
            
            // 详细天气信息
            HStack {
                WeatherInfoItem(icon: "humidity", label: "湿度", value: "\(weather.humidity.formatted(.number.precision(.fractionLength(0))))%")
                Spacer()
                WeatherInfoItem(icon: "barometer", label: "气压", value: "\(weather.pressure.formatted(.number.precision(.fractionLength(0))))hPa")
                Spacer()
                WeatherInfoItem(icon: "wind", label: "风速", value: "\(weather.windSpeed.formatted(.number.precision(.fractionLength(0))))km/h")
            }
            
            // 变化指示
            if abs(weather.temperatureChange) > 1 || abs(weather.pressureChange) > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("与昨日相比:")
                        .font(.caption.bold())
                    HStack {
                        if abs(weather.temperatureChange) > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: weather.temperatureChange > 0 ? "arrow.up" : "arrow.down")
                                    .foregroundColor(weather.temperatureChange > 0 ? .red : .blue)
                                Text("温度\(weather.temperatureChange > 0 ? "上升" : "下降")\(abs(weather.temperatureChange).formatted(.number.precision(.fractionLength(1))))°C")
                            }
                            .font(.caption)
                        }
                        
                        if abs(weather.pressureChange) > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: weather.pressureChange > 0 ? "arrow.up" : "arrow.down")
                                    .foregroundColor(weather.pressureChange > 0 ? .orange : .green)
                                Text("气压\(weather.pressureChange > 0 ? "上升" : "下降")\(abs(weather.pressureChange).formatted(.number.precision(.fractionLength(1))))hPa")
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func manualWeatherInput() -> some View {
        VStack(spacing: 16) {
            Picker("天气状况", selection: $manualWeatherCondition) {
                ForEach(WeatherCondition.allCases, id: \.self) { condition in
                    HStack {
                        Image(systemName: condition.icon)
                        Text(condition.displayName)
                    }
                    .tag(condition)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("温度: \(manualTemperature.formatted(.number.precision(.fractionLength(0))))°C")
                    .font(.subheadline)
                Slider(value: $manualTemperature, in: -10...40, step: 1)
                    .accentColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("湿度: \(manualHumidity.formatted(.number.precision(.fractionLength(0))))%")
                    .font(.subheadline)
                Slider(value: $manualHumidity, in: 0...100, step: 5)
                    .accentColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func weatherInsightSection(_ weather: WeatherRecord) -> some View {
        let insights = generateWeatherInsights(weather)
        if !insights.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(insight)
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("天气洞察")
            }
        }
    }
    
    private func generateWeatherInsights(_ weather: WeatherRecord) -> [String] {
        var insights: [String] = []
        
        // 气压变化洞察
        if abs(weather.pressureChange) > 3 {
            insights.append("气压变化较大，这可能是头痛的诱因之一")
        }
        
        // 温度变化洞察
        if abs(weather.temperatureChange) > 8 {
            insights.append("温度变化剧烈，注意保暖或降温")
        }
        
        // 湿度洞察
        if weather.humidity > 80 {
            insights.append("湿度较高，可能影响舒适度")
        } else if weather.humidity < 30 {
            insights.append("空气干燥，注意补水")
        }
        
        // 风速洞察
        if weather.windSpeed > 25 {
            insights.append("风速较大，外出时注意防风保暖")
        }
        
        // 天气条件洞察
        switch weather.condition {
        case WeatherCondition.stormy.rawValue:
            insights.append("暴风雨天气，气压变化可能影响头痛")
        case WeatherCondition.rainy.rawValue:
            insights.append("下雨天，湿度和气压变化需要关注")
        case WeatherCondition.foggy.rawValue:
            insights.append("雾天能见度低，湿度较高")
        default:
            break
        }
        
        return insights
    }
    
    // 其他现有的步骤方法保持不变...
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
                
                TextField("总体备注", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("基本信息")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("记录这次头痛的基本信息和总体感受")
                    Text("💡 提示：可以随时点击\"保存并完成\"来快速保存当前信息")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
    }
    
    @ViewBuilder
    private func locationStep() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 3D头部模型选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("疼痛位置选择")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("点击3D头部模型上的区域来选择疼痛位置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HeadModel3DView(
                        selectedLocations: $selectedLocations,
                        selectedCustomLocations: $selectedCustomLocations
                    )
                }
                .padding(.horizontal)
                
                // 传统列表选择（作为补充）
                VStack(alignment: .leading, spacing: 12) {
                    Text("或使用传统方式选择")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // 预定义位置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("常见疼痛位置")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
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
                                            .font(.subheadline)
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedLocations.contains(location) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 已保存的自定义位置
                let savedCustomLocations = customOptionsManager.getCustomOptions(for: .location)
                if !savedCustomLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已保存的自定义位置")
                            .font(.subheadline.bold())
                            .foregroundColor(.purple)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(savedCustomLocations, id: \.id) { option in
                                Button(action: {
                                    if selectedCustomLocations.contains(option.text) {
                                        selectedCustomLocations.remove(option.text)
                                    } else {
                                        selectedCustomLocations.insert(option.text)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .foregroundColor(.purple)
                                        Text(option.text)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedCustomLocations.contains(option.text) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.purple)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedCustomLocations.contains(option.text) ? Color.purple.opacity(0.1) : Color(.systemGray6))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 临时添加的位置
                VStack(alignment: .leading, spacing: 12) {
                    Text("本次临时添加")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                    
                    if !temporaryCustomLocations.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(temporaryCustomLocations, id: \.self) { location in
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                    Text(location)
                                        .font(.subheadline)
                                    Spacer()
                                    Button(action: {
                                        temporaryCustomLocations.removeAll { $0 == location }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange.opacity(0.1))
                                )
                            }
                        }
                    }
                    
                    HStack {
                        TextField("临时添加位置", text: $newCustomLocation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("添加") {
                            let trimmed = newCustomLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !temporaryCustomLocations.contains(trimmed) {
                                temporaryCustomLocations.append(trimmed)
                                newCustomLocation = ""
                            }
                        }
                        .disabled(newCustomLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Text("💡 临时添加的位置只用于本次记录。要永久保存，请在设置中添加。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func medicineStep() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("用药记录")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 快速提示
                    Text("💡 没有用药？可直接保存")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // 新的用药记录组件
                MedicationTrackingView(medicationEntries: $medicationEntries)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
        }
    }
    
    @ViewBuilder
    private func triggerStep() -> some View {
        Form {
            // 预定义触发因素
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
                Text("💡 不确定触发因素？可以暂时跳过，后续再补充")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            // 已保存的自定义触发因素
            let savedCustomTriggers = customOptionsManager.getCustomOptions(for: .trigger)
            if !savedCustomTriggers.isEmpty {
                Section {
                    ForEach(savedCustomTriggers, id: \.id) { option in
                        Button(action: {
                            if selectedCustomTriggers.contains(option.text) {
                                selectedCustomTriggers.remove(option.text)
                            } else {
                                selectedCustomTriggers.insert(option.text)
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.purple)
                                Text(option.text)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCustomTriggers.contains(option.text) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } header: {
                    Text("已保存的自定义触发因素")
                }
            }
            
            // 临时添加的触发因素
            Section {
                ForEach(temporaryCustomTriggers, id: \.self) { trigger in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text(trigger)
                        Spacer()
                        Button("删除") {
                            temporaryCustomTriggers.removeAll { $0 == trigger }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                
                HStack {
                    TextField("临时添加触发因素", text: $newCustomTrigger)
                    Button("添加") {
                        let trimmed = newCustomTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !temporaryCustomTriggers.contains(trimmed) {
                            temporaryCustomTriggers.append(trimmed)
                            newCustomTrigger = ""
                        }
                    }
                    .disabled(newCustomTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("本次临时添加")
            }
            
            // 触发因素备注
            Section {
                TextField("触发因素详细备注", text: $triggerNote, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("触发因素备注")
            } footer: {
                Text("记录触发因素的具体情况、持续时间、严重程度等")
            }
        }
    }
    
    @ViewBuilder
    private func symptomsStep() -> some View {
        Form {
            Section {
                Toggle("伴随耳鸣", isOn: $hasTinnitus)
                Toggle("明显血管跳动", isOn: $hasThrobbing)
            } header: {
                Text("常见症状")
            } footer: {
                Text("💡 症状信息可选，有助于分析头痛类型")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            // 已保存的自定义症状
            let savedCustomSymptoms = customOptionsManager.getCustomOptions(for: .symptom)
            if !savedCustomSymptoms.isEmpty {
                Section {
                    ForEach(savedCustomSymptoms, id: \.id) { option in
                        Button(action: {
                            if selectedCustomSymptoms.contains(option.text) {
                                selectedCustomSymptoms.remove(option.text)
                            } else {
                                selectedCustomSymptoms.insert(option.text)
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.purple)
                                Text(option.text)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCustomSymptoms.contains(option.text) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } header: {
                    Text("已保存的其他症状")
                }
            }
            
            // 临时添加的症状
            Section {
                ForEach(temporaryCustomSymptoms, id: \.self) { symptom in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text(symptom)
                        Spacer()
                        Button("删除") {
                            temporaryCustomSymptoms.removeAll { $0 == symptom }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                
                HStack {
                    TextField("临时添加症状", text: $newCustomSymptom)
                    Button("添加") {
                        let trimmed = newCustomSymptom.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !temporaryCustomSymptoms.contains(trimmed) {
                            temporaryCustomSymptoms.append(trimmed)
                            newCustomSymptom = ""
                        }
                    }
                    .disabled(newCustomSymptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("本次临时添加")
            }
            
            // 症状备注
            Section {
                TextField("症状详细备注", text: $symptomNote, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("症状备注")
            } footer: {
                Text("记录症状的强度、变化、持续时间等详细信息")
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
                VStack(alignment: .leading, spacing: 4) {
                    if !hasEndTime {
                        Text("如果头痛还在持续，系统会每3小时提醒你更新状态")
                    }
                    Text("💡 时间信息也是可选的，可以随时保存当前记录")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            // 时间备注
            Section {
                TextField("时间相关备注", text: $timeNote, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("时间备注")
            } footer: {
                Text("记录疼痛的变化过程、发作模式、缓解过程等时间相关信息")
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
        
        // 加载自定义位置 - 分离已保存和临时的
        let allCustomLocations = record.customLocationNames
        let savedLocations = Set(customOptionsManager.getCustomOptions(for: .location).map { $0.text })
        selectedCustomLocations = Set(allCustomLocations.filter { savedLocations.contains($0) })
        temporaryCustomLocations = allCustomLocations.filter { !savedLocations.contains($0) }
        
        // 用药信息 - 如果有新的 medicationEntries，优先使用
        if !record.medicationEntries.isEmpty {
            medicationEntries = record.medicationEntries
        } else {
            // 兼容旧数据
            tookMedicine = record.tookMedicine
            medicineTime = record.medicineTime ?? Date()
            if let typeString = record.medicineType,
               let type = MedicineType(rawValue: typeString) {
                medicineType = type
            }
            medicineRelief = record.medicineRelief
            medicineNote = record.medicineNote ?? ""
        }
        
        // 加载自定义药物
        let allCustomMedicines = record.customMedicineNames
        let savedMedicines = Set(customOptionsManager.getCustomOptions(for: .medicine).map { $0.text })
        selectedCustomMedicines = Set(allCustomMedicines.filter { savedMedicines.contains($0) })
        temporaryCustomMedicines = allCustomMedicines.filter { !savedMedicines.contains($0) }
        
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
        
        // 加载自定义触发因素
        let allCustomTriggers = record.customTriggerNames
        let savedTriggers = Set(customOptionsManager.getCustomOptions(for: .trigger).map { $0.text })
        selectedCustomTriggers = Set(allCustomTriggers.filter { savedTriggers.contains($0) })
        temporaryCustomTriggers = allCustomTriggers.filter { !savedTriggers.contains($0) }
        triggerNote = record.triggerNote ?? ""
        
        // 疼痛特征
        hasTinnitus = record.hasTinnitus
        hasThrobbing = record.hasThrobbing
        
        // 加载自定义症状
        let allCustomSymptoms = record.customSymptomNames
        let savedSymptoms = Set(customOptionsManager.getCustomOptions(for: .symptom).map { $0.text })
        selectedCustomSymptoms = Set(allCustomSymptoms.filter { savedSymptoms.contains($0) })
        temporaryCustomSymptoms = allCustomSymptoms.filter { !savedSymptoms.contains($0) }
        symptomNote = record.symptomNote ?? ""
        
        // 时间范围
        startTime = record.startTime ?? timestamp
        hasEndTime = record.endTime != nil
        if hasEndTime {
            endTime = record.endTime ?? timestamp
        }
        timeNote = record.timeNote ?? ""
        
        // 天气信息 - 加载现有的天气备注
        if let note = record.note, note.contains("天气") {
            weatherNote = ""  // 从备注中提取天气相关信息
        }
    }
    
    private func save() {
        isSaving = true

        // 时间合理性检查
        guard validateTime() else {
            isSaving = false
            showError = true
            return
        }
        
        DispatchQueue.main.async {
            do {
                let record = editingRecord ?? HeadacheRecord(context: viewContext)
                
                // 保存基本信息
                record.timestamp = timestamp
                record.intensity = Int16(intensity)
                
                // 合并天气备注到总体备注
                var finalNote = note
                if !weatherNote.isEmpty {
                    if !finalNote.isEmpty {
                        finalNote += "\n天气相关：\(weatherNote)"
                    } else {
                        finalNote = "天气相关：\(weatherNote)"
                    }
                }
                record.note = finalNote.isEmpty ? nil : finalNote
                
                // 疼痛位置
                record.locationForehead = selectedLocations.contains(.forehead)
                record.locationLeftSide = selectedLocations.contains(.leftSide)
                record.locationRightSide = selectedLocations.contains(.rightSide)
                record.locationTemple = selectedLocations.contains(.temple)
                record.locationFace = selectedLocations.contains(.face)
                // 合并已保存的和临时的自定义位置
                let allCustomLocations = Array(selectedCustomLocations) + temporaryCustomLocations
                record.setCustomLocations(allCustomLocations)
                
                // 用药信息 - 优先使用新的 medicationEntries
                if !medicationEntries.isEmpty {
                    record.medicationEntries = medicationEntries
                    
                    // 更新缓存字段
                    record.totalDosageValue = medicationEntries.reduce(0) { $0 + $1.dosage }
                    record.hasMedicationTimeline = medicationEntries.count > 1
                    
                    // 为了兼容性，更新传统字段
                    record.tookMedicine = true
                    if let firstEntry = medicationEntries.first {
                        record.medicineTime = firstEntry.time
                        if !firstEntry.isCustomMedicine {
                            record.medicineType = firstEntry.medicineType
                        }
                    }
                    record.medicineRelief = medicationEntries.contains { $0.relief }
                } else {
                    // 使用传统字段（向后兼容）
                    record.tookMedicine = tookMedicine
                    if tookMedicine {
                        record.medicineTime = medicineTime
                        record.medicineType = medicineType.rawValue
                        record.medicineRelief = medicineRelief
                        // 合并已保存的和临时的自定义药物
                        let allCustomMedicines = Array(selectedCustomMedicines) + temporaryCustomMedicines
                        record.setCustomMedicines(allCustomMedicines)
                        record.medicineNote = medicineNote.isEmpty ? nil : medicineNote
                    } else {
                        record.medicineTime = nil
                        record.medicineType = nil
                        record.medicineRelief = false
                        record.setCustomMedicines([])
                        record.medicineNote = nil
                    }
                }
                
                // 触发因素
                let triggersArray = Array(selectedTriggers).map { $0.rawValue }
                record.triggers = triggersArray.isEmpty ? nil : triggersArray.joined(separator: ",")
                // 合并已保存的和临时的自定义触发因素
                let allCustomTriggers = Array(selectedCustomTriggers) + temporaryCustomTriggers
                record.setCustomTriggers(allCustomTriggers)
                record.triggerNote = triggerNote.isEmpty ? nil : triggerNote
                
                // 疼痛特征
                record.hasTinnitus = hasTinnitus
                record.hasThrobbing = hasThrobbing
                // 合并已保存的和临时的自定义症状
                let allCustomSymptoms = Array(selectedCustomSymptoms) + temporaryCustomSymptoms
                record.setCustomSymptoms(allCustomSymptoms)
                record.symptomNote = symptomNote.isEmpty ? nil : symptomNote
                
                // 时间范围
                record.startTime = startTime
                record.endTime = hasEndTime ? endTime : nil
                record.timeNote = timeNote.isEmpty ? nil : timeNote
                
                // 新增：保存天气关联信息
                if autoDetectWeather && !isEditing {
                    // 将当前天气数据关联到头痛记录
                    saveWeatherAssociation(for: record)
                }
                
                // 保存到Core Data
                try viewContext.save()
                
                // 如果没有结束时间，安排通知提醒
                if !hasEndTime && editingRecord == nil {
                    scheduleHeadacheReminders(for: record)
                }
                
                print("✅ 保存成功: 强度=\(record.intensity), 有结束时间=\(hasEndTime), 已关联天气=\(autoDetectWeather)")
                
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
    
    // 新增：保存天气关联信息
    private func saveWeatherAssociation(for record: HeadacheRecord) {
        // 如果有当前天气数据，创建关联
        if let currentWeather = weatherService.currentWeather {
            // 在备注中添加天气信息
            var weatherInfo = "天气状况："
            if let condition = WeatherCondition(rawValue: currentWeather.condition) {
                weatherInfo += "\(condition.displayName)，"
            }
            weatherInfo += "温度\(currentWeather.temperature.formatted(.number.precision(.fractionLength(0))))°C，"
            weatherInfo += "湿度\(currentWeather.humidity.formatted(.number.precision(.fractionLength(0))))%"
            
            if abs(currentWeather.temperatureChange) > 3 {
                weatherInfo += "，温度\(currentWeather.temperatureChange > 0 ? "上升" : "下降")\(abs(currentWeather.temperatureChange).formatted(.number.precision(.fractionLength(1))))°C"
            }
            
            if abs(currentWeather.pressureChange) > 2 {
                weatherInfo += "，气压\(currentWeather.pressureChange > 0 ? "上升" : "下降")\(abs(currentWeather.pressureChange).formatted(.number.precision(.fractionLength(1))))hPa"
            }
            
            // 将天气信息添加到备注
            if let existingNote = record.note {
                record.note = existingNote + "\n\n" + weatherInfo
            } else {
                record.note = weatherInfo
            }
            
            print("✅ 已关联天气数据到头痛记录")
        }
    }
    
    private func deleteRecord() {
        guard let record = editingRecord else { return }
        
        isSaving = true
        
        // 先取消通知
        let recordURI = record.objectID.uriRepresentation().absoluteString
        let encodedRecordID = recordURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? recordURI
        
        Task {
            await NotificationManager.shared.cancelHeadacheReminders(for: encodedRecordID)
            print("✅ 已取消记录 \(record.objectID) 的所有通知")
        }
        
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
        Task {
            await NotificationManager.shared.scheduleHeadacheReminder(for: record)
        }
    }

    private func validateTime() -> Bool {
        // 1. 确保开始时间不晚于结束时间（如果存在结束时间）
        if hasEndTime && startTime > endTime {
            errorMessage = "头痛开始时间不能晚于结束时间。"
            return false
        }

        // 2. 确保记录时间（或头痛开始时间）不晚于当前时间
        let now = Date()
        if timestamp > now {
            errorMessage = "记录时间不能晚于当前时间。"
            return false
        }

        if startTime > now {
            errorMessage = "头痛开始时间不能晚于当前时间。"
            return false
        }

        return true
    }
}

// 新增：天气信息项组件
struct WeatherInfoItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// 简化的触发因素按钮组件
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
        case "teal": return .teal
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
