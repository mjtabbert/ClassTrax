//
//  NextUpSummaryCard.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import SwiftUI

struct NextUpSummaryCard: View {

    let item: AlarmItem
    let now: Date
    var isCompact: Bool = false

    var body: some View {

        HStack(alignment: .top, spacing: 14) {

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(item.type.themeColor.opacity(0.16))
                    .frame(width: isCompact ? 42 : 50, height: isCompact ? 42 : 50)

                Image(systemName: item.type.symbolName)
                    .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                    .foregroundStyle(item.type == .blank ? .secondary : item.type.themeColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("NEXT UP")
                        .font(.caption.weight(.black))
                        .foregroundColor(item.type == .blank ? .blue : item.type.themeColor)

                    TypeBadge(type: item.type)
                }

                Text(item.className)
                    .font(isCompact ? .subheadline : .headline)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(timeRangeText)
                    .font((isCompact ? Font.footnote : .subheadline).weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.location)
                        .font(isCompact ? .caption : .footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Text(timeText)
                    .font((isCompact ? Font.headline : .title3).weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Capsule(style: .continuous)
                    .fill(item.type.themeColor.opacity(0.22))
                    .frame(width: isCompact ? 56 : 76, height: 6)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(item.type.themeColor == .clear ? Color.blue : item.type.themeColor)
                            .frame(width: progressWidth)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            item.type.themeColor.opacity(0.10),
                            Color(.systemGray6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Timing

    private var start: Date {
        anchoredTime(for: item.startTime) ?? item.startTime
    }

    private var end: Date {
        anchoredEndTime
    }

    private var timeText: String {

        let totalSeconds = max(Int(start.timeIntervalSince(now)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var timeRangeText: String {
        "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private var progressWidth: CGFloat {
        let total = max(end.timeIntervalSince(start), 1)
        let remaining = max(start.timeIntervalSince(now), 0)
        let progress = CGFloat(1 - (remaining / total))
        let base = isCompact ? 56.0 : 76.0
        return max(12, base * progress)
    }

    private var anchoredEndTime: Date {
        guard let anchoredEnd = anchoredTime(for: item.endTime) else {
            return item.endTime
        }

        if anchoredEnd >= start {
            return anchoredEnd
        }

        return Calendar.current.date(byAdding: .day, value: 1, to: anchoredEnd) ?? anchoredEnd
    }

    private func anchoredTime(for date: Date) -> Date? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        )
    }
}
