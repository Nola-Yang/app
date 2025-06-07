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
                    Text("月份")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("统计")
                }
            
            // 天气分析页面
            WeatherAnalysisView()
                .tabItem {
                    Image(systemName: "cloud.sun.bolt")
                    Text("天气")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
        }
        .onAppear {
            // 确保应用启动时通知权限已请求
            NotificationManager.shared.requestNotificationPermission()
            
            // 初始化天气服务
            WeatherService.shared.requestCurrentLocationWeather()
        }
        .withNotificationNavigation() // 添加通知导航支持
        .environmentObject(appStateManager) // 注入状态管理器
        .overlay {
                    if appStateManager.showingHeadacheUpdate,
                       let recordID = appStateManager.activeRecordID {
                        HeadacheUpdateOverlay(
                            recordID: recordID,
                            mode: appStateManager.updateMode
                        ) {
                            // 关闭更新状态
                            appStateManager.showingHeadacheUpdate = false
                            appStateManager.activeRecordID = nil
                        }
                    }
        }
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
    case quickRecord
    case weatherAnalysis
    case settings
    
    var id: String {
        switch self {
        case .headacheEdit(let recordID):
            return "headacheEdit_\(recordID)"
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
    
    func navigateToHeadacheUpdate(recordID: String, mode: HeadacheUpdateMode = .inlineUpdate) {
        DispatchQueue.main.async {
            self.activeRecordID = recordID
            self.updateMode = mode
            self.navigationState = .headacheUpdate(recordID: recordID)
            self.showingHeadacheUpdate = true
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - 设置通知观察者
    private func setupNotificationObservers() {
        // 新增：观察头痛更新状态的通知
       NotificationCenter.default.publisher(for: .openHeadacheUpdate)
           .sink { [weak self] notification in
               self?.handleOpenHeadacheUpdate(notification: notification)
           }
           .store(in: &cancellables)
        
        // 观察打开头痛记录编辑页面的通知
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
                print("📱 进入头痛更新状态: \(recordID)")
                self.navigateToHeadacheUpdate(recordID: recordID, mode: .inlineUpdate)
            }
        }
    }
    
    // MARK: - 通知处理方法
    private func handleOpenHeadacheEdit(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            if let recordID = notification.userInfo?["recordID"] as? String {
                print("📱 导航到头痛记录编辑页面: \(recordID)")
                self.navigateToHeadacheUpdate(recordID: recordID, mode: .inlineUpdate)
            }
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
        }
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
