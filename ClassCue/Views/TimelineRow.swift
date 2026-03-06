//
//  TimelineRow.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 5:40 PM
//  Version: ClassCue Dev Build 20
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
            RoundedRectangle(cornerRadius: 2)
                .fill(item.type.themeColor)
                .frame(width: 4, height: isCurrent ? 54 : 42)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.className)
                        .font(isHero ? .headline : .subheadline)
                        .fontWeight(isCurrent ? .black : .bold)
                        .italic(isTransition)
                        .foregroundColor(.primary)
                    
                    if isCurrent {
                        Text("NOW")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.type.themeColor)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    TypeBadge(type: item.type)
                }
                
                Text(timeRangeText(start: start, end: end))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if isHero, let countdownText {
                    Text(countdownText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(backgroundColor(isHero: isHero, isCurrent: isCurrent))
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
    
    private func backgroundColor(isHero: Bool, isCurrent: Bool) -> Color {
        if isCurrent {
            return item.type.themeColor.opacity(0.12)
        } else if isHero {
            return Color.blue.opacity(0.08)
        } else {
            return Color(.secondarySystemGroupedBackground)
        }
    }
}
