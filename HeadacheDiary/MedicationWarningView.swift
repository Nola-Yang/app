//
//  MedicationWarningView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI
import CoreData

struct MedicationWarningView: View {
    let records: [HeadacheRecord]
    
    // 计算最近一周的用药次数
    private var weeklyMedicationCount: Int {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let recentRecords = records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return timestamp >= oneWeekAgo
        }
        
        var totalCount = 0
        for record in recentRecords {
            // 优先使用新的medicationEntries
            if !record.medicationEntries.isEmpty {
                totalCount += record.medicationEntries.count
            } else if record.tookMedicine {
                // 兼容旧数据格式
                totalCount += 1
            }
        }
        
        return totalCount
    }
    
    // 计算最近一个月的用药次数
    private var monthlyMedicationCount: Int {
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentRecords = records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return timestamp >= oneMonthAgo
        }
        
        var totalCount = 0
        for record in recentRecords {
            // 优先使用新的medicationEntries
            if !record.medicationEntries.isEmpty {
                totalCount += record.medicationEntries.count
            } else if record.tookMedicine {
                // 兼容旧数据格式
                totalCount += 1
            }
        }
        
        return totalCount
    }
    
    // 计算最近一个月的总剂量
    private var monthlyTotalDosage: Double {
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentRecords = records.filter { record in
            guard let timestamp = record.timestamp else { return false }
            return timestamp >= oneMonthAgo
        }
        
        var totalDosage: Double = 0
        for record in recentRecords {
            if !record.medicationEntries.isEmpty {
                totalDosage += record.medicationEntries.reduce(0) { $0 + $1.dosage }
            } else if record.tookMedicine {
                // 对于旧数据，使用默认剂量估算
                totalDosage += 500 // 默认500mg
            }
        }
        
        return totalDosage
    }
    
    // 判断警告级别
    private var warningLevel: MedicationWarningLevel {
        if monthlyMedicationCount > 10 {
            return .severe
        } else if weeklyMedicationCount > 3 {
            return .moderate
        } else if monthlyMedicationCount > 6 {
            return .mild
        } else {
            return .none
        }
    }
    
    var body: some View {
        Group {
            if warningLevel != .none {
                medicationWarningCard
            }
        }
    }
    
    @ViewBuilder
    private var medicationWarningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 警告标题
            HStack {
                Image(systemName: warningLevel.icon)
                    .foregroundColor(warningLevel.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(warningLevel.title)
                        .font(.headline.bold())
                        .foregroundColor(warningLevel.color)
                    
                    Text(warningLevel.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 数据摘要
                VStack(alignment: .trailing, spacing: 2) {
                    Text("本周 \(weeklyMedicationCount) 次")
                        .font(.caption.bold())
                        .foregroundColor(weeklyMedicationCount > 3 ? .red : .orange)
                    
                    Text("本月 \(monthlyMedicationCount) 次")
                        .font(.caption.bold())
                        .foregroundColor(monthlyMedicationCount > 10 ? .red : .secondary)
                }
            }
            
            // 详细信息和建议
            VStack(alignment: .leading, spacing: 8) {
                Text(warningLevel.message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 数据详情
                if monthlyTotalDosage > 0 {
                    HStack {
                        Text("本月总剂量:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(monthlyTotalDosage))mg")
                            .font(.caption.bold())
                            .foregroundColor(monthlyTotalDosage > 15000 ? .red : .orange)
                        
                        Spacer()
                        
                        if monthlyTotalDosage > 15000 {
                            Text("剂量过高")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // 行动建议
                if warningLevel != .none {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(warningLevel.actionItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(warningLevel.color)
                                    .font(.caption.bold())
                                Text(item)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // 操作按钮
            HStack {
                Spacer()
                
                Button("查看用药统计") {
                    // 这里可以导航到统计页面或显示详细的用药分析
                }
                .font(.caption.bold())
                .foregroundColor(warningLevel.color)
                
                Button("了解安全用药") {
                    // 这里可以显示用药安全指南
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(warningLevel.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(warningLevel.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// 用药警告级别枚举
enum MedicationWarningLevel {
    case none
    case mild
    case moderate
    case severe
    
    var title: String {
        switch self {
        case .none:
            return ""
        case .mild:
            return "用药提醒"
        case .moderate:
            return "用药频率偏高"
        case .severe:
            return "用药过量警告"
        }
    }
    
    var subtitle: String {
        switch self {
        case .none:
            return ""
        case .mild:
            return "请注意用药频率"
        case .moderate:
            return "建议谨慎用药"
        case .severe:
            return "强烈建议就医咨询"
        }
    }
    
    var message: String {
        switch self {
        case .none:
            return ""
        case .mild:
            return "您本月的用药次数有所增加。适当的用药可以缓解头痛，但过度依赖药物可能导致药物过量性头痛。"
        case .moderate:
            return "您最近一周的用药次数超过了建议频率。频繁用药可能会导致反弹性头痛，建议寻找其他缓解方法。"
        case .severe:
            return "您的用药频率已超过安全范围，可能存在药物过量性头痛的风险。强烈建议尽快咨询医生，制定更安全的头痛管理方案。"
        }
    }
    
    var actionItems: [String] {
        switch self {
        case .none:
            return []
        case .mild:
            return [
                "尝试非药物缓解方法，如休息、冷敷、按摩",
                "记录触发因素，预防头痛发生",
                "保持规律的作息和饮食"
            ]
        case .moderate:
            return [
                "减少药物使用频率，寻找替代方法",
                "考虑预防性治疗方案",
                "咨询医生或药师关于安全用药",
                "关注头痛模式变化"
            ]
        case .severe:
            return [
                "立即停止或减少药物使用",
                "尽快预约医生进行专业评估",
                "考虑住院或专科治疗",
                "建立药物使用记录给医生参考"
            ]
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return ""
        case .mild:
            return "info.circle.fill"
        case .moderate:
            return "exclamationmark.triangle.fill"
        case .severe:
            return "exclamationmark.octagon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none:
            return .clear
        case .mild:
            return .blue
        case .moderate:
            return .orange
        case .severe:
            return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .none:
            return .clear
        case .mild:
            return Color.blue.opacity(0.05)
        case .moderate:
            return Color.orange.opacity(0.05)
        case .severe:
            return Color.red.opacity(0.05)
        }
    }
}

// 用药安全指南视图
struct MedicationSafetyGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("头痛药物安全使用指南")
                            .font(.title2.bold())
                        Text("了解安全用药，预防药物过量性头痛")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 安全用药频率
                    SafetySection(
                        title: "推荐用药频率",
                        icon: "calendar.badge.clock",
                        color: .blue,
                        content: [
                            "每周不超过3次用药",
                            "每月不超过10次用药",
                            "连续用药不超过3天",
                            "两次用药间隔至少4-6小时"
                        ]
                    )
                    
                    // 药物过量性头痛警告
                    SafetySection(
                        title: "药物过量性头痛",
                        icon: "exclamationmark.triangle",
                        color: .orange,
                        content: [
                            "频繁用药可能导致反弹性头痛",
                            "症状：头痛频率增加，药效减弱",
                            "治疗：逐渐减少药物使用",
                            "预防：控制用药频率，寻找替代方法"
                        ]
                    )
                    
                    // 非药物缓解方法
                    SafetySection(
                        title: "非药物缓解方法",
                        icon: "leaf",
                        color: .green,
                        content: [
                            "充足睡眠和规律作息",
                            "冷敷或热敷头部",
                            "轻柔的颈部和肩部按摩",
                            "放松训练和深呼吸",
                            "避免已知的触发因素",
                            "保持适当的水分摄入"
                        ]
                    )
                    
                    // 何时就医
                    SafetySection(
                        title: "何时需要就医",
                        icon: "stethoscope",
                        color: .red,
                        content: [
                            "头痛模式突然改变",
                            "药物效果明显减弱",
                            "用药频率持续增加",
                            "出现新的症状",
                            "影响正常生活和工作",
                            "担心药物依赖问题"
                        ]
                    )
                    
                    // 建议
                    VStack(alignment: .leading, spacing: 12) {
                        Text("💡 专业建议")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("如果您发现需要频繁使用止痛药，建议咨询医生制定个性化的头痛管理方案。预防性治疗、生活方式调整和非药物疗法可能是更好的长期解决方案。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("用药安全指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// 安全指南章节组件
struct SafetySection: View {
    let title: String
    let icon: String
    let color: Color
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(content, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(color)
                            .font(.subheadline.bold())
                        Text(item)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    struct MedicationWarningPreview: View {
        let sampleRecords: [HeadacheRecord] = {
            let context = PersistenceController.preview.container.viewContext
            
            // 创建一些测试记录
            var records: [HeadacheRecord] = []
            
            // 创建最近一周有多次用药的记录
            for i in 0..<5 {
                let record = HeadacheRecord(context: context)
                record.timestamp = Calendar.current.date(byAdding: .day, value: -i, to: Date())
                record.tookMedicine = true
                record.medicineType = "tylenol"
                record.intensity = Int16(i + 5)
                
                // 添加一些用药记录
                let entries = [
                    MedicationEntry(
                        time: record.timestamp!,
                        medicineType: "tylenol",
                        dosage: 500,
                        relief: i % 2 == 0
                    )
                ]
                record.medicationEntries = entries
                
                records.append(record)
            }
            
            return records
        }()
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    MedicationWarningView(records: sampleRecords)
                    
                    // 显示不同级别的警告
                    Text("测试不同警告级别:")
                        .font(.headline)
                        .padding(.top)
                    
                    // 这里可以添加更多测试数据来展示不同级别的警告
                }
                .padding()
            }
        }
    }
    
    return MedicationWarningPreview()
}
