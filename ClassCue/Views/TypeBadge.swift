//
//  TypeBadge.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Updated: March 11, 2026
//

import SwiftUI

struct TypeBadge: View {

    let type: AlarmItem.ScheduleType

    var label: String {
        switch type {

        case .math:
            return "MATH"

        case .ela:
            return "ELA"

        case .science:
            return "SCIENCE"

        case .socialStudies:
            return "SOCIAL"

        case .assembly:
            return "ASSEMBLY"

        case .prep:
            return "PREP"

        case .studyTime:
            return "STUDY"

        case .recess:
            return "RECESS"

        case .lunch:
            return "LUNCH"

        case .transition:
            return "MOVE"

        case .other:
            return "OTHER"

        case .blank:
            return "BLANK"
        }
    }

    var foregroundColor: Color {
        switch type {
        case .science, .blank, .studyTime:
            return .primary
        case .transition:
            return .secondary
        default:
            return .white
        }
    }

    var body: some View {
        let usesBlankPalette = type == .blank
        let topColor = usesBlankPalette ? Color.blue.opacity(0.28) : type.themeColor.opacity(0.95)
        let bottomColor = usesBlankPalette ? Color.cyan.opacity(0.20) : type.themeColor.opacity(0.72)

        HStack(spacing: 5) {
            Image(systemName: type.symbolName)
                .font(.system(size: 9, weight: .black))

            Text(label)
                .font(.caption2)
                .fontWeight(.black)
                .tracking(0.3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundColor(foregroundColor)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [topColor, bottomColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}
