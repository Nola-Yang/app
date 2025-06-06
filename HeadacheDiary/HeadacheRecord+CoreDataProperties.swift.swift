//
//  HeadacheRecord+CoreDataProperties.swift.swift
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

    @NSManaged public var endTime: Date?
    @NSManaged public var hasThrobbing: Bool
    @NSManaged public var hasTinnitus: Bool
    @NSManaged public var intensity: Int16
    @NSManaged public var isVascular: Bool
    @NSManaged public var locationFace: Bool
    @NSManaged public var locationForehead: Bool
    @NSManaged public var locationLeftSide: Bool
    @NSManaged public var locationRightSide: Bool
    @NSManaged public var locationTemple: Bool
    @NSManaged public var medicineRelief: Bool
    @NSManaged public var medicineTime: Date?
    @NSManaged public var medicineType: String?
    @NSManaged public var note: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var timestamp: Date?
    @NSManaged public var tookMedicine: Bool
}

//extension HeadacheRecord {
//    
//    // 获取疼痛位置的便利属性
//    var locationNames: [String] {
//        var locations: [String] = []
//        if locationForehead { locations.append("额头") }
//        if locationLeftSide { locations.append("左侧") }
//        if locationRightSide { locations.append("右侧") }
//        if locationTemple { locations.append("太阳穴") }
//        if locationFace { locations.append("面部") }
//        return locations
//    }
//    
//    // 获取症状标签的便利属性
//    var symptomTags: [String] {
//        var symptoms: [String] = []
//        if isVascular { symptoms.append("血管性") }
//        if hasTinnitus { symptoms.append("耳鸣") }
//        if hasThrobbing { symptoms.append("跳动") }
//        return symptoms
//    }
//    
//    // 计算持续时间的便利方法
//    var durationText: String? {
//        guard let start = startTime, let end = endTime else { return nil }
//        
//        let duration = end.timeIntervalSince(start)
//        let hours = Int(duration) / 3600
//        let minutes = Int(duration) % 3600 / 60
//        
//        if hours > 0 {
//            return "\(hours)小时\(minutes)分钟"
//        } else {
//            return "\(minutes)分钟"
//        }
//    }
//    
//    // 获取药物名称
//    var medicineName: String? {
//        guard let typeString = medicineType,
//              let type = MedicineType(rawValue: typeString) else {
//            return nil
//        }
//        return type.displayName
//    }
//}
