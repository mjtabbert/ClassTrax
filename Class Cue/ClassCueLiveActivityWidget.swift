//
//  ClassCueLiveActivityWidget.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 13, 2026
//

import WidgetKit
import SwiftUI
import ActivityKit

struct ClassCueLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassCueActivityAttributes.self) { context in
            liveActivityLockScreen(context: context)
                .padding(.horizontal, 1)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(accentColor(for: context.state.iconName).opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: context.state.iconName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(accentColor(for: context.state.iconName))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.className)
                                .font(.headline.weight(.semibold))
                                .lineLimit(2)
                            if !context.state.room.isEmpty {
                                Text(context.state.room)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isHeld {
                        Label("Held", systemImage: "pause.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.endTime, style: .timer)
                            .font(.title2.weight(.black))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.nextClassName.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: context.state.nextIconName)
                                    .foregroundStyle(accentColor(for: context.state.nextIconName))
                                Text("Up Next")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(context.state.nextClassName)
                                .font(.caption)
                                .lineLimit(1)
                        } else {
                            Text("ClassCue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(accentColor(for: context.state.iconName).opacity(0.18))
                    Image(systemName: context.state.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentColor(for: context.state.iconName))
                }
            } compactTrailing: {
                if context.state.isHeld {
                    Image(systemName: "pause.fill")
                } else {
                    Text(context.state.endTime, style: .timer)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.iconName)
            }
        }
    }

    private func liveActivityLockScreen(context: ActivityViewContext<ClassCueActivityAttributes>) -> some View {
        let accent = accentColor(for: context.state.iconName)

        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18),
                            .white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.14))
                        Image(systemName: context.state.iconName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.className)
                            .font(.subheadline.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(context.state.isHeld ? "Held" : "Now")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(context.state.isHeld ? .orange : .secondary)
                    }

                    Spacer()

                    if !context.state.room.isEmpty {
                        Text(context.state.room)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                if context.state.isHeld {
                    Text("Paused")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text(context.state.endTime, style: .timer)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }

                if !context.state.nextClassName.isEmpty {
                    HStack(spacing: 8) {
                        Text("Up Next")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        Circle()
                            .fill(accentColor(for: context.state.nextIconName))
                            .frame(width: 6, height: 6)

                        Text(context.state.nextClassName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func accentColor(for symbolName: String) -> Color {
        switch symbolName {
        case "function":
            return .red
        case "text.book.closed.fill":
            return .orange
        case "atom":
            return .yellow
        case "globe.americas.fill":
            return .green
        case "pencil.and.ruler.fill":
            return .blue
        case "figure.run":
            return .indigo
        case "fork.knife":
            return .purple
        case "arrow.left.arrow.right":
            return .gray
        default:
            return .cyan
        }
    }
}
