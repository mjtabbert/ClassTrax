//
//  TypeBadge.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Updated: March 11, 2026
//

import SwiftUI

struct TypeBadge: View {

    let type: AlarmItem.ScheduleType

    var label: String {
        switch type {

        case .classPeriod:
            return "CLASS"

        case .prep:
            return "PREP"

        case .planning:
            return "PLAN"

        case .recess:
            return "RECESS"

        case .lunch:
            return "LUNCH"

        case .transition:
            return "MOVE"
        }
    }

    var body: some View {

        Text(label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(.white)
            .background(type.themeColor)
            .clipShape(Capsule())
    }
}
