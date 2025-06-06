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
        
        // 创建丰富的示例数据，包含新功能
        for i in 0..<15 {
            let record = HeadacheRecord(context: viewContext)
            record.timestamp = Date().addingTimeInterval(Double(-i) * 3600 * 24) // 每天一个记录
            record.intensity = Int16((i % 10) + 1)
            
            // 基本备注
            switch i % 4 {
            case 0:
                record.note = "工作压力很大，连续加班"
            case 1:
                record.note = "睡眠质量不好，半夜醒来好几次"
            case 2:
                record.note = "天气突然降温，可能受凉了"
            default:
                record.note = nil
            }
            
            // 随机设置疼痛位置
            record.locationForehead = i % 4 == 0
            record.locationLeftSide = i % 3 == 0
            record.locationRightSide = i % 5 == 0
            record.locationTemple = i % 2 == 0
            record.locationFace = i % 6 == 0
            
            // 添加自定义位置
            if i % 7 == 0 {
                record.customLocations = "后脑勺,颈部"
            } else if i % 8 == 0 {
                record.customLocations = "下巴,眼眶周围"
            }
            
            // 随机设置用药信息
            record.tookMedicine = i % 3 == 0
            if record.tookMedicine {
                record.medicineTime = record.timestamp?.addingTimeInterval(3600) // 1小时后服药
                record.medicineType = i % 2 == 0 ? MedicineType.tylenol.rawValue : MedicineType.ibuprofen.rawValue
                record.medicineRelief = i % 4 != 0 // 大部分时候有缓解
                
                // 添加自定义药物
                if i % 9 == 0 {
                    record.customMedicines = "阿司匹林"
                } else if i % 10 == 0 {
                    record.customMedicines = "头痛粉,散列通"
                }
                
                // 用药备注
                switch i % 5 {
                case 0:
                    record.medicineNote = "饭后服用，30分钟后开始缓解"
                case 1:
                    record.medicineNote = "空腹服用，有轻微胃部不适"
                case 2:
                    record.medicineNote = "效果不明显，2小时后又加服了一粒"
                default:
                    record.medicineNote = nil
                }
            }
            
            // 设置触发因素（包括新的月经期和补剂漏服）
            var sampleTriggers: [HeadacheTrigger] = []
            if i % 2 == 0 { sampleTriggers.append(.sleepDeprivation) }
            if i % 3 == 0 { sampleTriggers.append(.stress) }
            if i % 4 == 0 { sampleTriggers.append(.coldWind) }
            if i % 5 == 0 { sampleTriggers.append(.screenTime) }
            if i % 6 == 0 { sampleTriggers.append(.socialInteraction) }
            if i % 7 == 0 { sampleTriggers.append(.weather) }
            if i % 8 == 0 { sampleTriggers.append(.menstruation) } // 新增：月经期
            if i % 9 == 0 { sampleTriggers.append(.supplementMissed) } // 新增：补剂漏服
            if i % 10 == 0 { sampleTriggers.append(.caffeine) }
            
            if !sampleTriggers.isEmpty {
                record.triggers = sampleTriggers.map { $0.rawValue }.joined(separator: ",")
            }
            
            // 添加自定义触发因素
            if i % 11 == 0 {
                record.customTriggers = "空调直吹,办公室噪音"
            } else if i % 12 == 0 {
                record.customTriggers = "熬夜工作,吃了巧克力"
            } else if i % 13 == 0 {
                record.customTriggers = "长时间开车"
            }
            
            // 触发因素备注
            switch i % 6 {
            case 0:
                record.triggerNote = "昨晚只睡了4小时，今天一直很疲惫"
            case 1:
                record.triggerNote = "会议室空调太冷，坐了3小时"
            case 2:
                record.triggerNote = "连续看屏幕8小时，眼睛很干涩"
            case 3:
                record.triggerNote = "忘记吃CoQ10已经3天了"
            default:
                record.triggerNote = nil
            }
            
            // 设置症状（移除血管性选项）
            record.hasTinnitus = i % 7 == 0
            record.hasThrobbing = i % 4 == 0
            
            // 添加自定义症状
            if i % 8 == 0 {
                record.customSymptoms = "恶心想吐"
            } else if i % 9 == 0 {
                record.customSymptoms = "眼睛疼,畏光"
            } else if i % 10 == 0 {
                record.customSymptoms = "脖子僵硬,肩膀酸痛"
            }
            
            // 症状备注
            switch i % 7 {
            case 0:
                record.symptomNote = "血管跳动非常明显，像有东西在敲打"
            case 1:
                record.symptomNote = "伴随轻微恶心，不想吃东西"
            case 2:
                record.symptomNote = "对光线特别敏感，需要戴墨镜"
            default:
                record.symptomNote = nil
            }
            
            // 设置时间范围
            record.startTime = record.timestamp?.addingTimeInterval(-Double(i % 4 + 1) * 3600) // 开始时间在记录时间前几小时
            
            // 有些记录设置结束时间，有些不设置（模拟进行中的头痛）
            if i % 5 != 0 {
                record.endTime = record.timestamp?.addingTimeInterval(Double(i % 3 + 1) * 3600) // 结束时间在记录时间后几小时
            }
            
            // 时间备注
            switch i % 8 {
            case 0:
                record.timeNote = "疼痛逐渐加重，从轻微到剧烈"
            case 1:
                record.timeNote = "突然发作，没有任何征兆"
            case 2:
                record.timeNote = "持续了整个上午，下午开始缓解"
            case 3:
                record.timeNote = "间歇性疼痛，每隔30分钟疼一次"
            default:
                record.timeNote = nil
            }
        }
        
        // 添加一些自定义选项到用户偏好中（模拟用户已经添加过的自定义选项）
        let customOptionsManager = CustomOptionsManager.shared
        
        // 自定义位置
        customOptionsManager.addCustomOption(text: "后脑勺", category: .location)
        customOptionsManager.addCustomOption(text: "颈部", category: .location)
        customOptionsManager.addCustomOption(text: "下巴", category: .location)
        customOptionsManager.addCustomOption(text: "眼眶周围", category: .location)
        
        // 自定义药物
        customOptionsManager.addCustomOption(text: "阿司匹林", category: .medicine)
        customOptionsManager.addCustomOption(text: "头痛粉", category: .medicine)
        customOptionsManager.addCustomOption(text: "散列通", category: .medicine)
        
        // 自定义触发因素
        customOptionsManager.addCustomOption(text: "空调直吹", category: .trigger)
        customOptionsManager.addCustomOption(text: "办公室噪音", category: .trigger)
        customOptionsManager.addCustomOption(text: "熬夜工作", category: .trigger)
        customOptionsManager.addCustomOption(text: "吃了巧克力", category: .trigger)
        customOptionsManager.addCustomOption(text: "长时间开车", category: .trigger)
        
        // 自定义症状
        customOptionsManager.addCustomOption(text: "恶心想吐", category: .symptom)
        customOptionsManager.addCustomOption(text: "眼睛疼", category: .symptom)
        customOptionsManager.addCustomOption(text: "畏光", category: .symptom)
        customOptionsManager.addCustomOption(text: "脖子僵硬", category: .symptom)
        customOptionsManager.addCustomOption(text: "肩膀酸痛", category: .symptom)
        
        do {
            try viewContext.save()
            print("预览数据创建成功，包含自定义选项和详细备注")
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
