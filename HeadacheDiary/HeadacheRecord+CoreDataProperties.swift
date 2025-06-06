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
    @NSManaged public var customLocations: String?  // 新增
    
    // 用药信息
    @NSManaged public var tookMedicine: Bool
    @NSManaged public var medicineTime: Date?
    @NSManaged public var medicineType: String?
    @NSManaged public var medicineRelief: Bool
    @NSManaged public var customMedicines: String?  // 新增
    @NSManaged public var medicineNote: String?     // 新增
    
    // 触发因素
    @NSManaged public var triggers: String?
    @NSManaged public var customTriggers: String?   // 新增
    @NSManaged public var triggerNote: String?      // 新增
    
    // 疼痛特征 (已移除 isVascular)
    @NSManaged public var hasTinnitus: Bool
    @NSManaged public var hasThrobbing: Bool
    @NSManaged public var customSymptoms: String?   // 新增
    @NSManaged public var symptomNote: String?      // 新增
    
    // 时间范围
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var timeNote: String?         // 新增
}

