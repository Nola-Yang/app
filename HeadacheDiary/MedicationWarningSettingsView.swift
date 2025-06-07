//
//  MedicationWarningSettingsView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI

struct MedicationWarningSettingsView: View {
    @AppStorage("medicationWarningEnabled") private var warningEnabled = true
    @AppStorage("weeklyMedicationLimit") private var weeklyLimit: Double = 3
    @AppStorage("monthlyMedicationLimit") private var monthlyLimit: Double = 10
    @AppStorage("dosageWarningEnabled") private var dosageWarningEnabled = true
    @AppStorage("monthlyDosageLimit") private var monthlyDosageLimit: Double = 15000
    
    @State private var showSafetyGuide = false
    
    var body: some View {
        Form {
            // 功能概述
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("用药安全监控")
                                .font(.headline.bold())
                            Text("智能监控用药频率，预防药物过量性头痛")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("查看用药安全指南") {
                        showSafetyGuide = true
                    }
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
            } header: {
                Text("功能说明")
            }
            
            // 警告设置
            Section {
                Toggle("启用用药警告", isOn: $warningEnabled)
                
                if warningEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每周用药次数警告阈值: \(Int(weeklyLimit))次")
                            .font(.subheadline)
                        Slider(value: $weeklyLimit, in: 1...7, step: 1)
                        Text("建议: 每周不超过3次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每月用药次数警告阈值: \(Int(monthlyLimit))次")
                            .font(.subheadline)
                        Slider(value: $monthlyLimit, in: 5...20, step: 1)
                        Text("建议: 每月不超过10次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("频率警告设置")
            } footer: {
                Text("当用药频率超过设定阈值时，在主页显示警告提醒")
            }
            
            // 剂量警告设置
            Section {
                Toggle("启用剂量警告", isOn: $dosageWarningEnabled)
                
                if dosageWarningEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每月总剂量警告阈值: \(Int(monthlyDosageLimit))mg")
                            .font(.subheadline)
                        Slider(value: $monthlyDosageLimit, in: 5000...30000, step: 1000)
                        Text("建议: 每月总剂量不超过15,000mg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("剂量警告设置")
            } footer: {
                Text("监控累计用药剂量，防止过量使用")
            }
            
            // 警告级别说明
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    WarningLevelRow(
                        level: "提醒",
                        color: .blue,
                        icon: "info.circle.fill",
                        description: "用药次数略高，建议关注"
                    )
                    
                    WarningLevelRow(
                        level: "警告",
                        color: .orange,
                        icon: "exclamationmark.triangle.fill",
                        description: "用药频率偏高，建议谨慎用药"
                    )
                    
                    WarningLevelRow(
                        level: "严重",
                        color: .red,
                        icon: "exclamationmark.octagon.fill",
                        description: "用药过量，强烈建议就医咨询"
                    )
                }
            } header: {
                Text("警告级别说明")
            }
            
            // 药物过量性头痛信息
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("什么是药物过量性头痛？")
                        .font(.subheadline.bold())
                    
                    Text("药物过量性头痛（Medication Overuse Headache, MOH）是由于过度使用止痛药物而引起的头痛。这种头痛通常表现为频率增加、药效减弱，形成恶性循环。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("预防要点:")
                            .font(.caption.bold())
                        Text("• 控制用药频率和剂量")
                            .font(.caption)
                        Text("• 寻找并避免头痛触发因素")
                            .font(.caption)
                        Text("• 尝试非药物缓解方法")
                            .font(.caption)
                        Text("• 定期咨询医生")
                            .font(.caption)
                    }
                }
            } header: {
                Text("了解药物过量性头痛")
            }
            
            // 统计信息
            Section {
                HStack {
                    Text("功能状态")
                    Spacer()
                    Label(warningEnabled ? "已启用" : "已禁用",
                          systemImage: warningEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(warningEnabled ? .green : .red)
                        .font(.caption)
                }
                
                HStack {
                    Text("当前设置")
                    Spacer()
                    Text("周限\(Int(weeklyLimit))次 / 月限\(Int(monthlyLimit))次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("当前状态")
            }
        }
        .navigationTitle("用药警告设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafetyGuide) {
            MedicationSafetyGuideView()
        }
    }
}

// 警告级别行组件
struct WarningLevelRow: View {
    let level: String
    let color: Color
    let icon: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(level)
                    .font(.subheadline.bold())
                    .foregroundColor(color)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// 更新SettingsView，添加用药警告设置入口
extension SettingsView {
    var medicationWarningSection: some View {
        Section {
            NavigationLink(destination: MedicationWarningSettingsView()) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("用药安全监控")
                        Text("监控用药频率，预防药物过量性头痛")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("健康监控")
        }
    }
}

#Preview {
    NavigationView {
        MedicationWarningSettingsView()
    }
}
