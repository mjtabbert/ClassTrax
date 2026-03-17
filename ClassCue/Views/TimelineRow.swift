//
//  TimelineRow.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 5:40 PM
//  Version: ClassTrax Dev Build 20
//

import SwiftUI

struct TimelineRow: View {
    
    let item: AlarmItem
    let now: Date
    let isHero: Bool
    
    var body: some View {
        let start = startDateToday(for: item)
        let end = endDateToday(for: item)
        let isPast = end < now
        let isCurrent = now >= start && now < end
        let isTransition = item.type == .transition
        let countdownText = timeUntilStartText()

        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.type.themeColor.opacity(item.type == .blank ? 0.12 : 0.18))
                    .frame(width: 34, height: 56)

                Image(systemName: item.type.symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(item.type == .blank ? .secondary : item.type.themeColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.className)
                        .font(isHero ? .headline : .subheadline)
                        .fontWeight(isCurrent ? .black : .bold)
                        .italic(isTransition)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if isCurrent {
                        Text("NOW")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.type.themeColor, in: Capsule())
                    }

                    Spacer(minLength: 6)

                    TypeBadge(type: item.type)
                }

                HStack(spacing: 10) {
                    Text(timeRangeText(start: start, end: end))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.location)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if isHero, let countdownText {
                    Text(countdownText)
                        .font(.caption.weight(.bold))
                        .foregroundColor(item.type == .blank ? .blue : item.type.themeColor)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground(isHero: isHero, isCurrent: isCurrent))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor(isCurrent: isCurrent), lineWidth: isCurrent ? 1.2 : 1)
        )
        .opacity(isPast ? 0.38 : 1.0)
    }
    
    private func timeRangeText(start: Date, end: Date) -> String {
        let startText = start.formatted(date: .omitted, time: .shortened)
        let endText = end.formatted(date: .omitted, time: .shortened)
        return "\(startText) – \(endText)"
    }
    
    private func timeUntilStartText() -> String? {
        let remaining = Int(startDateToday(for: item).timeIntervalSince(now))
        
        if remaining <= 0 {
            return nil
        }
        
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        
        if hours > 0 {
            return String(format: "Starts in %d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "Starts in %d:%02d", minutes, seconds)
        }
    }
    
    private func startDateToday(for item: AlarmItem) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.startTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }
    
    private func endDateToday(for item: AlarmItem) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.endTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }
    
    private func cardBackground(isHero: Bool, isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        item.type.themeColor.opacity(isCurrent ? 0.18 : isHero ? 0.12 : 0.08),
                        Color(.secondarySystemBackground).opacity(isCurrent ? 0.92 : 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func borderColor(isCurrent: Bool) -> Color {
        if isCurrent {
            return item.type.themeColor.opacity(0.42)
        }
        return Color.white.opacity(0.08)
    }
}
