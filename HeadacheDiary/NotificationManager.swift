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
    
    // 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已获得")
                } else {
                    print("❌ 通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    // 为未结束的头痛安排3小时间隔的提醒
    func scheduleHeadacheReminders(for record: HeadacheRecord) {
        guard let objectIDString = record.objectID.uriRepresentation().absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 无法获取记录ID")
            return
        }
        
        // 清除该记录的现有通知
        cancelHeadacheReminders(for: objectIDString)
        
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
        
        // 添加操作按钮
        let endAction = UNNotificationAction(
            identifier: "end_headache",
            title: "头痛已结束",
            options: [.foreground]
        )
        
        let continueAction = UNNotificationAction(
            identifier: "continue_headache",
            title: "还在疼痛",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "headache_reminder_category",
            actions: [endAction, continueAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
    
    // 取消特定记录的所有提醒
    func cancelHeadacheReminders(for recordID: String) {
        let identifiers = (1...8).map { "headache_reminder_\(recordID)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("✅ 已取消记录 \(recordID) 的所有提醒")
    }
    
    // 取消所有头痛提醒
    func cancelAllHeadacheReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let headacheReminderIDs = requests
                .filter { $0.identifier.hasPrefix("headache_reminder_") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: headacheReminderIDs)
            print("✅ 已取消所有头痛提醒通知")
        }
    }
    
    // 处理用户点击"头痛已结束"的操作
    func handleHeadacheEndAction(recordID: String) {
        // 这里需要访问Core Data来更新记录
        // 由于NotificationManager是独立的，我们需要通过通知或回调来处理
        let userInfo = ["recordID": recordID]
        NotificationCenter.default.post(name: .headacheEnded, object: nil, userInfo: userInfo)
        
        // 取消该记录的后续提醒
        cancelHeadacheReminders(for: recordID)
    }
    
    // 处理用户点击"还在疼痛"的操作
    func handleHeadacheContinueAction(recordID: String) {
        // 暂时不需要特殊处理，让后续的提醒继续
        print("用户表示头痛仍在继续，将继续提醒")
    }
}

// 扩展Notification.Name来定义自定义通知
extension Notification.Name {
    static let headacheEnded = Notification.Name("headacheEnded")
}

// 通知代理，处理用户与通知的交互
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // 应用在前台时如何显示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 这里使用 UNNotificationPresentationOptions，可以使用新的选项
        if #available(iOS 14.0, *) {
            // iOS 14.0+ 使用新的选项替代已弃用的 .alert
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            // iOS 14.0 以下继续使用 .alert
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // 处理用户点击通知或通知按钮的操作
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let type = userInfo["type"] as? String,
              type == "headache_reminder",
              let recordID = userInfo["recordID"] as? String else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case "end_headache":
            NotificationManager.shared.handleHeadacheEndAction(recordID: recordID)
        case "continue_headache":
            NotificationManager.shared.handleHeadacheContinueAction(recordID: recordID)
        case UNNotificationDefaultActionIdentifier:
            // 用户点击了通知本身，可以打开应用到特定页面
            print("用户点击了头痛提醒通知")
        default:
            break
        }
        
        completionHandler()
    }
}
