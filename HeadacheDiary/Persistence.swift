//
//  Persistence.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import CoreData
import Foundation

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
            
            // 随机设置触发因素（替代isVascular）
            var sampleTriggers: [HeadacheTrigger] = []
            if i % 2 == 0 { sampleTriggers.append(.sleepDeprivation) }
            if i % 3 == 0 { sampleTriggers.append(.stress) }
            if i % 4 == 0 { sampleTriggers.append(.coldWind) }
            if i % 5 == 0 { sampleTriggers.append(.screenTime) }
            if i % 6 == 0 { sampleTriggers.append(.socialInteraction) }
            if i % 7 == 0 { sampleTriggers.append(.weather) }
            
            if !sampleTriggers.isEmpty {
                record.triggers = sampleTriggers.map { $0.rawValue }.joined(separator: ",")
            }
            
            // 随机设置症状（移除isVascular）
            record.hasTinnitus = i % 7 == 0
            record.hasThrobbing = i % 4 == 0
            
            // 设置时间范围
            record.startTime = record.timestamp?.addingTimeInterval(-Double(i % 4 + 1) * 3600) // 开始时间在记录时间前几小时
            record.endTime = record.timestamp?.addingTimeInterval(Double(i % 3 + 1) * 3600) // 结束时间在记录时间后几小时
        }
        
        do {
            try viewContext.save()
            print("预览数据创建成功")
        } catch {
            let nsError = error as NSError
            print("预览数据创建失败: \(nsError), \(nsError.userInfo)")
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
            // 启用持久化历史跟踪
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            // 启用远程更改通知
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 调试信息
            print("配置存储描述: \(storeDescription)")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data 加载失败: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("Core Data 加载成功: \(storeDescription)")
            }
        })
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // 设置合并策略 - 这很重要！
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 启用调试
        container.viewContext.name = "MainContext"
        
        // 添加保存通知监听
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: container.viewContext,
            queue: .main
        ) { notification in
            print("Core Data 保存通知: \(notification)")
        }
    }
    
    // 手动保存方法，用于调试
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else {
            print("没有变化需要保存")
            return
        }
        
        do {
            try context.save()
            print("手动保存成功")
        } catch {
            print("手动保存失败: \(error)")
        }
    }
}
