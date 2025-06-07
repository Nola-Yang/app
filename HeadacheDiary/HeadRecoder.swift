//
//  HeadRecoder.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import Foundation
import CoreData

@objc(HeadacheRecord)
public class HeadacheRecord: NSManagedObject {

}

extension HeadacheRecord: Identifiable {
    public var id: NSManagedObjectID {
        return self.objectID
    }
}




extension HeadacheRecord {
    
    // 获取所有疼痛位置（包括自定义）
    var allLocationNames: [String] {
        var locations: [String] = []
        
        // 预定义位置
        if locationForehead { locations.append("额头") }
        if locationLeftSide { locations.append("左侧") }
        if locationRightSide { locations.append("右侧") }
        if locationTemple { locations.append("太阳穴") }
        if locationFace { locations.append("面部") }
        
        // 自定义位置
        if let customLocationsString = customLocations {
            let customLocationArray = customLocationsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            locations.append(contentsOf: customLocationArray)
        }
        
        return locations
    }
    
    // 获取预定义疼痛位置
    var locationNames: [String] {
        var locations: [String] = []
        if locationForehead { locations.append("额头") }
        if locationLeftSide { locations.append("左侧") }
        if locationRightSide { locations.append("右侧") }
        if locationTemple { locations.append("太阳穴") }
        if locationFace { locations.append("面部") }
        return locations
    }
    
    // 获取自定义疼痛位置
    var customLocationNames: [String] {
        guard let customLocationsString = customLocations else { return [] }
        return customLocationsString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // 获取所有触发因素（包括自定义）
    var allTriggerNames: [String] {
        var allTriggers: [String] = []
        
        // 预定义触发因素
        allTriggers.append(contentsOf: triggerNames)
        
        // 自定义触发因素
        allTriggers.append(contentsOf: customTriggerNames)
        
        return allTriggers
    }
    
    // 获取预定义触发因素名称
    var triggerNames: [String] {
        guard let triggersString = triggers else { return [] }
        let triggerStrings = triggersString.components(separatedBy: ",")
        return triggerStrings.compactMap { triggerString in
            HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces))?.displayName
        }
    }
    
    // 获取预定义触发因素枚举数组
    var triggerObjects: [HeadacheTrigger] {
        guard let triggersString = triggers else { return [] }
        let triggerStrings = triggersString.components(separatedBy: ",")
        return triggerStrings.compactMap { triggerString in
            HeadacheTrigger(rawValue: triggerString.trimmingCharacters(in: .whitespaces))
        }
    }
    
    // 获取自定义触发因素
    var customTriggerNames: [String] {
        guard let customTriggersString = customTriggers else { return [] }
        return customTriggersString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // 获取所有药物（包括自定义）
    var allMedicineNames: [String] {
        var medicines: [String] = []
        
        // 预定义药物
        if let medicineName = medicineName {
            medicines.append(medicineName)
        }
        
        // 自定义药物
        medicines.append(contentsOf: customMedicineNames)
        
        return medicines
    }
    
    // 获取自定义药物
    var customMedicineNames: [String] {
        guard let customMedicinesString = customMedicines else { return [] }
        return customMedicinesString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // 获取所有症状（包括自定义）
    var allSymptomTags: [String] {
        var symptoms: [String] = []
        
        // 预定义症状
        symptoms.append(contentsOf: symptomTags)
        
        // 自定义症状
        symptoms.append(contentsOf: customSymptomNames)
        
        return symptoms
    }
    
    // 获取预定义症状标签
    var symptomTags: [String] {
        var symptoms: [String] = []
        if hasTinnitus { symptoms.append("耳鸣") }
        if hasThrobbing { symptoms.append("跳动") }
        return symptoms
    }
    
    // 获取自定义症状
    var customSymptomNames: [String] {
        guard let customSymptomsString = customSymptoms else { return [] }
        return customSymptomsString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
    
    // 设置自定义位置
    func setCustomLocations(_ locations: [String]) {
        customLocations = locations.isEmpty ? nil : locations.joined(separator: ",")
    }
    
    // 设置自定义药物
    func setCustomMedicines(_ medicines: [String]) {
        customMedicines = medicines.isEmpty ? nil : medicines.joined(separator: ",")
    }
    
    // 设置自定义触发因素
    func setCustomTriggers(_ triggers: [String]) {
        customTriggers = triggers.isEmpty ? nil : triggers.joined(separator: ",")
    }
    
    // 设置自定义症状
    func setCustomSymptoms(_ symptoms: [String]) {
        customSymptoms = symptoms.isEmpty ? nil : symptoms.joined(separator: ",")
    }
    
    // 获取完整的描述信息（包含所有备注）
    var fullDescription: String {
        var description = "头痛强度: \(intensity)"
        
        if !allLocationNames.isEmpty {
            description += "\n位置: \(allLocationNames.joined(separator: ", "))"
        }
        
        if !allTriggerNames.isEmpty {
            description += "\n触发因素: \(allTriggerNames.joined(separator: ", "))"
        }
        
        
        if let note = triggerNote, !note.isEmpty {
            description += "\n触发因素备注: \(note)"
        }
        
        if !allSymptomTags.isEmpty {
            description += "\n症状: \(allSymptomTags.joined(separator: ", "))"
        }
        
        if let note = symptomNote, !note.isEmpty {
            description += "\n症状备注: \(note)"
        }
        
        if tookMedicine {
            let medicineInfo = allMedicineNames.isEmpty ? "已用药" : allMedicineNames.joined(separator: ", ")
            description += "\n用药: \(medicineInfo)\(medicineRelief ? " (有缓解)" : " (无缓解)")"
            
            if let note = medicineNote, !note.isEmpty {
                description += "\n用药备注: \(note)"
            }
        }
        
        if let durationText = durationText {
            description += "\n持续时间: \(durationText)"
        }
        
        if let note = timeNote, !note.isEmpty {
            description += "\n时间备注: \(note)"
        }
        
        if let note = note, !note.isEmpty {
            description += "\n备注: \(note)"
        }
        
        return description
    }
    
    var isMildHeadache: Bool {
        return intensity <= 3 || (note?.contains("快速记录") == true)
    }
    
    // 新增：检查是否为快速记录
    var isQuickRecord: Bool {
        return note?.contains("快速记录") == true
    }
}
