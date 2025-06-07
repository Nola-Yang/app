//
//  AutoHeadacheManager.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-07.
//


import Foundation
import CoreData
import UserNotifications

class AutoHeadacheManager {
    static let shared = AutoHeadacheManager()
    
    private init() {}
    
    /// 检查并自动结束跨天的进行中头痛记录
    @MainActor
    func checkAndAutoEndOverdueHeadaches(context: NSManagedObjectContext) async {
        do {
            let allOngoing = try context.fetch(HeadacheRecord.ongoingFetchRequest())
            // 只保留“开始在今天之前”的
            let toAutoEnd = allOngoing.filter { $0.shouldAutoEnd }

            print("ℹ️ 未结束共 \(allOngoing.count) 条，需自动结束 \(toAutoEnd.count) 条")
            
            for record in toAutoEnd {
                autoEndRecord(record, context: context)
            }
            if !toAutoEnd.isEmpty {
                try context.save()
                await sendAutoEndNotification(count: toAutoEnd.count)
            }
        } catch {
            print("❌ 检查跨天头痛记录失败: \(error)")
        }
    }

    @MainActor
    func checkForYesterdayHeadaches(context: NSManagedObjectContext) async {
        do {
            let allOngoing = try context.fetch(HeadacheRecord.ongoingFetchRequest())
            // 只保留“开始在昨天”的
            let yesterdayOnes = allOngoing.filter { $0.isFromYesterday }
            print("ℹ️ 未结束共 \(allOngoing.count) 条，其中昨天开始 \(yesterdayOnes.count) 条")
            
            for record in yesterdayOnes {
                await sendYesterdayHeadacheReminder(record: record)
            }
        } catch {
            print("❌ 检查昨天头痛记录失败: \(error)")
        }
    }

    /// 自动结束单个头痛记录
    private func autoEndRecord(_ record: HeadacheRecord, context: NSManagedObjectContext) {
        guard let autoEndTime = record.autoEndTime else {
            print("❌ 无法计算自动结束时间")
            return
        }
        
        record.endTime = autoEndTime
        record.addAutoEndNote()
        
        print("✅ 自动结束头痛记录: 开始时间 \(record.timestamp?.description ?? "未知"), 结束时间 \(autoEndTime)")
    }
    
    /// 发送自动结束通知
    private func sendAutoEndNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "头痛记录自动更新"
        
        if count == 1 {
            content.body = "检测到1个跨天的进行中头痛记录，已自动结束"
        } else {
            content.body = "检测到\(count)个跨天的进行中头痛记录，已自动结束"
        }
        
        content.sound = .default
        content.categoryIdentifier = "auto_end_category"
        content.userInfo = [
            "type": "auto_end_headache",
            "count": count
        ]
        
        let request = UNNotificationRequest(
            identifier: "auto_end_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送自动结束通知成功")
        } catch {
            print("❌ 发送自动结束通知失败: \(error)")
        }
    }
    
    
    /// 发送昨天头痛记录的提醒
    private func sendYesterdayHeadacheReminder(record: HeadacheRecord) async {
        let content = UNMutableNotificationContent()
        content.title = "头痛记录提醒"
        content.body = "您有一个昨天开始的头痛记录尚未结束，是否需要更新状态？"
        content.sound = .default
        content.categoryIdentifier = "yesterday_headache_category"
        
        // 添加操作按钮
        await setupYesterdayNotificationActions()
        
        content.userInfo = [
            "type": "yesterday_headache",
            "recordID": record.objectID.uriRepresentation().absoluteString
        ]
        
        let request = UNNotificationRequest(
            identifier: "yesterday_headache_\(record.objectID.uriRepresentation().absoluteString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 发送昨天头痛记录提醒成功")
        } catch {
            print("❌ 发送昨天头痛记录提醒失败: \(error)")
        }
    }
    
    /// 设置昨天头痛记录的通知操作按钮
    private func setupYesterdayNotificationActions() async {
        let endYesterdayAction = UNNotificationAction(
            identifier: "end_yesterday",
            title: "昨晚已结束",
            options: [.foreground]
        )
        
        let stillOngoingAction = UNNotificationAction(
            identifier: "still_ongoing",
            title: "仍在继续",
            options: []
        )
        
        let updateAction = UNNotificationAction(
            identifier: "update_record",
            title: "打开应用",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "yesterday_headache_category",
            actions: [endYesterdayAction, stillOngoingAction, updateAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// 手动结束指定的头痛记录
    @MainActor
    func manuallyEndRecord(recordID: String, context: NSManagedObjectContext, endTime: Date? = nil) {
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
            
            // 如果指定了结束时间，使用指定时间；否则使用当前时间
            let finalEndTime = endTime ?? Date()
            record.endNow(with: finalEndTime)
            record.addManualEndNote()
            
            try context.save()
            print("✅ 手动结束头痛记录成功，结束时间: \(finalEndTime)")
            
            // 取消该记录的所有待发送提醒
            Task {
                await cancelRemindersForRecord(recordID: recordID)
            }
            
        } catch {
            print("❌ 手动结束头痛记录失败: \(error)")
        }
    }
    
    /// 将昨天的头痛记录标记为昨晚结束
    @MainActor
    func endYesterdayRecord(recordID: String, context: NSManagedObjectContext) {
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
            
            // 使用自动结束时间（开始日期的23:59:59）
            if let autoEndTime = record.autoEndTime {
                record.endTime = autoEndTime
                record.addAutoEndNote()
                
                try context.save()
                print("✅ 头痛记录已标记为昨晚结束")
                
                // 取消相关提醒
                Task {
                    await cancelRemindersForRecord(recordID: recordID)
                }
            }
            
        } catch {
            print("❌ 结束昨天头痛记录失败: \(error)")
        }
    }
    
    /// 取消指定记录的所有提醒通知
    private func cancelRemindersForRecord(recordID: String) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        let identifiersToCancel = pendingRequests.compactMap { request in
            if let requestRecordID = request.content.userInfo["recordID"] as? String,
               requestRecordID == recordID {
                return request.identifier
            }
            return nil
        }
        
        if !identifiersToCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("✅ 取消了 \(identifiersToCancel.count) 个相关提醒通知")
        }
    }
    
    /// 获取所有进行中的头痛记录统计
    @MainActor
    func getOngoingHeadacheStats(context: NSManagedObjectContext) -> (total: Int, shouldAutoEnd: Int, yesterday: Int) {
        do {
            let ongoingCount = try context.count(for: HeadacheRecord.ongoingFetchRequest())
            let shouldAutoEndCount = try context.count(for: HeadacheRecord.recordsToAutoEndFetchRequest())
            let yesterdayCount = try context.count(for: HeadacheRecord.yesterdayOngoingFetchRequest())
            
            return (total: ongoingCount, shouldAutoEnd: shouldAutoEndCount, yesterday: yesterdayCount)
        } catch {
            print("❌ 获取进行中头痛记录统计失败: \(error)")
            return (total: 0, shouldAutoEnd: 0, yesterday: 0)
        }
    }
    
    /// 清理所有自动结束相关的通知
    func cleanupAutoEndNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        let identifiersToCancel = pendingRequests.compactMap { request in
            if let type = request.content.userInfo["type"] as? String,
               type == "auto_end_headache" || type == "yesterday_headache" {
                return request.identifier
            }
            return nil
        }
        
        if !identifiersToCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("✅ 清理了 \(identifiersToCancel.count) 个自动结束相关通知")
        }
    }
    
    /// 每日检查任务（建议在应用启动时调用）
    @MainActor
    func performDailyCheck(context: NSManagedObjectContext) async {
        // 自动结束跨天的记录
        await checkAndAutoEndOverdueHeadaches(context: context)
        
        // 检查昨天开始的记录，发送提醒
        await checkForYesterdayHeadaches(context: context)
    }
}
