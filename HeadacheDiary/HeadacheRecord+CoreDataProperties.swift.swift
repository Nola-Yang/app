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
