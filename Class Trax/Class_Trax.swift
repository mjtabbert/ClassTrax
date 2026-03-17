//
//  Class_Trax.swift
//  Class Trax
//
//  Created by Mike Tabbert on 3/11/26.
//

import WidgetKit
import SwiftUI

struct ClassTraxHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: ClassTraxWidgetSnapshot?
}

struct ClassTraxHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClassTraxHomeEntry {
        ClassTraxHomeEntry(date: .now, snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassTraxHomeEntry) -> Void) {
        completion(ClassTraxHomeEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? sampleSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassTraxHomeEntry>) -> Void) {
        let currentDate = Date()
        let snapshot = WidgetSnapshotStore.load()
        let entries = (0..<12).map { minuteOffset in
            ClassTraxHomeEntry(
                date: Calendar.current.date(byAdding: .minute, value: minuteOffset * 15, to: currentDate) ?? currentDate,
                snapshot: snapshot
            )
        }

        completion(Timeline(entries: entries, policy: .after(currentDate.addingTimeInterval(15 * 60))))
    }

    private var sampleSnapshot: ClassTraxWidgetSnapshot {
        let now = Date()
        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: .init(
                className: "Math",
                room: "Room 204",
                gradeLevel: "5th Grade",
                symbolName: "function",
                startTime: now.addingTimeInterval(-600),
                endTime: now.addingTimeInterval(1800),
                typeName: "Math"
            ),
            next: .init(
                className: "Science",
                room: "Lab 2",
                gradeLevel: "5th Grade",
                symbolName: "atom",
                startTime: now.addingTimeInterval(2100),
                endTime: now.addingTimeInterval(4500),
                typeName: "Science"
            )
        )
    }
}

struct ClassTraxHomeEntryView: View {
    let entry: ClassTraxHomeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor(for: entry.snapshot?.current ?? entry.snapshot?.next).opacity(0.08), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)

            content
                .padding(family == .systemSmall ? 6 : 8)
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            mediumContent
        default:
            smallContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

            if let current = entry.snapshot?.current {
                compactHero(title: "Now", block: current, timerDate: current.endTime)
                if let next = entry.snapshot?.next {
                    compactNextRow(next)
                }
            } else if let next = entry.snapshot?.next {
                compactHero(title: "Up Next", block: next, timerDate: next.startTime)
            } else {
                emptyState
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

            if let current = entry.snapshot?.current {
                compactHero(title: "Now", block: current, timerDate: current.endTime)
            } else {
                emptyState
            }

            if let next = entry.snapshot?.next {
                compactNextRow(next)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2.weight(.bold))
                Text("CLASSTRAX")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(entry.snapshot?.current == nil && entry.snapshot?.next == nil ? "Wrapped" : "Now")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func compactHero(title: String, block: ClassTraxWidgetSnapshot.BlockSummary, timerDate: Date) -> some View {
        let accent = accentColor(for: block)

        return ZStack(alignment: .topTrailing) {
            Image(systemName: block.symbolName)
                .font(.system(size: family == .systemSmall ? 44 : 54, weight: .bold))
                .foregroundStyle(accent.opacity(0.12))
                .offset(x: 4, y: -2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.14))
                        Image(systemName: block.symbolName)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(block.className)
                            .font((family == .systemSmall ? Font.subheadline : .headline).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer()

                    Text(timerDate, style: title == "Now" ? .timer : .relative)
                        .font(.system(size: family == .systemSmall ? 24 : 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }

                let meta = blockMetaText(block)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                HStack(spacing: 8) {
                    Text(block.startTime, style: .time)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    if title == "Now" {
                        progressBar(for: block)
                    }

                    Text(block.endTime, style: .time)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func compactNextRow(_ block: ClassTraxWidgetSnapshot.BlockSummary) -> some View {
        let accent = accentColor(for: block)

        return HStack(spacing: 8) {
            Text("Up Next")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)

            Text(block.className)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Text(block.startTime, style: .time)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func progressBar(for block: ClassTraxWidgetSnapshot.BlockSummary) -> some View {
        let duration = max(block.endTime.timeIntervalSince(block.startTime), 1)
        let elapsed = min(max(Date().timeIntervalSince(block.startTime), 0), duration)
        let progress = elapsed / duration
        let accent = accentColor(for: block)

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(accent.opacity(0.9))
                    .frame(width: max(proxy.size.width * progress, 6))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 6)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)

            Text("Day Wrapped")
                .font(.title3.weight(.bold))

            Text("Open ClassTrax for tomorrow’s schedule, tasks, and supports.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func blockMetaText(_ block: ClassTraxWidgetSnapshot.BlockSummary) -> String {
        [block.gradeLevel, block.room]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private func accentColor(for block: ClassTraxWidgetSnapshot.BlockSummary?) -> Color {
        switch block?.symbolName {
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

struct Class_Trax: Widget {
    let kind: String = "ClassTraxHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassTraxHomeProvider()) { entry in
            ClassTraxHomeEntryView(entry: entry)
        }
        .configurationDisplayName("Class Trax")
        .description("Current class, up next, and your teacher day at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    Class_Trax()
} timeline: {
    ClassTraxHomeEntry(
        date: .now,
        snapshot: ClassTraxWidgetSnapshot(
            updatedAt: .now,
            current: .init(
                className: "Math",
                room: "204",
                gradeLevel: "5th Grade",
                symbolName: "function",
                startTime: .now.addingTimeInterval(-600),
                endTime: .now.addingTimeInterval(2400),
                typeName: "Math"
            ),
            next: .init(
                className: "Science",
                room: "Lab 2",
                gradeLevel: "5th Grade",
                symbolName: "atom",
                startTime: .now.addingTimeInterval(2700),
                endTime: .now.addingTimeInterval(4500),
                typeName: "Science"
            )
        )
    )
}
