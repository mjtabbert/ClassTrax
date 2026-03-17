//
//  ActiveTimerCard.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import SwiftUI

struct ActiveTimerCard: View {

    let item: AlarmItem
    let now: Date
    var isTeacherMode: Bool = false
    var isHeld: Bool = false
    var bellSkipped: Bool = false
    var onHoldToggle: (() -> Void)? = nil
    var onExtend: ((Int) -> Void)? = nil
    var onSkipBell: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var pulse = false

    // MARK: - Timing

    private var start: Date {
        anchoredTime(for: item.startTime) ?? item.startTime
    }

    private var end: Date {
        anchoredEndTime
    }

    private var total: TimeInterval {
        end.timeIntervalSince(start)
    }

    private var remaining: TimeInterval {
        max(end.timeIntervalSince(now), 0)
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(1 - remaining / total)
    }

    private var ringPrimaryColor: Color {
        item.type.themeColor == .clear ? .blue : item.type.themeColor
    }

    private var ringSecondaryColor: Color {
        if isCriticalCountdown {
            return .orange
        }

        switch item.type {
        case .math:
            return .orange
        case .ela:
            return .yellow
        case .science:
            return .green
        case .socialStudies:
            return .mint
        case .prep:
            return .cyan
        case .recess:
            return .teal
        case .lunch:
            return .pink
        case .transition:
            return Color(.systemGray3)
        case .other:
            return Color(.systemGray2)
        case .blank:
            return .cyan
        }
    }

    private var isCriticalCountdown: Bool {
        remaining > 0 && remaining <= 10
    }

    private var warningStage: WarningStage? {
        guard remaining > 10 else { return nil }

        switch remaining {
        case ...60:
            return .oneMinute
        case ...120:
            return .twoMinutes
        case ...300:
            return .fiveMinutes
        default:
            return nil
        }
    }

    // MARK: - View

    var body: some View {

        GeometryReader { geo in

            let landscape = geo.size.width > geo.size.height

            if landscape {

                VStack(spacing: 14) {

                    headerRow

                    Text(timeRemaining)
                        .font(.system(size: landscapeTimerSize(for: geo), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 20)
                        .foregroundStyle(isCriticalCountdown ? .red : .primary)
                        .scaleEffect(isCriticalCountdown && pulse ? 1.04 : 0.98)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)

                    if let warningStage {
                        warningCallout(for: warningStage, compact: false)
                    }

                    detailsBlock(
                        titleFont: isTeacherMode ? .system(size: 38, weight: .bold, design: .rounded) : .largeTitle,
                        detailFont: isTeacherMode ? .title2 : .title3
                    )

                    controlStrip(compact: false)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(landscapeBackdrop)
                .overlay(alignment: .topTrailing) {
                    if let warningStage {
                        warningBadge(for: warningStage)
                            .padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            } else {

                VStack {

                    ZStack(alignment: .top) {

                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 20)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        ringPrimaryColor,
                                        ringSecondaryColor,
                                        ringPrimaryColor
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: ringPrimaryColor.opacity(0.28), radius: 10)
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(isCriticalCountdown ? Color.red.opacity(0.28) : .clear, lineWidth: 28)
                                    .blur(radius: 8)
                                    .rotationEffect(.degrees(-90))
                                    .scaleEffect(isCriticalCountdown && pulse ? 1.03 : 0.98)
                            )

                        VStack(spacing: 8) {

                            headerRow

                            Text(timeRemaining)
                                .font(.system(size: min(geo.size.width * 0.16, 48), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, 24)
                                .foregroundStyle(isCriticalCountdown ? .red : .primary)
                                .scaleEffect(isCriticalCountdown && pulse ? 1.04 : 0.98)

                            if let warningStage {
                                warningCallout(for: warningStage, compact: true)
                            }

                            detailsBlock(titleFont: .title3, detailFont: .caption)

                            controlStrip(compact: true)
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(width: 280, height: 280)

                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            pulse = true
        }
    }

    // MARK: - Time Formatting

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("NOW")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            TypeBadge(type: item.type)

            if isHeld {
                Text("HOLD")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange)
                    .clipShape(Capsule())
            }

            if bellSkipped {
                Text("BELL SKIPPED")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func detailsBlock(titleFont: Font, detailFont: Font) -> some View {
        let grade = item.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = item.location.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(item.className)
                    .font(titleFont.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                if !room.isEmpty {
                    Text("• \(room)")
                        .font(detailFont.weight(.semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(timeRangeText)
                .font(detailFont.weight(.semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !grade.isEmpty {
                Text(grade)
                    .font(detailFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var timeRemaining: String {

        let seconds = Int(remaining)

        let minutes = seconds / 60
        let secs = seconds % 60

        return String(format: "%02d:%02d", minutes, secs)
    }

    private var timeRangeText: String {
        "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func landscapeTimerSize(for geo: GeometryProxy) -> CGFloat {
        let multiplier = isTeacherMode ? 0.37 : 0.30
        let maxSize: CGFloat = isTeacherMode ? 180 : 116
        return min(geo.size.width * multiplier, maxSize)
    }

    private var landscapeBackdrop: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        ringPrimaryColor.opacity(warningStage == nil ? 0.14 : 0.18),
                        warningBackdropColor.opacity(warningStage == nil ? 0.10 : 0.22),
                        Color(.systemBackground).opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke((warningStage?.tint ?? ringPrimaryColor).opacity(warningStage == nil ? 0.22 : 0.52), lineWidth: warningStage == nil ? 1 : 2)
            )
    }

    private var warningBackdropColor: Color {
        warningStage?.tint ?? ringSecondaryColor
    }

    @ViewBuilder
    private func warningBadge(for stage: WarningStage) -> some View {
        Text(stage.label)
            .font(.caption2.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(stage.tint, in: Capsule())
            .shadow(color: stage.tint.opacity(0.25), radius: 8, y: 4)
    }

    private func warningCallout(for stage: WarningStage, compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: "bell.badge.fill")
                .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))

            Text(stage.prominentLabel)
                .font((compact ? Font.caption.weight(.black) : .subheadline.weight(.black)))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [stage.tint, stage.tint.opacity(0.82)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: stage.tint.opacity(0.35), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .scaleEffect(pulse ? 1.01 : 0.99)
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

    @ViewBuilder
    private func controlStrip(compact: Bool) -> some View {
        if onHoldToggle != nil || onExtend != nil || onSkipBell != nil {
            VStack(spacing: compact ? 6 : 8) {
                HStack(spacing: compact ? 6 : 8) {
                    controlButton(
                        title: isHeld ? "Resume" : "Hold",
                        systemImage: isHeld ? "play.fill" : "pause.fill",
                        tint: .orange,
                        compact: compact
                    ) {
                        onHoldToggle?()
                    }

                    ForEach([1, 2, 5], id: \.self) { minutes in
                        controlButton(
                            title: "+\(minutes)m",
                            systemImage: "plus",
                            tint: ringPrimaryColor,
                            compact: compact
                        ) {
                            onExtend?(minutes)
                        }
                    }
                }

                controlButton(
                    title: bellSkipped ? "Bell Skipped" : "Skip Bell",
                    systemImage: bellSkipped ? "bell.slash.fill" : "bell.slash",
                    tint: .secondary,
                    compact: compact,
                    fullWidth: true,
                    disabled: bellSkipped
                ) {
                    onSkipBell?()
                }
            }
            .padding(.top, 4)
        }
    }

    private func controlButton(
        title: String,
        systemImage: String,
        tint: Color,
        compact: Bool,
        fullWidth: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font((compact ? Font.caption : .subheadline).weight(.bold))
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(disabled)
        .controlSize(compact ? .small : .regular)
    }
}

private extension ActiveTimerCard {
    enum WarningStage {
        case fiveMinutes
        case twoMinutes
        case oneMinute

        var label: String {
            switch self {
            case .fiveMinutes:
                return "5 MIN"
            case .twoMinutes:
                return "2 MIN"
            case .oneMinute:
                return "1 MIN"
            }
        }

        var tint: Color {
            switch self {
            case .fiveMinutes:
                return .yellow
            case .twoMinutes:
                return .orange
            case .oneMinute:
                return .red
            }
        }

        var prominentLabel: String {
            switch self {
            case .fiveMinutes:
                return "5 MINUTES REMAINING"
            case .twoMinutes:
                return "2 MINUTES REMAINING"
            case .oneMinute:
                return "1 MINUTE REMAINING"
            }
        }
    }
}
