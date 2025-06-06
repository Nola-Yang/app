//
//  TriggerButton.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI

struct TriggerButton: View {
    let trigger: HeadacheTrigger
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: trigger.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(trigger.color))
                
                Text(trigger.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(trigger.color) : Color(trigger.color).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(trigger.color) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 扩展Color以支持字符串颜色名称
extension Color {
    init(_ colorName: String) {
        switch colorName {
        case "blue": self = .blue
        case "purple": self = .purple
        case "green": self = .green
        case "red": self = .red
        case "orange": self = .orange
        case "pink": self = .pink
        case "yellow": self = .yellow
        case "gray": self = .gray
        case "brown": self = .brown
        case "mint": self = .mint
        case "cyan": self = .cyan
        case "indigo": self = .indigo
        default: self = .blue
        }
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 12) {
        TriggerButton(
            trigger: .coldWind,
            isSelected: false
        ) { }
        
        TriggerButton(
            trigger: .sleepDeprivation,
            isSelected: true
        ) { }
        
        TriggerButton(
            trigger: .stress,
            isSelected: false
        ) { }
        
        TriggerButton(
            trigger: .socialInteraction,
            isSelected: true
        ) { }
    }
    .padding()
}
