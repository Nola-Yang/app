//
//  HeadacheRecord+AutoEnd.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-07.
//


import Foundation
import CoreData

extension HeadacheRecord {
    
    /// 检查头痛记录是否应该自动结束（开始时间不是今天）
    var shouldAutoEnd: Bool {
            guard let start = timestamp, endTime == nil else { return false }
            let cal      = Calendar.current
            let startDay = cal.startOfDay(for: start)
            let today    = cal.startOfDay(for: Date())
            return startDay < today
    }
    
    /// 检查头痛记录是否是昨天开始的（用于发送提醒）
    var isFromYesterday: Bool {
        guard let start = timestamp, endTime == nil else { return false }
        let cal            = Calendar.current
        let todayStart     = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
        return cal.startOfDay(for: start) == yesterdayStart
    }
    
    /// 获取应该自动结束的时间（开始日期的当天结尾）
    var autoEndTime: Date? {
            guard let start = timestamp else { return nil }
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: start)
            comps.hour   = 23
            comps.minute = 59
            comps.second = 59
            return Calendar.current.date(from: comps)
    }

    
    /// 获取头痛开始日期的描述
    var startDateDescription: String {
            guard let startTime = timestamp else { return "未知" }
            let cal = Calendar.current
            if cal.isDateInToday(startTime) {
                return "今天"
            } else if cal.isDateInYesterday(startTime) {
                return "昨天"
            } else {
                let f = DateFormatter()
                f.dateFormat = "yyyy年M月d日"
                return f.string(from: startTime)
            }
    }
    
    /// 获取进行中头痛记录的 fetch request
    static func ongoingFetchRequest() -> NSFetchRequest<HeadacheRecord> {
        let req: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
        req.predicate = NSPredicate(format: "endTime == nil")
        req.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.startTime, ascending: false)]
        return req
    }
    
    /// 获取需要自动结束的头痛记录（开始时间不是今天）
    static func recordsToAutoEndFetchRequest() -> NSFetchRequest<HeadacheRecord> {
        let req: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
        let todayStart = Calendar.current.startOfDay(for: Date())
        req.predicate = NSPredicate(format: "startTime < %@ AND endTime == nil", todayStart as NSDate)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.startTime, ascending: false)]
        return req
    }
    
    /// 获取昨天开始的进行中头痛记录（用于发送提醒）
    static func yesterdayOngoingFetchRequest() -> NSFetchRequest<HeadacheRecord> {
            let req: NSFetchRequest<HeadacheRecord> = HeadacheRecord.fetchRequest()
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
            req.predicate = NSPredicate(
                format: "startTime >= %@ AND startTime < %@ AND endTime == nil",
                yesterdayStart as NSDate,
                todayStart as NSDate
            )
            req.sortDescriptors = [NSSortDescriptor(keyPath: \HeadacheRecord.startTime, ascending: false)]
            return req
    }
    
    /// 手动结束头痛记录
    func endNow(with endTime: Date = Date(), note: String? = nil) {
        self.endTime = endTime
        
        if let note = note {
            if let existingNote = self.note, !existingNote.isEmpty {
                self.note = existingNote + "\n" + note
            } else {
                self.note = note
            }
        }
        
        Task {
            await cancelRemindersForThisRecord()
        }
    }
    
    /// 添加自动结束标记到备注
    func addAutoEndNote() {
        let autoEndNote = "系统自动结束（跨天）"
        if let existingNote = note, !existingNote.isEmpty {
            note = existingNote + "\n" + autoEndNote
        } else {
            note = autoEndNote
        }
        
        Task {
            await cancelRemindersForThisRecord()
        }
    }
    
    /// 添加手动结束标记到备注
    func addManualEndNote() {
        let manualEndNote = "用户手动结束"
        if let existingNote = note, !existingNote.isEmpty {
            note = existingNote + "\n" + manualEndNote
        } else {
            note = manualEndNote
        }
        
        Task {
            await cancelRemindersForThisRecord()
        }
    }
    
    private func cancelRemindersForThisRecord() async {
        guard let recordIDString = objectID.uriRepresentation().absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 无法获取记录ID用于取消通知")
            return
        }
        
        await NotificationManager.shared.cancelHeadacheReminders(for: recordIDString)
        print("✅ 已取消记录的所有提醒通知")
    }
    
    /// 新增：检查记录是否可以发送提醒
    var canSendReminders: Bool {
        return endTime == nil // 只有未结束的记录才能发送提醒
    }
}
