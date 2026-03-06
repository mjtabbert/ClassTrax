//
//  NextUpCard.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 5:25 PM
//  Version: ClassCue Dev Build 19
//

import SwiftUI

struct NextUpCard: View {
    
    let item: AlarmItem
    let now: Date
    
    @State private var pulse = false
    
    var body: some View {
        let remaining = timeUntilStart()
        let isSoon = remaining <= 60 && remaining > 0
        let isCritical = remaining <= 10 && remaining > 0
        
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progressValue())
                    .stroke(
                        ringGradient(isSoon: isSoon, isCritical: isCritical),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(isCritical && pulse ? 1.03 : 1.0)
                    .animation(
                        isCritical
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                        value: pulse
                    )
                
                VStack(spacing: 4) {
                    Text(formatCountdown(remaining))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(countdownColor(isSoon: isSoon, isCritical: isCritical))
                    
                    Text(statusText(isSoon: isSoon, isCritical: isCritical))
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
            }
            .frame(height: 130)
            
            VStack(spacing: 4) {
                Text("NEXT UP")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(countdownColor(isSoon: isSoon, isCritical: isCritical))
                    .tracking(2)
                
                Text(item.className.uppercased())
                    .font(.title3)
                    .fontWeight(.black)
                
                Text(timeRangeText())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(item.gradeLevel) • \(item.location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(countdownColor(isSoon: isSoon, isCritical: isCritical), lineWidth: isSoon ? 4 : 0)
        )
        .scaleEffect(isCritical && pulse ? 1.01 : 1.0)
        .animation(
            isCritical
            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
            : .default,
            value: pulse
        )
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
        .onAppear {
            pulse = true
        }
    }
    
    private func timeUntilStart() -> TimeInterval {
        let startComp = Calendar.current.dateComponents([.hour, .minute], from: item.startTime)
        let startToday = Calendar.current.date(
            bySettingHour: startComp.hour ?? 0,
            minute: startComp.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        
        return startToday.timeIntervalSince(now)
    }
    
    private func progressValue() -> CGFloat {
        let remaining = max(0, timeUntilStart())
        let totalWindow: TimeInterval = 3600
        let progress = 1.0 - min(remaining / totalWindow, 1.0)
        return CGFloat(max(0, min(progress, 1)))
    }
    
    private func timeRangeText() -> String {
        let start = item.startTime.formatted(date: .omitted, time: .shortened)
        let end = item.endTime.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let secs = value % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func countdownColor(isSoon: Bool, isCritical: Bool) -> Color {
        if isCritical {
            return .red
        } else if isSoon {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func statusText(isSoon: Bool, isCritical: Bool) -> String {
        if isCritical {
            return "BELL IN SECONDS"
        } else if isSoon {
            return "STARTING SOON"
        } else {
            return "UNTIL START"
        }
    }
    
    private func ringGradient(isSoon: Bool, isCritical: Bool) -> AngularGradient {
        if isCritical {
            return AngularGradient(
                gradient: Gradient(colors: [.red, .orange, .red]),
                center: .center
            )
        } else if isSoon {
            return AngularGradient(
                gradient: Gradient(colors: [.orange, .yellow, .orange]),
                center: .center
            )
        } else {
            return AngularGradient(
                gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .yellow, .green, .blue]),
                center: .center
            )
        }
    }
}
