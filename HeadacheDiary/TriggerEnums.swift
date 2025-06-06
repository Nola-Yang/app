//
//  TriggerEnums.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import Foundation

enum HeadacheTrigger: String, CaseIterable {
    case coldWind = "coldWind"
    case sleepDeprivation = "sleepDeprivation"
    case socialInteraction = "socialInteraction"
    case stress = "stress"
    case weather = "weather"
    case diet = "diet"
    case menstruation = "menstruation"  // 更新：荷尔蒙改为月经期
    case supplementMissed = "supplementMissed"  // 新增：补剂漏服
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
            return "月经期"  // 更新
        case .supplementMissed:
            return "补剂漏服(CoQ10等)"  // 新增
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
            return "calendar.badge.clock"  // 更新图标
        case .supplementMissed:
            return "pills.circle"  // 新增图标
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
            return "pink"  // 保持粉色
        case .supplementMissed:
            return "teal"  // 新增颜色
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

// 自定义选项的数据模型
struct CustomOption: Codable, Identifiable, Hashable {
    let id = UUID()
    let text: String
    let category: CustomOptionCategory
    let createdAt: Date
    
    init(text: String, category: CustomOptionCategory) {
        self.text = text
        self.category = category
        self.createdAt = Date()
    }
}

// 自定义选项分类
enum CustomOptionCategory: String, CaseIterable, Codable {
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

// 自定义选项管理器
class CustomOptionsManager: ObservableObject {
    static let shared = CustomOptionsManager()
    
    @Published var customOptions: [CustomOption] = []
    
    private let userDefaults = UserDefaults.standard
    private let customOptionsKey = "CustomOptions"
    
    private init() {
        loadCustomOptions()
    }
    
    // 添加自定义选项
    func addCustomOption(text: String, category: CustomOptionCategory) {
        let newOption = CustomOption(text: text, category: category)
        customOptions.append(newOption)
        saveCustomOptions()
    }
    
    // 获取指定分类的自定义选项
    func getCustomOptions(for category: CustomOptionCategory) -> [CustomOption] {
        return customOptions.filter { $0.category == category }
    }
    
    // 删除自定义选项
    func removeCustomOption(_ option: CustomOption) {
        customOptions.removeAll { $0.id == option.id }
        saveCustomOptions()
    }
    
    // 保存到UserDefaults
    private func saveCustomOptions() {
        if let encoded = try? JSONEncoder().encode(customOptions) {
            userDefaults.set(encoded, forKey: customOptionsKey)
        }
    }
    
    // 从UserDefaults加载
    private func loadCustomOptions() {
        if let data = userDefaults.data(forKey: customOptionsKey),
           let decoded = try? JSONDecoder().decode([CustomOption].self, from: data) {
            customOptions = decoded
        }
    }
}
