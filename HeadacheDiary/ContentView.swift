import SwiftUI
import CoreData
import Combine

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var appStateManager = AppStateManager.shared
    
    var body: some View {
        TabView {
            MonthlyView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text(NSLocalizedString("MONTHLY_VIEW_TAB", comment: ""))
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text(NSLocalizedString("STATISTICS_VIEW_TAB", comment: ""))
                }
            
            // 综合洞察页面（包含天气分析）
            ComprehensiveInsightsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text(NSLocalizedString("INSIGHTS_VIEW_TAB", comment: ""))
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(NSLocalizedString("SETTINGS_VIEW_TAB", comment: ""))
                }
        }
        .id(appStateManager.forceRefresh) // 使用forceRefresh作为ID来强制重建TabView
        .onAppear {
            // 确保应用启动时通知权限已请求
            NotificationManager.shared.requestNotificationPermission()
            
            // 初始化天气服务
            WeatherService.shared.requestCurrentLocationWeather()
            
            // 初始化HealthKit (在后台异步进行)
            Task {
                let _ = await HealthKitManager.shared.requestHealthKitPermissions()
            }
        }
        .withNotificationNavigation() // 添加通知导航支持
        .environmentObject(appStateManager) // 注入状态管理器
    }
}

// MARK: - 应用导航状态
enum AppNavigationState: Equatable {
    case home
    case headacheList
    case headacheDetail(recordID: String)
    case headacheEdit(recordID: String)
    case headacheUpdate(recordID: String)
    case quickRecord
    case weatherAnalysis
    case settings
    
    static func == (lhs: AppNavigationState, rhs: AppNavigationState) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home),
             (.headacheList, .headacheList),
             (.quickRecord, .quickRecord),
             (.weatherAnalysis, .weatherAnalysis),
             (.settings, .settings):
            return true
        case (.headacheDetail(let lhsID), .headacheDetail(let rhsID)),
             (.headacheEdit(let lhsID), .headacheEdit(let rhsID)):
            return lhsID == rhsID
        default:
            return false
        }
    }
}

enum HeadacheUpdateMode {
    case inlineUpdate  // 内嵌更新模式
    case fullEdit     // 完整编辑模式
}

// MARK: - 弹出页面类型
enum PresentedSheet: Identifiable {
    case headacheEdit(recordID: String)
    case headacheUpdate(recordID: String)
    case quickRecord
    case weatherAnalysis
    case settings
    
    var id: String {
        switch self {
        case .headacheEdit(let recordID):
            return "headacheEdit_\(recordID)"
        case .headacheUpdate(let recordID):
            return "headacheUpdate_\(recordID)"
        case .quickRecord:
            return "quickRecord"
        case .weatherAnalysis:
            return "weatherAnalysis"
        case .settings:
            return "settings"
        }
    }
}

// MARK: - 应用状态管理器
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var navigationState: AppNavigationState = .home
    @Published var activeRecordID: String?
    @Published var showingQuickRecord = false
    @Published var showingWeatherAnalysis = false
    @Published var presentedSheet: PresentedSheet?
    @Published var updateMode: HeadacheUpdateMode = .inlineUpdate
    @Published var showingHeadacheUpdate = false
    @Published var forceRefresh: UUID = UUID() // 用于强制刷新UI
    
    func navigateToHeadacheUpdate(recordID: String, mode: HeadacheUpdateMode = .inlineUpdate) {
            DispatchQueue.main.async {
                self.activeRecordID = recordID
                self.updateMode = mode
                self.navigationState = .headacheUpdate(recordID: recordID)
                
                self.presentedSheet = .headacheUpdate(recordID: recordID)
            }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - 设置通知观察者
    private func setupNotificationObservers() {
        // 观察头痛更新状态的通知
        NotificationCenter.default.publisher(for: .openHeadacheUpdate)
           .sink { [weak self] notification in
               self?.handleOpenHeadacheUpdate(notification: notification)
           }
           .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .openHeadacheEdit)
            .sink { [weak self] notification in
                self?.handleOpenHeadacheEdit(notification: notification)
            }
            .store(in: &cancellables)

        // 观察打开头痛记录列表的通知
        NotificationCenter.default.publisher(for: .openHeadacheList)
            .sink { [weak self] _ in
                self?.handleOpenHeadacheList()
            }
            .store(in: &cancellables)
        
        // 观察打开快速记录的通知
        NotificationCenter.default.publisher(for: .openQuickRecord)
            .sink { [weak self] _ in
                self?.handleOpenQuickRecord()
            }
            .store(in: &cancellables)
        
        // 观察打开天气分析的通知
        NotificationCenter.default.publisher(for: .openWeatherAnalysis)
            .sink { [weak self] _ in
                self?.handleOpenWeatherAnalysis()
            }
            .store(in: &cancellables)
        
        // 观察头痛结束通知
        NotificationCenter.default.publisher(for: .headacheEnded)
            .sink { [weak self] notification in
                self?.handleHeadacheEnded(notification: notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleOpenHeadacheUpdate(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            if let recordID = notification.userInfo?["recordID"] as? String {
                print("📱 通知点击 - 进入头痛更新状态: \(recordID)")
                // 通知点击 - 使用更新模式
                self.navigateToHeadacheUpdate(recordID: recordID, mode: .inlineUpdate)
            }
        }
    }
    
    // MARK: - 通知处理方法
    private func handleOpenHeadacheEdit(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            if let recordID = notification.userInfo?["recordID"] as? String {
                let source = notification.userInfo?["source"] as? String ?? "unknown"
                print("📱 通知点击 - 导航到头痛记录编辑页面: \(recordID), 来源: \(source)")
                self.navigateToHeadacheUpdate(recordID: recordID, mode: .fullEdit)
            }
        }
    }
    
    nonisolated func handleHeadacheEndAction(recordID: String) {
        Task { @MainActor in
            let userInfo = ["recordID": recordID]
            NotificationCenter.default.post(name: .headacheEnded, object: nil, userInfo: userInfo)
            
            // Cancel subsequent reminders
            await NotificationManager.shared.cancelHeadacheReminders(for: recordID)
            
//            // 发送确认通知
//            NotificationManager.shared.sendConfirmationNotification(
//                title: "头痛已结束",
//                body: "点击查看详情，或使用按钮重新结束记录",
//                recordID: recordID
//            )
        }
    }
    
    private func handleOpenHeadacheList() {
        DispatchQueue.main.async {
            print("📱 导航到头痛记录列表")
            self.navigationState = .headacheList
            self.presentedSheet = nil
        }
    }
    
    private func handleOpenQuickRecord() {
        DispatchQueue.main.async {
            print("📱 打开快速记录页面")
            self.showingQuickRecord = true
            self.presentedSheet = .quickRecord
        }
    }
    
    private func handleOpenWeatherAnalysis() {
        DispatchQueue.main.async {
            print("📱 打开天气分析页面")
            self.showingWeatherAnalysis = true
            self.presentedSheet = .weatherAnalysis
        }
    }
    
    private func handleHeadacheEnded(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            if let recordID = notification.userInfo?["recordID"] as? String {
                print("📱 头痛已结束: \(recordID)")
                // 如果当前正在查看这个记录，更新状态
                if self.activeRecordID == recordID {
                    self.refreshCurrentView()
                }
            }
        }
    }
    
    // MARK: - 公共方法
    func navigateToHeadacheDetail(recordID: String) {
        DispatchQueue.main.async {
            self.activeRecordID = recordID
            self.navigationState = .headacheDetail(recordID: recordID)
        }
    }
    
    func navigateToHome() {
        DispatchQueue.main.async {
            self.navigationState = .home
            self.activeRecordID = nil
            self.presentedSheet = nil
        }
    }
    
    func refreshCurrentView() {
        // 触发当前视图的刷新
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func dismissPresentedSheet() {
        DispatchQueue.main.async {
            self.presentedSheet = nil
            self.showingQuickRecord = false
            self.showingWeatherAnalysis = false
            self.activeRecordID = nil
        }
    }
    
    func triggerRefresh() {
        forceRefresh = UUID()
    }
}

// MARK: - 视图修饰符：处理通知导航
struct NotificationNavigationModifier: ViewModifier {
    @ObservedObject private var appStateManager = AppStateManager.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(item: $appStateManager.presentedSheet) { sheet in
                switch sheet {
                case .headacheEdit(let recordID):
                    HeadacheEditView(recordID: recordID)
                case .headacheUpdate(let recordID):
                    // 使用新的头痛更新视图
                    HeadacheUpdateSheetView(
                        recordID: recordID,
                        mode: appStateManager.updateMode
                    )
                case .quickRecord:
                    QuickRecordView()
                case .weatherAnalysis:
                    WeatherAnalysisDetailView()
                case .settings:
                    SettingsDetailView()
                }
            }
            .onChange(of: appStateManager.navigationState) { _, navigationState in
                handleNavigationStateChange(navigationState)
            }
    }
    
    private func handleNavigationStateChange(_ navigationState: AppNavigationState) {
        // 根据导航状态执行相应的导航操作
        switch navigationState {
        case .home:
            break
        case .headacheList:
            break
        case .headacheDetail(let recordID):
            break
        case .headacheEdit(let recordID):
            break
        case .quickRecord:
            break
        case .weatherAnalysis:
            break
        case .settings:
            break
        case .headacheUpdate(recordID: let recordID):
            print("📱 处理头痛更新状态导航: \(recordID)")
            break
        }
    }
}

// MARK: - 新的头痛更新Sheet视图
struct HeadacheUpdateSheetView: View {
    let recordID: String
    let mode: HeadacheUpdateMode
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var appStateManager = AppStateManager.shared
    
    @State private var record: HeadacheRecord?
    @State private var updatedIntensity: Int = 5
    @State private var updatedNote: String = ""
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
    
    // MARK: - 私有方法（从原Overlay复制）
    
    private func loadRecord() {
        isLoading = true
        
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
            record.intensity = Int16(updatedIntensity)
            
            if !updatedNote.isEmpty {
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                let newNote = "[\(timestamp)] \(updatedNote)"
                
                if let existingNote = record.note, !existingNote.isEmpty {
                    record.note = "\(existingNote)\n\(newNote)"
                } else {
                    record.note = newNote
                }
            }
            
            try viewContext.save()
            print("✅ 头痛状态更新成功")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
                appStateManager.dismissPresentedSheet()
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
            
            Task {
                await NotificationManager.shared.cancelHeadacheReminders(for: recordID)
            }
            
            NotificationCenter.default.post(
                name: .headacheEnded,
                object: nil,
                userInfo: ["recordID": recordID]
            )
            
            dismiss()
            appStateManager.dismissPresentedSheet()
            
        } catch {
            print("❌ 结束头痛失败: \(error)")
            errorMessage = "结束头痛失败：\(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func scheduleReminder(minutes: Int) {
        guard let record = record else { return }
        
        saveUpdates()
        
        NotificationManager.shared.scheduleHeadacheReminder(for: record, reminderMinutes: minutes)
        print("✅ 已安排\(minutes)分钟后提醒")
        
        dismiss()
        appStateManager.dismissPresentedSheet()
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

// MARK: - 视图扩展
extension View {
    func withNotificationNavigation() -> some View {
        self.modifier(NotificationNavigationModifier())
    }
}

// MARK: - 头痛记录编辑视图
struct HeadacheEditView: View {
    let recordID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var record: HeadacheRecord?
    
    var body: some View {
        NavigationView {
            VStack {
                if let record = record {
                    Form {
                        Section("头痛信息") {
                            HStack {
                                Text("开始时间:")
                                Spacer()
                                if let startTime = record.startTime {
                                    Text(startTime, style: .date)
                                    Text(startTime, style: .time)
                                }
                            }
                            
                            HStack {
                                Text("强度:")
                                Spacer()
                                Text("\(record.intensity)")
                            }
                            
                            if let endTime = record.endTime {
                                HStack {
                                    Text("结束时间:")
                                    Spacer()
                                    Text(endTime, style: .date)
                                    Text(endTime, style: .time)
                                }
                            }
                        }
                        
                        Section("操作") {
                            if record.endTime == nil {
                                Button("结束头痛") {
                                    endHeadache()
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                } else {
                    VStack {
                        ProgressView()
                        Text("加载记录中...")
                    }
                }
            }
            .navigationTitle("头痛记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRecord()
            }
        }
    }
    
    private func loadRecord() {
        // 首先尝试UUID
        if let uuid = UUID(uuidString: recordID) {
            let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
               request.predicate = NSPredicate(format: "timestamp != nil")
               request.fetchLimit = 1
            
            do {
                let records = try viewContext.fetch(request)
                self.record = records.first
            } catch {
                print("❌ 加载记录失败: \(error)")
            }
        } else if let url = URL(string: recordID),
                  let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            // 通过ObjectID加载
            do {
                let record = try viewContext.existingObject(with: objectID) as? HeadacheRecord
                self.record = record
            } catch {
                print("❌ 通过ObjectID加载记录失败: \(error)")
            }
        }
    }
    
    private func endHeadache() {
        guard let record = record, record.endTime == nil else { return }
        
        record.endTime = Date()
        
        do {
            try viewContext.save()
            
            // 取消相关通知
            Task {
                await NotificationManager.shared.cancelHeadacheReminders(for: recordID)
            }
            
            dismiss()
        } catch {
            print("❌ 保存失败: \(error)")
        }
    }
}

// MARK: - 快速记录视图
struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var intensity: Int = 5
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("头痛强度") {
                    HStack {
                        Text("1")
                        Slider(value: Binding(
                            get: { Double(intensity) },
                            set: { intensity = Int($0) }
                        ), in: 1...10, step: 1)
                        Text("10")
                    }
                    Text("当前强度: \(intensity)")
                        .foregroundColor(.secondary)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                }
            }
        }
    }
    
    private func saveRecord() {
        let newRecord = HeadacheRecord(context: viewContext)
        newRecord.startTime = Date()
        newRecord.timestamp = Date()
        newRecord.intensity = Int16(intensity)
        newRecord.note = notes.isEmpty ? nil : notes
        
        do {
            try viewContext.save()
            
            // 安排提醒通知
            NotificationManager.shared.scheduleHeadacheReminder(for: newRecord)
            
            dismiss()
        } catch {
            print("❌ 保存记录失败: \(error)")
        }
    }
}

// MARK: - 天气分析详情视图
struct WeatherAnalysisDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("天气分析详情")
                    .font(.title)
                    .padding()
                
                Text("这里显示详细的天气与头痛关联分析")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("天气分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 设置详情视图
struct SettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("通知设置") {
                    Text("配置通知偏好")
                }
                
                Section("数据管理") {
                    Text("导出和备份数据")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
