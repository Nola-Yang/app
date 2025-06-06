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
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // 应用启动时清理过期的通知
                    HeadacheDiaryApp.cleanupExpiredNotifications()
                }
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
            let expiredIdentifiers = requests.compactMap { request -> String? in
                guard let trigger = request.trigger as? UNTimeIntervalNotificationTrigger else {
                    return nil
                }
                
                // 如果通知是超过24小时前安排的，就认为是过期的
                let scheduleDate = trigger.nextTriggerDate()
                if let scheduleDate = scheduleDate, scheduleDate.timeIntervalSince(now) < -24 * 60 * 60 {
                    return request.identifier
                }
                return nil
            }
            
            if !expiredIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIdentifiers)
                print("✅ 已清理 \(expiredIdentifiers.count) 个过期通知")
            }
        }
    }
}
