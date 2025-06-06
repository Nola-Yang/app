//
//  TriggerEnums.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import Foundation
import SwiftUI

enum HeadacheTrigger: String, CaseIterable {
    case coldWind = "coldWind"
    case sleepDeprivation = "sleepDeprivation"
    case socialInteraction = "socialInteraction"
    case stress = "stress"
    case weather = "weather"
    case diet = "diet"
    case menstruation = "menstruation"
    case supplementMissed = "supplementMissed"
    case brightLight = "brightLight"
    case noise = "noise"
    case smell = "smell"
    case exercise = "exercise"
    case dehydration = "dehydration"
    case hunger = "hunger"
    case screenTime = "screenTime"
    case alcohol = "alcohol"
    case caffeine = "caffeine"
    
    var displayName: String {
        switch self {
        case .coldWind:
            return "吹冷风"
        case .sleepDeprivation:
            return "睡眠不足"
        case .socialInteraction:
            return "社交活动"
        case .stress:
            return "压力/焦虑"
        case .weather:
            return "天气变化"
        case .diet:
            return "饮食因素"
        case .menstruation:
            return "月经期"
        case .supplementMissed:
            return "补剂漏服(CoQ10等)"
        case .brightLight:
            return "强光刺激"
        case .noise:
            return "噪音环境"
        case .smell:
            return "气味刺激"
        case .exercise:
            return "运动过度"
        case .dehydration:
            return "脱水"
        case .hunger:
            return "饥饿"
        case .screenTime:
            return "长时间看屏幕"
        case .alcohol:
            return "饮酒"
        case .caffeine:
            return "咖啡因"
        }
    }
    
    var icon: String {
        switch self {
        case .coldWind:
            return "wind"
        case .sleepDeprivation:
            return "bed.double"
        case .socialInteraction:
            return "person.2"
        case .stress:
            return "brain.head.profile"
        case .weather:
            return "cloud.rain"
        case .diet:
            return "fork.knife"
        case .menstruation:
            return "calendar.badge.clock"
        case .supplementMissed:
            return "pills.circle"
        case .brightLight:
            return "sun.max"
        case .noise:
            return "speaker.wave.3"
        case .smell:
            return "nose"
        case .exercise:
            return "figure.run"
        case .dehydration:
            return "drop"
        case .hunger:
            return "stomach"
        case .screenTime:
            return "display"
        case .alcohol:
            return "wineglass"
        case .caffeine:
            return "cup.and.saucer"
        }
    }
    
    var color: String {
        switch self {
        case .coldWind, .weather:
            return "blue"
        case .sleepDeprivation:
            return "purple"
        case .socialInteraction:
            return "green"
        case .stress:
            return "red"
        case .diet, .hunger:
            return "orange"
        case .menstruation:
            return "pink"
        case .supplementMissed:
            return "teal"
        case .brightLight:
            return "yellow"
        case .noise:
            return "gray"
        case .smell:
            return "brown"
        case .exercise:
            return "mint"
        case .dehydration:
            return "cyan"
        case .screenTime:
            return "indigo"
        case .alcohol:
            return "red"
        case .caffeine:
            return "brown"
        }
    }
}

// 自定义选项分类
enum HeadacheCustomOptionCategory: String, CaseIterable, Codable {
    case location = "location"
    case medicine = "medicine"
    case trigger = "trigger"
    case symptom = "symptom"
    
    var displayName: String {
        switch self {
        case .location:
            return "疼痛位置"
        case .medicine:
            return "药物"
        case .trigger:
            return "触发因素"
        case .symptom:
            return "症状"
        }
    }
    
    var icon: String {
        switch self {
        case .location:
            return "location"
        case .medicine:
            return "pills"
        case .trigger:
            return "exclamationmark.triangle"
        case .symptom:
            return "stethoscope"
        }
    }
}

// 自定义选项的数据模型
struct HeadacheCustomOption: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let category: HeadacheCustomOptionCategory
    let createdAt: Date
    
    init(text: String, category: HeadacheCustomOptionCategory) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.createdAt = Date()
    }
    
    // 为了支持 Codable
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case category
        case createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        category = try container.decode(HeadacheCustomOptionCategory.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// 自定义选项管理器
class HeadacheCustomOptionsManager: ObservableObject {
    static let shared = HeadacheCustomOptionsManager()
    
    @Published var customOptions: [HeadacheCustomOption] = []
    
    private let userDefaults = UserDefaults.standard
    private let customOptionsKey = "HeadacheCustomOptions"
    
    private init() {
        loadCustomOptions()
        print("✅ HeadacheCustomOptionsManager 初始化完成，当前选项数量: \(customOptions.count)")
    }
    
    // 添加自定义选项
    func addCustomOption(text: String, category: HeadacheCustomOptionCategory) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            print("❌ 添加失败：文本为空")
            return
        }
        
        let exists = customOptions.contains { option in
            option.category == category && option.text.lowercased() == trimmedText.lowercased()
        }
        
        guard !exists else {
            print("❌ 添加失败：选项已存在")
            return
        }
        
        let newOption = HeadacheCustomOption(text: trimmedText, category: category)
        customOptions.append(newOption)
        saveCustomOptions()
        print("✅ 成功添加自定义选项: \(trimmedText) -> \(category.displayName)")
    }
    
    // 获取指定分类的自定义选项
    func getCustomOptions(for category: HeadacheCustomOptionCategory) -> [HeadacheCustomOption] {
        return customOptions.filter { $0.category == category }.sorted { $0.createdAt < $1.createdAt }
    }
    
    // 删除自定义选项
    func removeCustomOption(_ option: HeadacheCustomOption) {
        customOptions.removeAll { $0.id == option.id }
        saveCustomOptions()
        print("✅ 删除自定义选项: \(option.text)")
    }
    
    // 批量删除指定分类的选项
    func removeCustomOptions(for category: HeadacheCustomOptionCategory) {
        customOptions.removeAll { $0.category == category }
        saveCustomOptions()
        print("✅ 清空分类: \(category.displayName)")
    }
    
    // 检查选项是否存在
    func optionExists(text: String, category: HeadacheCustomOptionCategory) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return customOptions.contains { option in
            option.category == category && option.text.lowercased() == trimmedText.lowercased()
        }
    }
    
    // 保存到UserDefaults
    private func saveCustomOptions() {
        do {
            let encoded = try JSONEncoder().encode(customOptions)
            userDefaults.set(encoded, forKey: customOptionsKey)
            print("✅ 自定义选项已保存到 UserDefaults")
        } catch {
            print("❌ 保存自定义选项失败: \(error)")
        }
    }
    
    // 从UserDefaults加载
    private func loadCustomOptions() {
        guard let data = userDefaults.data(forKey: customOptionsKey) else {
            print("⚠️ 没有找到保存的自定义选项数据")
            return
        }
        
        do {
            customOptions = try JSONDecoder().decode([HeadacheCustomOption].self, from: data)
            print("✅ 从 UserDefaults 加载了 \(customOptions.count) 个自定义选项")
        } catch {
            print("❌ 加载自定义选项失败: \(error)")
            customOptions = []
        }
    }
    
    // 调试方法
    func debugPrintAllOptions() {
        print("=== 所有自定义选项 ===")
        for category in HeadacheCustomOptionCategory.allCases {
            let options = getCustomOptions(for: category)
            print("\(category.displayName): \(options.map { $0.text })")
        }
        print("=====================")
    }
}
