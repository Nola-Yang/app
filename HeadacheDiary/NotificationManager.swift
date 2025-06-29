//
//  NotificationManager.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import Foundation
import UserNotifications
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - 通知权限管理
    @MainActor
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .provisional] 
        ) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已获得（不包括Badge）")
                    self.registerNotificationCategories()
                } else {
                    print("❌ 通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    // MARK: - 注册通知类别
    private func registerNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // 头痛提醒类别
        let endHeadacheAction = UNNotificationAction(
                identifier: "end_headache_confirm",
                title: "结束头痛记录",
                options: []
        )
        
        let continueHeadacheAction = UNNotificationAction(
            identifier: "continue_headache",
            title: "还在疼痛",
            options: [.foreground]
        )
        
        let headacheCategory = UNNotificationCategory(
            identifier: "headache_reminder_category",
            actions: [endHeadacheAction, continueHeadacheAction],
            intentIdentifiers: [],
            options: []
        )
        
        let confirmationCategory = UNNotificationCategory(
            identifier: "headache_confirmation_category",
            actions: [endHeadacheAction],
            intentIdentifiers: [],
            options: []
        )
        
        let endHeadacheConfirmAction = UNNotificationAction(
            identifier: "end_headache_confirm",
            title: "结束头痛记录",
            options: []
        )
        categories.insert(headacheCategory)
        
        // 正在进行的头痛类别
        let quickEndAction = UNNotificationAction(
            identifier: "quick_end_headache",
            title: "快速结束",
            options: []
        )
        
        let updateRecordAction = UNNotificationAction(
            identifier: "update_record",
            title: "更新记录",
            options: [.foreground]
        )
        
        let ongoingHeadacheCategory = UNNotificationCategory(
            identifier: "ongoing_headache_category",
            actions: [quickEndAction, updateRecordAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(ongoingHeadacheCategory)
        
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
        
        // 预测预警类别
        let viewPredictiveAlertAction = UNNotificationAction(
            identifier: "view_predictive_alert",
            title: "查看详情",
            options: [.foreground]
        )
        
        let dismissPredictiveAlertAction = UNNotificationAction(
            identifier: "dismiss_predictive_alert",
            title: "知道了",
            options: []
        )
        
        let predictiveAlertCategory = UNNotificationCategory(
            identifier: "predictive_alert_category",
            actions: [viewPredictiveAlertAction, dismissPredictiveAlertAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(predictiveAlertCategory)
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        print("✅ 已注册 \(categories.count) 个通知类别")
    }
    
    // MARK: - 头痛提醒通知
    func scheduleHeadacheReminder(for record: HeadacheRecord, reminderMinutes: Int = 60) {
        guard record.endTime == nil else {
            print("⚠️ 头痛已结束，不发送提醒")
            return
        }
        
        // 获取记录ID字符串 - 修复版本
        let recordIDString = record.objectID.uriRepresentation().absoluteString
        
        let content = UNMutableNotificationContent()
        content.title = "头痛状态提醒"
        content.body = "您的头痛记录已持续 \(reminderMinutes) 分钟，请更新您的状态"
        content.sound = .default
        content.badge = NSNumber(value: 1)
        
        // 设置为时间敏感通知
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        // 添加用户信息
        content.userInfo = [
            "type": "headache_reminder",
            "recordID": recordIDString,
            "startTime": record.startTime?.timeIntervalSince1970 ?? 0,
            "severity": record.intensity
        ]
        
        // 设置通知类别
        content.categoryIdentifier = "ongoing_headache_category"
        
        // 设置触发时间
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(reminderMinutes * 60),
            repeats: false
        )
        
        let identifier = "headache_reminder_\(recordIDString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送头痛提醒失败: \(error)")
            } else {
                print("✅ 已安排头痛提醒，\(reminderMinutes)分钟后触发")
            }
        }
    }
    
    // MARK: - 发送快速结束提醒
    func sendQuickEndReminder(for record: HeadacheRecord) {
        // 获取记录ID字符串
        let recordIDString = record.objectID.uriRepresentation().absoluteString
        
        let content = UNMutableNotificationContent()
        content.title = "快速操作"
        content.body = "头痛还在持续吗？"
        content.sound = .default
        
        content.userInfo = [
            "type": "quick_end_reminder",
            "recordID": recordIDString
        ]
        
        content.categoryIdentifier = "ongoing_headache_category"
        
        let request = UNNotificationRequest(
            identifier: "quick_end_\(recordIDString)",
            content: content,
            trigger: nil // 立即发送
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送快速结束提醒失败: \(error)")
            } else {
                print("✅ 已发送快速结束提醒")
            }
        }
    }
    
    // MARK: - 天气通知
    @MainActor
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
        if #available(iOS 15.0, *) {
            switch riskLevel {
            case .low:
                content.interruptionLevel = .passive
            case .moderate:
                content.interruptionLevel = .active
            case .high, .veryHigh:
                content.interruptionLevel = .timeSensitive
            }
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
    
    @MainActor
    func sendDailyWeatherForecast(forecast: String, riskLevel: HeadacheRisk) async {
        let content = UNMutableNotificationContent()
        content.title = "今日头痛风险预报"
        content.body = forecast
        content.sound = .default
        
        // 根据风险级别设置不同的标识符和内容
        let riskEmoji: String
        if #available(iOS 15.0, *) {
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
        } else {
            switch riskLevel {
            case .low:
                riskEmoji = "✅"
            case .moderate:
                riskEmoji = "⚠️"
            case .high:
                riskEmoji = "🔶"
            case .veryHigh:
                riskEmoji = "🔴"
            }
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
    
    @MainActor
    func sendPredictiveAlert(
        title: String,
        body: String,
        alertDate: Date,
        riskLevel: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // 根据风险级别设置中断级别
        if #available(iOS 15.0, *) {
            switch riskLevel {
            case "low":
                content.interruptionLevel = .passive
            case "medium":
                content.interruptionLevel = .active
            case "high", "critical":
                content.interruptionLevel = .timeSensitive
            default:
                content.interruptionLevel = .active
            }
        }
        
        content.userInfo = [
            "type": "predictive_alert",
            "alertDate": alertDate.timeIntervalSince1970,
            "riskLevel": riskLevel
        ]
        
        content.categoryIdentifier = "predictive_alert_category"
        
        let request = UNNotificationRequest(
            identifier: "predictive_alert_\(alertDate.timeIntervalSince1970)",
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送预测预警通知成功: \(title)")
        } catch {
            print("❌ 发送预测预警通知失败: \(error)")
        }
    }
    
    // MARK: - 取消通知
    func cancelHeadacheReminders(for recordID: String) async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let headacheReminderIDs = requests
                    .filter { $0.identifier.contains(recordID) }
                    .map { $0.identifier }
                
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: headacheReminderIDs)
                print("✅ 已取消记录 \(recordID) 的所有提醒通知")
                continuation.resume()
            }
        }
    }
    
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
    
    func cancelAllWeatherWarningNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let weatherWarningIDs = requests
                .filter { $0.identifier.hasPrefix("weather_warning_") || $0.identifier.hasPrefix("daily_weather_forecast_") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: weatherWarningIDs)
            print("✅ 已取消所有天气预警通知")
        }
    }
    
    // MARK: - 处理用户操作 (nonisolated methods)
    nonisolated func handleHeadacheEndAction(recordID: String) {
        Task { @MainActor in
            let userInfo = ["recordID": recordID]
            NotificationCenter.default.post(name: .headacheEnded, object: nil, userInfo: userInfo)
            
            // Cancel subsequent reminders
            await cancelHeadacheReminders(for: recordID)
            sendConfirmationNotification(
                title: "头痛已结束",
                body: "点击查看详情，或使用按钮重新结束记录",
                recordID: recordID
            )
        }
    }
    
    nonisolated func handleHeadacheContinueAction(recordID: String) {
        DispatchQueue.main.async {
            // 发送打开特定记录的通知
            let userInfo = ["recordID": recordID]
            NotificationCenter.default.post(name: .openHeadacheEdit, object: nil, userInfo: userInfo)
        }
    }
    
    func handleQuickEndAction(recordID: String) {
        handleHeadacheEndAction(recordID: recordID)
    }
    
    func handlePostponeAction(recordID: String) {
        Task {
            if let record = await getHeadacheRecord(by: recordID) {
                scheduleHeadacheReminder(for: record, reminderMinutes: 30)
            }
        }
    }
    
    nonisolated func handleWeatherWarningResponse(action: String, warningId: String) {
        Task { @MainActor in
            switch action {
            case "view_weather_warning":
                NotificationCenter.default.post(
                    name: .openWeatherAnalysis,
                    object: nil,
                    userInfo: ["warningId": warningId]
                )
            case "quick_record_headache":
                NotificationCenter.default.post(
                    name: .openQuickRecord,
                    object: nil,
                    userInfo: ["source": "weather_warning"]
                )
            case "dismiss_weather_warning":
                if let uuid = UUID(uuidString: warningId) {
                    WeatherWarningManager.shared.markWarningAsRead(uuid)
                }
            default:
                break
            }
        }
    }
    
    nonisolated func handleWeatherForecastResponse(action: String) {
        Task { @MainActor in
            switch action {
            case "check_weather_detail":
                NotificationCenter.default.post(name: .openWeatherAnalysis, object: nil)
            default:
                break
            }
        }
    }
    
    // MARK: - 确认通知
    private func sendConfirmationNotification(title: String, body: String, recordID: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "headache_confirmation_category"
        
        content.userInfo = [
            "type": "confirmation",
            "recordID": recordID
        ]
        
        let request = UNNotificationRequest(
            identifier: "confirmation_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送确认通知失败: \(error)")
            } else {
                print("✅ 已发送确认通知")
            }
        }
    }
    
    // MARK: - 辅助方法
    private func getHeadacheRecord(by recordID: String) async -> HeadacheRecord? {
        return await withCheckedContinuation { continuation in
            let context = PersistenceController.shared.container.viewContext
            context.perform {
                // 首先尝试UUID
                if let uuid = UUID(uuidString: recordID) {
                    let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                    request.fetchLimit = 1
                    
                    do {
                        let records = try context.fetch(request)
                        if let record = records.first {
                            continuation.resume(returning: record)
                            return
                        }
                    } catch {
                        print("❌ 通过UUID获取头痛记录失败: \(error)")
                    }
                }
                
                // 如果UUID失败，尝试通过objectID URI
                if let url = URL(string: recordID),
                   let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
                    do {
                        let record = try context.existingObject(with: objectID) as? HeadacheRecord
                        continuation.resume(returning: record)
                        return
                    } catch {
                        print("❌ 通过ObjectID获取头痛记录失败: \(error)")
                    }
                }
                
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - 验证和清理
    func validateAndSendReminder(for recordID: String, context: NSManagedObjectContext) async {
        // 首先尝试UUID解析
        if let uuid = UUID(uuidString: recordID) {
            let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            
            do {
                let records = try context.fetch(request)
                guard let record = records.first else {
                    print("❌ 找不到头痛记录")
                    return
                }
                
                if record.endTime != nil {
                    print("⚠️ 记录已结束，取消相关提醒")
                    await cancelHeadacheReminders(for: recordID)
                    return
                }
                
                print("✅ 记录仍在进行中，可以发送提醒")
                
            } catch {
                print("❌ 验证记录状态失败: \(error)")
            }
            return
        }
        
        // 尝试ObjectID URI解析
        guard let decodedString = recordID.removingPercentEncoding,
              let url = URL(string: decodedString),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            print("❌ 无法解析记录ID: \(recordID)")
            return
        }
        
        do {
            guard let record = try context.existingObject(with: objectID) as? HeadacheRecord else {
                print("❌ 找不到头痛记录")
                return
            }
            
            if record.endTime != nil {
                print("⚠️ 记录已结束，取消相关提醒")
                await cancelHeadacheReminders(for: recordID)
                return
            }
            
            print("✅ 记录仍在进行中，可以发送提醒")
            
        } catch {
            print("❌ 验证记录状态失败: \(error)")
        }
    }
    
    // MARK: - 清理方法
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

// MARK: - 扩展：清理孤儿通知
extension NotificationManager {
    func cleanupOrphanedNotifications(context: NSManagedObjectContext) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        var orphanedIdentifiers: [String] = []
        
        for request in pendingRequests {
            // 检查头痛提醒通知
            if request.identifier.hasPrefix("headache_reminder_"),
               let recordIDString = request.content.userInfo["recordID"] as? String {
                
                // 检查记录是否仍然存在
                if !recordExists(recordID: recordIDString, context: context) {
                    orphanedIdentifiers.append(request.identifier)
                }
            }
        }
        
        if !orphanedIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphanedIdentifiers)
            print("✅ 清理了 \(orphanedIdentifiers.count) 个孤儿通知")
        }
    }
    
    /// 检查记录是否存在
    private func recordExists(recordID: String, context: NSManagedObjectContext) -> Bool {
        // 首先尝试UUID
        if let uuid = UUID(uuidString: recordID) {
            let request: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            
            do {
                let count = try context.count(for: request)
                return count > 0
            } catch {
                print("❌ 检查记录存在性失败: \(error)")
            }
        }
        
        // 如果UUID失败，尝试通过objectID URI
        guard let decodedString = recordID.removingPercentEncoding,
              let url = URL(string: decodedString),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            return false
        }
        
        do {
            _ = try context.existingObject(with: objectID)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let headacheEnded = Notification.Name("headacheEnded")
    static let openWeatherAnalysis = Notification.Name("openWeatherAnalysis")
    static let openQuickRecord = Notification.Name("openQuickRecord")
    static let openHeadacheList = Notification.Name("openHeadacheList")
    static let openHeadacheEdit = Notification.Name("openHeadacheEdit")
    static let notificationActionPerformed = Notification.Name("notificationActionPerformed")
    static let openHeadacheUpdate = Notification.Name("openHeadacheUpdate")
}

// MARK: - 通知代理
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // Application in foreground notification presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // Handle user notification interactions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        guard let type = userInfo["type"] as? String else {
            completionHandler()
            return
        }
        
        print("📱 收到通知交互 - 类型: \(type), 操作: \(actionIdentifier)")
        
        // 根据通知类型处理
        switch type {
        case "headache_reminder", "quick_end_reminder", "ongoing_headache":
            handleHeadacheNotificationResponse(response: response, userInfo: userInfo)
        case "weather_warning":
            handleWeatherWarningResponse(response: response, userInfo: userInfo)
        case "weather_forecast":
            handleWeatherForecastResponse(response: response, userInfo: userInfo)
        case "auto_end_headache":
            handleAutoEndNotification(response: response, userInfo: userInfo)
        case "yesterday_headache":
            handleYesterdayHeadacheNotification(response: response, userInfo: userInfo)
        case "confirmation":
            handleConfirmationNotification(response: response, userInfo: userInfo)
        default:
            print("⚠️ 未知通知类型: \(type)")
        }
        
        completionHandler()
    }
    
    // MARK: - 通知响应处理方法
    private func handleHeadacheNotificationResponse(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        guard let recordID = userInfo["recordID"] as? String else {
            print("❌ 缺少recordID")
            return
        }
        
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "end_headache", "quick_end_headache":
            NotificationManager.shared.handleHeadacheEndAction(recordID: recordID)
            print("✅ 用户选择结束头痛")
            
        case "open_record", "update_record", "continue_headache":
            openHeadacheUpdateState(recordID: recordID)
            print("✅ 用户选择进入更新状态")
            
        case "postpone_reminder":
            NotificationManager.shared.handlePostponeAction(recordID: recordID)
            print("✅ 用户选择延迟提醒")
            
        case UNNotificationDefaultActionIdentifier:
            openHeadacheUpdateState(recordID: recordID)
            print("✅ 用户点击通知，打开对应记录")
            
        case UNNotificationDismissActionIdentifier:
            print("📱 用户删除了通知")
            
        default:
            openHeadacheList()
            print("📱 默认行为：打开记录列表")
        }
        
        func openHeadacheUpdateState(recordID: String) {
            DispatchQueue.main.async {
                let userInfo = ["recordID": recordID, "action": "update_state"]
                NotificationCenter.default.post(
                    name: .openHeadacheUpdate, // 新的通知名称
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }
    
    private func handleWeatherWarningResponse(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "view_weather_warning":
            openWeatherAnalysis()
            print("✅ 用户选择查看天气详情")
            
        case "quick_record_headache":
            openQuickRecord()
            print("✅ 用户选择快速记录头痛")
            
        case "dismiss_weather_warning":
            print("📱 用户忽略天气预警")
            
        case UNNotificationDefaultActionIdentifier:
            openWeatherAnalysis()
            print("✅ 用户点击天气预警通知")
            
        default:
            openWeatherAnalysis()
        }
    }
    
    private func handleWeatherForecastResponse(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "check_weather_detail":
            openWeatherAnalysis()
            print("✅ 用户选择查看天气预报详情")
            
        case "quick_record_headache":
            openQuickRecord()
            print("✅ 用户从天气预报选择快速记录")
            
        case UNNotificationDefaultActionIdentifier:
            openWeatherAnalysis()
            print("✅ 用户点击天气预报通知")
            
        default:
            openWeatherAnalysis()
        }
    }
    
    private func handleAutoEndNotification(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            openHeadacheList()
            print("✅ 打开记录列表查看自动结束的记录")
            
        default:
            openHeadacheList()
        }
    }
    
    private func handleYesterdayHeadacheNotification(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "end_yesterday":
            if let recordIDString = userInfo["recordID"] as? String {
                markYesterdayRecordAsEnded(recordID: recordIDString)
            }
            print("✅ 用户选择昨晚已结束")
            
        case "still_ongoing":
            print("📱 用户选择头痛仍在继续")
            
        case "update_record":
            if let recordID = userInfo["recordID"] as? String {
                openHeadacheRecord(recordID: recordID)
            }
            print("✅ 用户选择打开应用更新记录")
            
        case UNNotificationDefaultActionIdentifier:
            if let recordID = userInfo["recordID"] as? String {
                openHeadacheRecord(recordID: recordID)
            } else {
                openHeadacheList()
            }
            
        default:
            openHeadacheList()
        }
    }
    
    private func handleConfirmationNotification(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier
        
        guard let recordID = userInfo["recordID"] as? String else {
            print("❌ 确认通知缺少recordID")
            return
        }
        
        switch actionIdentifier {
        case "end_headache_confirm":
            // 用户点击了"结束头痛记录"按钮
            endHeadacheFromConfirmation(recordID: recordID)
            print("✅ 用户通过确认通知结束头痛记录")
            
        case UNNotificationDefaultActionIdentifier:
            // 用户直接点击通知 - 跳转到编辑页面
            openHeadacheEditPage(recordID: recordID)
            print("✅ 用户点击确认通知，跳转到编辑页面")
            
        case UNNotificationDismissActionIdentifier:
            print("📱 用户删除了确认通知")
            
        default:
            // 默认行为：跳转到编辑页面
            openHeadacheEditPage(recordID: recordID)
            print("📱 默认行为：跳转到编辑页面")
        }
    }
    
    // MARK: - 导航辅助方法
    private func openHeadacheRecord(recordID: String) {
        DispatchQueue.main.async {
            let userInfo = ["recordID": recordID]
            NotificationCenter.default.post(
                name: .openHeadacheEdit,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    // 专门用于编辑页面跳转
    private func openHeadacheEditPage(recordID: String) {
        DispatchQueue.main.async {
            let userInfo = ["recordID": recordID]
            NotificationCenter.default.post(
                name: .openHeadacheEdit,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    // 从确认通知结束头痛记录
    private func endHeadacheFromConfirmation(recordID: String) {
        DispatchQueue.main.async {
            let userInfo = ["recordID": recordID, "source": "confirmation"]
            NotificationCenter.default.post(
                name: .headacheEnded,
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    private func openHeadacheList() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openHeadacheList, object: nil)
        }
    }
    
    private func openWeatherAnalysis() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openWeatherAnalysis, object: nil)
        }
    }
    
    private func openQuickRecord() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openQuickRecord, object: nil)
        }
    }
    
    private func markYesterdayRecordAsEnded(recordID: String) {
        DispatchQueue.main.async {
            AutoHeadacheManager.shared.endYesterdayRecord(
                recordID: recordID,
                context: PersistenceController.shared.container.viewContext
            )
        }
    }
}
