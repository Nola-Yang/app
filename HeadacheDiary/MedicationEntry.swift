//
//  MedicationEntry.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import Foundation
import CoreData

// 单次用药记录的结构
struct MedicationEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let time: Date
    let medicineType: String // 预定义药物类型或自定义药物名称
    let dosage: Double // 剂量，单位mg
    let isCustomMedicine: Bool // 是否为自定义药物
    let relief: Bool // 是否缓解
    let reliefTime: Date? // 缓解时间（如果有的话）
    let note: String? // 单次用药备注
    
    init(id: UUID = UUID(), time: Date, medicineType: String, dosage: Double, isCustomMedicine: Bool = false, relief: Bool = false, reliefTime: Date? = nil, note: String? = nil) {
        self.id = id
        self.time = time
        self.medicineType = medicineType
        self.dosage = dosage
        self.isCustomMedicine = isCustomMedicine
        self.relief = relief
        self.reliefTime = reliefTime
        self.note = note
    }
    
    // 创建更新版本的便利方法
    func updated(time: Date? = nil, medicineType: String? = nil, dosage: Double? = nil, isCustomMedicine: Bool? = nil, relief: Bool? = nil, reliefTime: Date? = nil, note: String? = nil) -> MedicationEntry {
        return MedicationEntry(
            id: self.id,
            time: time ?? self.time,
            medicineType: medicineType ?? self.medicineType,
            dosage: dosage ?? self.dosage,
            isCustomMedicine: isCustomMedicine ?? self.isCustomMedicine,
            relief: relief ?? self.relief,
            reliefTime: reliefTime ?? self.reliefTime,
            note: note ?? self.note
        )
    }
    
    // 显示名称
    var displayName: String {
        if isCustomMedicine {
            return medicineType
        } else {
            return MedicineType(rawValue: medicineType)?.displayName ?? medicineType
        }
    }
    
    // 剂量显示文本
    var dosageText: String {
        if dosage == floor(dosage) {
            return "\(Int(dosage))mg"
        } else {
            return "\(dosage)mg"
        }
    }
    
    // 完整描述
    var fullDescription: String {
        var description = "\(displayName) \(dosageText)"
        if relief {
            description += " (有效"
            if let reliefTime = reliefTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                description += "，\(formatter.string(from: reliefTime))缓解"
            }
            description += ")"
        } else {
            description += " (无效)"
        }
        return description
    }
}

// HeadacheRecord的扩展，增加用药记录管理
extension HeadacheRecord {
    
    // 获取所有用药记录
    var medicationEntries: [MedicationEntry] {
        get {
            guard let medicationEntriesData = medicationEntriesData else { return [] }
            do {
                return try JSONDecoder().decode([MedicationEntry].self, from: medicationEntriesData)
            } catch {
                print("❌ 解析用药记录失败: \(error)")
                return []
            }
        }
        set {
            do {
                medicationEntriesData = try JSONEncoder().encode(newValue)
            } catch {
                print("❌ 编码用药记录失败: \(error)")
                medicationEntriesData = nil
            }
        }
    }
    
    // 添加用药记录
    func addMedicationEntry(_ entry: MedicationEntry) {
        var entries = medicationEntries
        entries.append(entry)
        medicationEntries = entries.sorted { $0.time < $1.time }
        
        // 更新兼容字段
        updateCompatibilityFields()
    }
    
    // 删除用药记录
    func removeMedicationEntry(with id: UUID) {
        var entries = medicationEntries
        entries.removeAll { $0.id == id }
        medicationEntries = entries
        
        // 更新兼容字段
        updateCompatibilityFields()
    }
    
    // 更新用药记录
    func updateMedicationEntry(_ updatedEntry: MedicationEntry) {
        var entries = medicationEntries
        if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
            entries[index] = updatedEntry
            medicationEntries = entries.sorted { $0.time < $1.time }
            
            // 更新兼容字段
            updateCompatibilityFields()
        }
    }
    
    // 获取有效用药记录
    var effectiveMedicationEntries: [MedicationEntry] {
        return medicationEntries.filter { $0.relief }
    }
    
    // 获取最后一次有效用药
    var lastEffectiveMedication: MedicationEntry? {
        return effectiveMedicationEntries.last
    }
    
    // 获取总剂量
    var totalDosage: Double {
        return medicationEntries.reduce(0) { $0 + $1.dosage }
    }
    
    // 获取每种药物的总剂量
    var dosageByMedicine: [String: Double] {
        var dosages: [String: Double] = [:]
        for entry in medicationEntries {
            dosages[entry.displayName, default: 0] += entry.dosage
        }
        return dosages
    }
    
    // 是否有多次用药
    var hasMultipleMedications: Bool {
        return medicationEntries.count > 1
    }
    
    // 用药时间线描述
    var medicationTimeline: String {
        let sortedEntries = medicationEntries.sorted { $0.time < $1.time }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return sortedEntries.enumerated().map { index, entry in
            let timeStr = formatter.string(from: entry.time)
            let effectStr = entry.relief ? "✓" : "✗"
            return "\(index + 1). \(timeStr) \(entry.displayName) \(entry.dosageText) \(effectStr)"
        }.joined(separator: "\n")
    }
    
    // 更新兼容字段（保持与旧版本的兼容性）
    private func updateCompatibilityFields() {
        let entries = medicationEntries
        
        // 更新基本用药状态
        tookMedicine = !entries.isEmpty
        
        if let firstEntry = entries.first {
            // 使用第一次用药的时间和类型
            medicineTime = firstEntry.time
            if !firstEntry.isCustomMedicine {
                medicineType = firstEntry.medicineType
            }
        }
        
        // 判断是否有任何用药缓解
        medicineRelief = entries.contains { $0.relief }
        
        // 更新自定义药物列表
        let customMedicines = entries.filter { $0.isCustomMedicine }.map { $0.medicineType }
        setCustomMedicines(Array(Set(customMedicines)))
    }
    
    // 从旧数据迁移（兼容性方法）
    func migrateLegacyMedicationData() {
        // 如果已经有新格式的数据，不需要迁移
        if !medicationEntries.isEmpty { return }
        
        // 如果有旧格式的用药数据，转换为新格式
        if tookMedicine, let medicineTime = medicineTime {
            var entries: [MedicationEntry] = []
            
            // 预定义药物
            if let medicineType = medicineType {
                let entry = MedicationEntry(
                    time: medicineTime,
                    medicineType: medicineType,
                    dosage: getDefaultDosageForMedicine(medicineType),
                    isCustomMedicine: false,
                    relief: medicineRelief,
                    note: medicineNote
                )
                entries.append(entry)
            }
            
            // 自定义药物
            for customMedicine in customMedicineNames {
                let entry = MedicationEntry(
                    time: medicineTime,
                    medicineType: customMedicine,
                    dosage: 500, // 默认剂量
                    isCustomMedicine: true,
                    relief: medicineRelief,
                    note: medicineNote
                )
                entries.append(entry)
            }
            
            medicationEntries = entries
        }
    }
    
    // 获取药物的默认剂量
    private func getDefaultDosageForMedicine(_ medicineType: String) -> Double {
        switch medicineType {
        case MedicineType.tylenol.rawValue:
            return 500
        case MedicineType.ibuprofen.rawValue:
            return 400
        default:
            return 500
        }
    }
}
