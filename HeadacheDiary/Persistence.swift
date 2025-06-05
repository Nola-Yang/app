//
//  Persistence.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建示例数据
        for i in 0..<10 {
            let record = HeadacheRecord(context: viewContext)
            record.timestamp = Date().addingTimeInterval(Double(-i) * 3600 * 24) // 每天一个记录
            record.intensity = Int16((i % 10) + 1)
            record.note = i % 3 == 0 ? "工作压力大" : (i % 3 == 1 ? "睡眠不足" : nil)
            
            // 随机设置疼痛位置
            record.locationForehead = i % 4 == 0
            record.locationLeftSide = i % 3 == 0
            record.locationRightSide = i % 5 == 0
            record.locationTemple = i % 2 == 0
            record.locationFace = i % 6 == 0
            
            // 随机设置用药信息
            record.tookMedicine = i % 3 == 0
            if record.tookMedicine {
                record.medicineTime = record.timestamp?.addingTimeInterval(3600) // 1小时后服药
                record.medicineType = i % 2 == 0 ? MedicineType.tylenol.rawValue : MedicineType.ibuprofen.rawValue
                record.medicineRelief = i % 4 != 0 // 大部分时候有缓解
            }
            
            // 随机设置症状
            record.isVascular = i % 5 == 0
            record.hasTinnitus = i % 7 == 0
            record.hasThrobbing = i % 4 == 0
            
            // 设置时间范围
            record.startTime = record.timestamp?.addingTimeInterval(-Double(i % 4 + 1) * 3600) // 开始时间在记录时间前几小时
            record.endTime = record.timestamp?.addingTimeInterval(Double(i % 3 + 1) * 3600) // 结束时间在记录时间后几小时
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "HeadacheDiary")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // 配置CloudKit
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
