//
//  NotificationManager.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import Foundation
import UserNotifications
import CoreData

@MainActor
class NotificationManager: ObservableObject {
    // In NotificationManager.swift - Fix main actor issues
    static let shared = NotificationManager()
    
    private init() {}
    
    nonisolated func handleWeatherWarningResponse(action: String, warningId: String) {
        Task { @MainActor in
            switch action {
            case "view_weather_warning":
                // 打开天气分析页面
                NotificationCenter.default.post(
                    name: .openWeatherAnalysis,
                    object: nil,
                    userInfo: ["warningId": warningId]
                )
            case "quick_record_headache":
                // 打开快速记录页面
                NotificationCenter.default.post(
                    name: .openQuickRecord,
                    object: nil,
                    userInfo: ["source": "weather_warning"]
                )
            case "dismiss_weather_warning":
                // 标记预警为已读 - Fixed method call
                if let uuid = UUID(uuidString: warningId) {
                    await WeatherWarningManager.shared.markWarningAsRead(uuid)
                }
            default:
                break
            }
        }
    }
    
    
    // Fix the method to be async and main actor
    func sendWeatherWarningNotification(
        title: String,
        message: String,
        riskLevel: HeadacheRisk,
        warningId: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.badge = 1
        
        // 根据风险级别设置中断级别
        switch riskLevel {
        case .low:
            content.interruptionLevel = .passive
        case .moderate:
            content.interruptionLevel = .active
        case .high, .veryHigh:
            content.interruptionLevel = .timeSensitive
        }
        
        content.userInfo = [
            "type": "weather_warning",
            "warningId": warningId,
            "riskLevel": riskLevel.rawValue
        ]
        
        content.categoryIdentifier = "weather_warning_category"
        
        let request = UNNotificationRequest(
            identifier: "weather_warning_\(warningId)",
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送天气预警通知成功: \(title)")
        } catch {
            print("❌ 发送天气预警通知失败: \(error)")
        }
    }
    
    // Fix the method to be async and main actor
    func sendDailyWeatherForecast(forecast: String, riskLevel: HeadacheRisk) async {
        let content = UNMutableNotificationContent()
        content.title = "今日头痛风险预报"
        content.body = forecast
        content.sound = .default
        
        // 根据风险级别设置不同的标识符和内容
        let riskEmoji: String
        switch riskLevel {
        case .low:
            riskEmoji = "✅"
            content.interruptionLevel = .passive
        case .moderate:
            riskEmoji = "⚠️"
            content.interruptionLevel = .active
        case .high:
            riskEmoji = "🔶"
            content.interruptionLevel = .timeSensitive
        case .veryHigh:
            riskEmoji = "🔴"
            content.interruptionLevel = .timeSensitive
        }
        
        content.title = "\(riskEmoji) \(content.title)"
        
        content.userInfo = [
            "type": "weather_forecast",
            "riskLevel": riskLevel.rawValue
        ]
        
        content.categoryIdentifier = "weather_forecast_category"
        
        let request = UNNotificationRequest(
            identifier: "daily_weather_forecast_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送天气预报通知成功")
        } catch {
            print("❌ 发送天气预报通知失败: \(error)")
        }
    }
    
    // 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已获得")
                    
                    // 注册通知类别
                    self.registerNotificationCategories()
                } else {
                    print("❌ 通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    // 注册所有通知类别
    private func registerNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // 头痛提醒类别
        let endHeadacheAction = UNNotificationAction(
            identifier: "end_headache",
            title: "头痛已结束",
            options: [.foreground]
        )
        
        let continueHeadacheAction = UNNotificationAction(
            identifier: "continue_headache",
            title: "还在疼痛",
            options: []
        )
        
        let headacheCategory = UNNotificationCategory(
            identifier: "headache_reminder_category",
            actions: [endHeadacheAction, continueHeadacheAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(headacheCategory)
        
        // 天气预警类别
        let viewWeatherAction = UNNotificationAction(
            identifier: "view_weather_warning",
            title: "查看详情",
            options: [.foreground]
        )
        
        let dismissWeatherAction = UNNotificationAction(
            identifier: "dismiss_weather_warning",
            title: "知道了",
            options: []
        )
        
        let quickRecordAction = UNNotificationAction(
            identifier: "quick_record_headache",
            title: "快速记录头痛",
            options: [.foreground]
        )
        
        let weatherWarningCategory = UNNotificationCategory(
            identifier: "weather_warning_category",
            actions: [viewWeatherAction, quickRecordAction, dismissWeatherAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(weatherWarningCategory)
        
        // 天气预报类别
        let checkWeatherAction = UNNotificationAction(
            identifier: "check_weather_detail",
            title: "查看天气分析",
            options: [.foreground]
        )
        
        let weatherForecastCategory = UNNotificationCategory(
            identifier: "weather_forecast_category",
            actions: [checkWeatherAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(weatherForecastCategory)
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        print("✅ 已注册 \(categories.count) 个通知类别")
    }
    
    // 为未结束的头痛安排3小时间隔的提醒
    func scheduleHeadacheReminders(for record: HeadacheRecord) async {
        guard let objectIDString = record.objectID.uriRepresentation().absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 无法获取记录ID")
            return
        }
        
        // 清除该记录的现有通知
        await cancelHeadacheReminders(for: objectIDString)
        
        // 安排多个提醒（最多安排8次，即24小时）
        for i in 1...8 {
            let timeInterval = TimeInterval(i * 3 * 60 * 60) // 3小时的秒数
            let identifier = "headache_reminder_\(objectIDString)_\(i)"
            
            scheduleHeadacheReminderNotification(
                identifier: identifier,
                timeInterval: timeInterval,
                recordID: objectIDString
            )
        }
        
        print("✅ 已为记录安排8个3小时间隔的提醒")
    }
    
    // 安排单个提醒通知
    private func scheduleHeadacheReminderNotification(identifier: String, timeInterval: TimeInterval, recordID: String) {
        let content = UNMutableNotificationContent()
        content.title = "头痛状态更新"
        content.body = "你的头痛现在好些了吗？点击更新状态"
        content.sound = .default
        content.badge = 1
        
        // 添加用户信息，用于处理通知响应
        content.userInfo = [
            "type": "headache_reminder",
            "recordID": recordID
        ]
        
        content.categoryIdentifier = "headache_reminder_category"
        
        // 创建触发器
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 安排通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 安排通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 成功安排通知: \(identifier)")
            }
        }
    }
    
    // 新增：发送天气预警通知
    func sendWeatherWarningNotification(
        title: String,
        message: String,
        riskLevel: HeadacheRisk,
        warningId: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.badge = 1
        
        // 根据风险级别设置中断级别
        switch riskLevel {
        case .low:
            content.interruptionLevel = .passive
        case .moderate:
            content.interruptionLevel = .active
        case .high, .veryHigh:
            content.interruptionLevel = .timeSensitive
        }
        
        content.userInfo = [
            "type": "weather_warning",
            "warningId": warningId,
            "riskLevel": riskLevel.rawValue
        ]
        
        content.categoryIdentifier = "weather_warning_category"
        
        let request = UNNotificationRequest(
            identifier: "weather_warning_\(warningId)",
            content: content,
            trigger: nil // 立即发送
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送天气预警通知失败: \(error)")
            } else {
                print("✅ 发送天气预警通知成功: \(title)")
            }
        }
    }
    
    // 新增：发送每日天气预报通知
    func sendDailyWeatherForecast(forecast: String, riskLevel: HeadacheRisk) {
        let content = UNMutableNotificationContent()
        content.title = "今日头痛风险预报"
        content.body = forecast
        content.sound = .default
        
        // 根据风险级别设置不同的标识符和内容
        let riskEmoji: String
        switch riskLevel {
        case .low:
            riskEmoji = "✅"
            content.interruptionLevel = .passive
        case .moderate:
            riskEmoji = "⚠️"
            content.interruptionLevel = .active
        case .high:
            riskEmoji = "🔶"
            content.interruptionLevel = .timeSensitive
        case .veryHigh:
            riskEmoji = "🔴"
            content.interruptionLevel = .timeSensitive
        }
        
        content.title = "\(riskEmoji) \(content.title)"
        
        content.userInfo = [
            "type": "weather_forecast",
            "riskLevel": riskLevel.rawValue
        ]
        
        content.categoryIdentifier = "weather_forecast_category"
        
        let request = UNNotificationRequest(
            identifier: "daily_weather_forecast_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送天气预报通知失败: \(error)")
            } else {
                print("✅ 发送天气预报通知成功")
            }
        }
    }
    
    // 取消特定记录的所有提醒
    func cancelHeadacheReminders(for recordID: String) async {
            let identifiers = (1...8).map { "headache_reminder_\(recordID)_\($0)" }
            
            await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                print("✅ 已取消记录 \(recordID) 的所有提醒")
                continuation.resume()
            }
    }
    
    // Add this missing method as nonisolated
    nonisolated func handleWeatherForecastResponse(action: String) {
            Task { @MainActor in
                switch action {
                case "check_weather_detail":
                    // 打开天气分析页面
                    NotificationCenter.default.post(name: .openWeatherAnalysis, object: nil)
                default:
                    break
                }
            }
    }
    
    // 取消所有头痛提醒
    func cancelAllHeadacheReminders() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let headacheReminderIDs = requests
                    .filter { $0.identifier.hasPrefix("headache_reminder_") }
                    .map { $0.identifier }
                
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: headacheReminderIDs)
                print("✅ 已取消所有头痛提醒通知")
                continuation.resume()
            }
        }
    }
    
    // 新增：取消所有天气预警通知
    func cancelAllWeatherWarningNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let weatherWarningIDs = requests
                .filter { $0.identifier.hasPrefix("weather_warning_") || $0.identifier.hasPrefix("daily_weather_forecast_") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: weatherWarningIDs)
            print("✅ 已取消所有天气预警通知")
        }
    }
    
    // 处理用户点击"头痛已结束"的操作
    nonisolated func handleHeadacheEndAction(recordID: String) {
            Task { @MainActor in
                // This needs to access Core Data to update record
                // Since NotificationManager is independent, we use notification pattern
                let userInfo = ["recordID": recordID]
                NotificationCenter.default.post(name: .headacheEnded, object: nil, userInfo: userInfo)
                
                // Cancel subsequent reminders
                await cancelHeadacheReminders(for: recordID)
            }
    }
    
    // 处理用户点击"还在疼痛"的操作
    nonisolated func handleHeadacheContinueAction(recordID: String) {
        Task { @MainActor in
            // Let subsequent reminders continue - no special handling needed
            print("用户表示头痛仍在继续，将继续提醒")
        }
    }
}

// 扩展Notification.Name来定义自定义通知
extension Notification.Name {
    static let headacheEnded = Notification.Name("headacheEnded")
    static let openWeatherAnalysis = Notification.Name("openWeatherAnalysis")
    static let openQuickRecord = Notification.Name("openQuickRecord")
}

// 通知代理，处理用户与通知的交互
// In NotificationManager.swift - Fix the NotificationDelegate class

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // Application in foreground notification presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle user notification interactions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let type = userInfo["type"] as? String else {
            completionHandler()
            return
        }
        
        switch type {
        case "headache_reminder":
            handleHeadacheReminderResponse(response: response)
        case "weather_warning":
            handleWeatherWarningResponse(response: response)
        case "weather_forecast":
            handleWeatherForecastResponse(response: response)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleHeadacheReminderResponse(response: UNNotificationResponse) {
        guard let recordID = response.notification.request.content.userInfo["recordID"] as? String else {
            return
        }
        
        switch response.actionIdentifier {
        case "end_headache":
            // Now calling the nonisolated method - this should work
            NotificationManager.shared.handleHeadacheEndAction(recordID: recordID)
        case "continue_headache":
            // Now calling the nonisolated method - this should work
            NotificationManager.shared.handleHeadacheContinueAction(recordID: recordID)
        case UNNotificationDefaultActionIdentifier:
            print("用户点击了头痛提醒通知")
        default:
            break
        }
    }
    
    private func handleWeatherWarningResponse(response: UNNotificationResponse) {
        guard let warningId = response.notification.request.content.userInfo["warningId"] as? String else {
            return
        }
        
        // Now calling the nonisolated method - this should work
        NotificationManager.shared.handleWeatherWarningResponse(
            action: response.actionIdentifier,
            warningId: warningId
        )
    }
    
    private func handleWeatherForecastResponse(response: UNNotificationResponse) {
        // This method needs to be added to NotificationManager as nonisolated as well
        NotificationManager.shared.handleWeatherForecastResponse(action: response.actionIdentifier)
    }
}


