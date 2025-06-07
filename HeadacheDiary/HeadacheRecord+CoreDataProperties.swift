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
    @NSManaged public var customLocations: String?
    
    // 传统用药信息（保持向后兼容）
    @NSManaged public var tookMedicine: Bool
    @NSManaged public var medicineTime: Date?
    @NSManaged public var medicineType: String?
    @NSManaged public var medicineRelief: Bool
    @NSManaged public var customMedicines: String?
    @NSManaged public var medicineNote: String?
    
    // 新增：增强的用药记录
    @NSManaged public var medicationEntriesData: Data?  // 存储MedicationEntry数组的JSON数据
    @NSManaged public var totalDosageValue: Double      // 总剂量缓存
    @NSManaged public var hasMedicationTimeline: Bool   // 是否有多次用药时间线
    
    // 触发因素
    @NSManaged public var triggers: String?
    @NSManaged public var customTriggers: String?
    @NSManaged public var triggerNote: String?
    
    // 疼痛特征
    @NSManaged public var hasTinnitus: Bool
    @NSManaged public var hasThrobbing: Bool
    @NSManaged public var customSymptoms: String?
    @NSManaged public var symptomNote: String?
    
    // 时间范围
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var timeNote: String?
}


