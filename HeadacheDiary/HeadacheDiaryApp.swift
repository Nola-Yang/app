//
//  HeadacheDiaryApp.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI
import UserNotifications

@main
struct HeadacheDiaryApp: App {
    let persistenceController = PersistenceController.shared
    private let notificationDelegate = NotificationDelegate()
    
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var weatherWarningManager = WeatherWarningManager.shared
    
    init() {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        // 请求通知权限
        NotificationManager.shared.requestNotificationPermission()
        
        // 监听头痛结束通知
        NotificationCenter.default.addObserver(
            forName: .headacheEnded,
            object: nil,
            queue: .main
        ) { notification in
            if let recordID = notification.userInfo?["recordID"] as? String {
                HeadacheDiaryApp.updateHeadacheEndTime(recordID: recordID, controller: PersistenceController.shared)
            }
        }
        
        // 新增：监听天气相关通知
        NotificationCenter.default.addObserver(
            forName: .openWeatherAnalysis,
            object: nil,
            queue: .main
        ) { notification in
            // 处理打开天气分析页面的请求
            // 这里可以通过 AppState 或其他机制来控制界面导航
            print("📱 请求打开天气分析页面")
        }
        
        NotificationCenter.default.addObserver(
            forName: .openQuickRecord,
            object: nil,
            queue: .main
        ) { notification in
            // 处理打开快速记录页面的请求
            print("📱 请求打开快速记录页面")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(weatherService)  // 新增：注入天气服务
                .environmentObject(weatherWarningManager)  // 新增：注入预警管理器
                .onAppear {
                    // 应用启动时的初始化
                    setupAppOnLaunch()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // 应用变为活跃状态时的处理
                    handleAppBecomeActive()
                }
        }
    }
    
    // 新增：应用启动时的设置
    private func setupAppOnLaunch() {
        // 清理过期的通知
        HeadacheDiaryApp.cleanupExpiredNotifications()
        
        Task {
                await NotificationManager.shared.cleanupOrphanedNotifications(
                    context: persistenceController.container.viewContext
                )
        }
    
        // 初始化天气服务
        Task {
            await initializeWeatherServices()
        }
        
        Task { @MainActor in
            await AutoHeadacheManager.shared.checkAndAutoEndOverdueHeadaches(
                context: persistenceController.container.viewContext
            )
        }
        
        print("✅ 头痛日记应用启动完成")
    }
    
    // 应用变为活跃状态时的处理
    private func handleAppBecomeActive() {
        // 刷新天气数据
        weatherService.requestCurrentLocationWeather()
        
        // 从后台返回时清理孤儿通知
        Task {
            await NotificationManager.shared.cleanupOrphanedNotifications(
                context: persistenceController.container.viewContext
            )
        }
        
        // 检查是否有新的预警需要处理
        Task {
            await weatherWarningManager.checkForWarnings(weather: weatherService.currentWeather ?? WeatherRecord(
                date: Date(),
                location: .init(latitude: 0, longitude: 0),
                temperature: 20,
                humidity: 50,
                pressure: 1013,
                condition: WeatherCondition.sunny.rawValue,
                uvIndex: 5,
                windSpeed: 10,
                precipitationChance: 0
            ))
        }
        
        // 执行每日检查：自动结束跨天记录 + 提醒昨天记录
        Task { @MainActor in
            await AutoHeadacheManager.shared.performDailyCheck(
                context: persistenceController.container.viewContext
            )
        }
    }
    
    // 新增：初始化天气服务
    private func initializeWeatherServices() async {
        // 请求位置权限
        weatherService.requestLocationPermission()
        
        // 设置预警管理器
        if weatherWarningManager.settings.isEnabled {
            weatherWarningManager.scheduleRegularChecks()
        }
        
        // 如果是新的一天，发送每日预报
        await sendDailyForecastIfNeeded()
        
        print("✅ 天气服务初始化完成")
    }
    
    // 发送每日预报（如果需要）
    private func sendDailyForecastIfNeeded() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 检查今天是否已经发送过预报
        let lastForecastKey = "lastDailyForecastDate"
        let lastForecastDate = UserDefaults.standard.object(forKey: lastForecastKey) as? Date
        
        if lastForecastDate == nil || !calendar.isDate(lastForecastDate!, inSameDayAs: today) {
            // 生成并发送每日预报
            let forecast = await weatherWarningManager.generateDailyForecast()
            let riskLevel = weatherWarningManager.tomorrowsRisk
            
            if weatherWarningManager.settings.enableDailyForecast {
                // Fixed method call to be async
                await NotificationManager.shared.sendDailyWeatherForecast(
                    forecast: forecast,
                    riskLevel: riskLevel
                )
            }
            
            // 记录今天已发送预报
            UserDefaults.standard.set(today, forKey: lastForecastKey)
            print("✅ 已发送每日天气预报")
        }
    }
    
    // 静态方法：更新头痛结束时间
    static func updateHeadacheEndTime(recordID: String, controller: PersistenceController) {
        // 先进行URL解码
        guard let decodedString = recordID.removingPercentEncoding,
              let url = URL(string: decodedString),
              let objectID = controller.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url) else {
            print("❌ 无法解析记录ID: \(recordID)")
            return
        }
        
        let context = controller.container.viewContext
        
        do {
            let record = try context.existingObject(with: objectID) as? HeadacheRecord
            record?.endTime = Date()
            try context.save()
            print("✅ 头痛结束时间已更新")
        } catch {
            print("❌ 更新头痛结束时间失败: \(error)")
        }
    }
    
    // 静态方法：清理过期的通知
    static func cleanupExpiredNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let now = Date()
            var expiredIdentifiers: [String] = []
            
            for request in requests {
                // 头痛提醒通知：超过24小时的清理
                if request.identifier.hasPrefix("headache_reminder_") {
                    if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
                       let scheduleDate = trigger.nextTriggerDate(),
                       scheduleDate.timeIntervalSince(now) < -24 * 60 * 60 {
                        expiredIdentifiers.append(request.identifier)
                    }
                }
                
                // 天气预警通知：超过12小时的清理
                if request.identifier.hasPrefix("weather_warning_") {
                    if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
                       let scheduleDate = trigger.nextTriggerDate(),
                       scheduleDate.timeIntervalSince(now) < -12 * 60 * 60 {
                        expiredIdentifiers.append(request.identifier)
                    }
                }
                
                // 天气预报通知：超过当天的清理
                if request.identifier.hasPrefix("daily_weather_forecast_") {
                    // 预报通知应该在发送后几小时内清理
                    let creationTime = Double(request.identifier.replacingOccurrences(of: "daily_weather_forecast_", with: "")) ?? 0
                    let creationDate = Date(timeIntervalSince1970: creationTime)
                    
                    if now.timeIntervalSince(creationDate) > 6 * 60 * 60 { // 6小时后清理
                        expiredIdentifiers.append(request.identifier)
                    }
                }
            }
            
            if !expiredIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIdentifiers)
                print("✅ 已清理 \(expiredIdentifiers.count) 个过期通知")
            }
        }
    }
}
