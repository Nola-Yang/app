//
//  HeadacheRecord+CoreDataProperties.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import Foundation
import CoreData

extension HeadacheRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HeadacheRecord> {
        return NSFetchRequest<HeadacheRecord>(entityName: "HeadacheRecord")
    }

    // 基本信息
    @NSManaged public var timestamp: Date?
    @NSManaged public var intensity: Int16
    @NSManaged public var note: String?
    
    // 疼痛位置
    @NSManaged public var locationFace: Bool
    @NSManaged public var locationForehead: Bool
    @NSManaged public var locationLeftSide: Bool
    @NSManaged public var locationRightSide: Bool
    @NSManaged public var locationTemple: Bool
    
    // 用药信息
    @NSManaged public var tookMedicine: Bool
    @NSManaged public var medicineTime: Date?
    @NSManaged public var medicineType: String?
    @NSManaged public var medicineRelief: Bool
    
    // 触发因素 (新增)
    @NSManaged public var triggers: String?
    
    // 疼痛特征 (移除了 isVascular)
    @NSManaged public var hasTinnitus: Bool
    @NSManaged public var hasThrobbing: Bool
    
    // 时间范围
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
}

// MARK: - 便利属性和方法
extension HeadacheRecord {
    
    // 获取疼痛位置的便利属性
    var locationNames: [String] {
        var locations: [String] = []
        if locationForehead { locations.append("额头") }
        if locationLeftSide { locations.append("左侧") }
        if locationRightSide { locations.append("右侧") }
        if locationTemple { locations.append("太阳穴") }
        if locationFace { locations.append("面部") }
        return locations
    }
    
    // 获取触发因素的便利属性
    var triggerNames: [String] {
        guard let triggersString = triggers else { return [] }
        let triggerStrings = triggersString.components(separatedBy: ",")
        return triggerStrings.compactMap { triggerString in
            HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces))?.displayName
        }
    }
    
    // 获取触发因素枚举数组
    var triggerObjects: [HeadacheTrigger] {
        guard let triggersString = triggers else { return [] }
        let triggerStrings = triggersString.components(separatedBy: ",")
        return triggerStrings.compactMap { triggerString in
            HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces))
        }
    }
    
    // 获取症状标签的便利属性
    var symptomTags: [String] {
        var symptoms: [String] = []
        if hasTinnitus { symptoms.append("耳鸣") }
        if hasThrobbing { symptoms.append("跳动") }
        return symptoms
    }
    
    // 计算持续时间的便利方法
    var durationText: String? {
        guard let start = startTime, let end = endTime else { return nil }
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    // 获取药物名称
    var medicineName: String? {
        guard let typeString = medicineType,
              let type = MedicineType(rawValue: typeString) else {
            return nil
        }
        return type.displayName
    }
    
    // 检查头痛是否正在进行中
    var isOngoing: Bool {
        return startTime != nil && endTime == nil
    }
    
    // 获取头痛强度颜色
    var intensityColor: String {
        switch intensity {
        case 1...3: return "green"
        case 4...6: return "yellow"
        case 7...8: return "orange"
        case 9...10: return "red"
        default: return "gray"
        }
    }
    
    // 设置触发因素（从枚举数组）
    func setTriggers(_ triggerArray: [HeadacheTrigger]) {
        if triggerArray.isEmpty {
            triggers = nil
        } else {
            triggers = triggerArray.map { $0.rawValue }.joined(separator: ",")
        }
    }
    
    // 添加触发因素
    func addTrigger(_ trigger: HeadacheTrigger) {
        var currentTriggers = triggerObjects
        if !currentTriggers.contains(trigger) {
            currentTriggers.append(trigger)
            setTriggers(currentTriggers)
        }
    }
    
    // 移除触发因素
    func removeTrigger(_ trigger: HeadacheTrigger) {
        var currentTriggers = triggerObjects
        currentTriggers.removeAll { $0 == trigger }
        setTriggers(currentTriggers)
    }
}
