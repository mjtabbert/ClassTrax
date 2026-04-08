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
        case .assembly:
            return .pink
        case .prep:
            return .cyan
        case .studyTime:
            return .blue
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
        return WarningStage(minutesRemaining: Int(remaining), configuredMinutes: item.warningLeadTimes)
    }

    // MARK: - View

    var body: some View {

        GeometryReader { geo in

            let landscape = geo.size.width > geo.size.height

            if landscape {

                VStack(spacing: 14) {
                    Text(timeRemaining)
                        .font(.system(size: landscapeTimerSize(for: geo), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(isCriticalCountdown ? .red : .primary)
                        .scaleEffect(isCriticalCountdown && pulse ? 1.04 : 0.98)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(landscapeBackdrop)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            } else {

                VStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(timeRemaining)
                            .font(.system(size: min(geo.size.width * 0.18, 56), weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                            .foregroundStyle(isCriticalCountdown ? .red : .primary)
                            .scaleEffect(isCriticalCountdown && pulse ? 1.03 : 0.99)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(currentBlockBackdrop)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(currentBlockBorderColor, lineWidth: 1)
                    )
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
            statusPill(
                "Now",
                tint: ringPrimaryColor,
                foregroundStyle: AnyShapeStyle(ringPrimaryColor)
            )

            if item.type != .blank {
                Text(item.typeLabel.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isHeld {
                statusPill(
                    "Hold",
                    tint: .orange,
                    foregroundStyle: AnyShapeStyle(.white)
                )
            }

            if bellSkipped {
                statusPill(
                    "Bell Skipped",
                    tint: Color(.systemGray5),
                    foregroundStyle: AnyShapeStyle(.secondary)
                )
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func detailsBlock(titleFont: Font, detailFont: Font) -> some View {
        let grade = item.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondaryLine = [grade, room]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        VStack(alignment: .leading, spacing: 10) {
            Text(item.displayClassName)
                .font(titleFont.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(timeRangeText)
                    .font(detailFont.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !secondaryLine.isEmpty {
                    Text(secondaryLine)
                        .font(detailFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeRemaining: String {

        let seconds = Int(remaining)

        let minutes = seconds / 60
        let secs = seconds % 60

        return "\(minutes):" + String(format: "%02d", secs)
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

    private var currentBlockBackdrop: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        ringPrimaryColor.opacity(isCriticalCountdown ? 0.18 : 0.14),
                        Color(.secondarySystemBackground).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var currentBlockBorderColor: Color {
        (isCriticalCountdown ? Color.red : ringPrimaryColor).opacity(isCriticalCountdown ? 0.32 : 0.18)
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

    @ViewBuilder
    private var currentBlockHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ringPrimaryColor.opacity(item.type == .blank ? 0.10 : 0.16))
                    .frame(width: 38, height: 58)

                Image(systemName: item.type.symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(item.type == .blank ? .secondary : ringPrimaryColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.displayClassName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    statusPill(
                        "Now",
                        tint: ringPrimaryColor,
                        foregroundStyle: AnyShapeStyle(.white)
                    )

                    Spacer(minLength: 6)

                    if item.type != .blank {
                        TypeBadge(type: item.type)
                    }
                }

                HStack(spacing: 10) {
                    Text(timeRangeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    let room = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !room.isEmpty {
                        Text(room)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    if isHeld {
                        statusPill(
                            "Hold",
                            tint: .orange,
                            foregroundStyle: AnyShapeStyle(.white)
                        )
                    }

                    if bellSkipped {
                        statusPill(
                            "Bell Skipped",
                            tint: Color(.systemGray5),
                            foregroundStyle: AnyShapeStyle(.secondary)
                        )
                    }
                }
            }
        }
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

    private func statusPill(
        _ title: String,
        tint: Color,
        foregroundStyle: AnyShapeStyle
    ) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.black))
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint, in: Capsule())
    }

    private func metadataChip(_ title: String, systemImage: String, font: Font) -> some View {
        Label(title, systemImage: systemImage)
            .font(font.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
    }
}

private extension ActiveTimerCard {
    enum WarningStage {
        case configured(minutes: Int, rank: Int)

        init?(minutesRemaining: Int, configuredMinutes: [Int]) {
            let sorted = configuredMinutes.filter { $0 > 0 }.sorted(by: >)
            guard let index = sorted.firstIndex(where: { minutesRemaining <= $0 * 60 && minutesRemaining > max(($0 - 1) * 60, 10) }) else {
                return nil
            }
            self = .configured(minutes: sorted[index], rank: index)
        }

        var label: String {
            switch self {
            case .configured(let minutes, _):
                return "\(minutes) MIN"
            }
        }

        var tint: Color {
            switch self {
            case .configured(_, let rank) where rank == 0:
                return .yellow
            case .configured(_, let rank) where rank == 1:
                return .orange
            default:
                return .red
            }
        }

        var prominentLabel: String {
            switch self {
            case .configured(let minutes, _):
                return minutes == 1 ? "1 MINUTE REMAINING" : "\(minutes) MINUTES REMAINING"
            }
        }
    }
}
