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
        let timelineDates = timelineDates(for: snapshot, from: currentDate)
        let entries = timelineDates.map { entryDate in
            ClassTraxHomeEntry(
                date: entryDate,
                snapshot: snapshotState(snapshot, at: entryDate)
            )
        }

        let refreshDate = timelineDates.last?.addingTimeInterval(60 * 5) ?? currentDate.addingTimeInterval(60 * 15)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private var sampleSnapshot: ClassTraxWidgetSnapshot {
        let now = Date()
        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: .init(
                id: UUID(),
                className: "Math",
                room: "Room 204",
                gradeLevel: "5th Grade",
                symbolName: "function",
                startTime: now.addingTimeInterval(-600),
                endTime: now.addingTimeInterval(1800),
                typeName: "Math",
                isHeld: false,
                bellSkipped: false
            ),
            next: .init(
                id: UUID(),
                className: "Science",
                room: "Lab 2",
                gradeLevel: "5th Grade",
                symbolName: "atom",
                startTime: now.addingTimeInterval(2100),
                endTime: now.addingTimeInterval(4500),
                typeName: "Science",
                isHeld: false,
                bellSkipped: false
            ),
            currentRoster: [
                .init(
                    id: UUID(),
                    name: "Avery Moss",
                    gradeLevel: "5",
                    attendanceStatusRawValue: "Present",
                    behaviorRatingRawValue: "onTask"
                )
            ],
            ignoreUntil: nil
        )
    }

    private func timelineDates(for snapshot: ClassTraxWidgetSnapshot?, from now: Date) -> [Date] {
        var dates: [Date] = [now]

        if let current = snapshot?.current {
            dates.append(current.endTime)
        }

        if let next = snapshot?.next {
            dates.append(next.startTime)
            dates.append(next.endTime)
        }

        let periodicDates = stride(from: 15, through: 90, by: 15).compactMap {
            Calendar.current.date(byAdding: .minute, value: $0, to: now)
        }
        dates.append(contentsOf: periodicDates)

        return Array(
            Set(dates.map { Calendar.current.dateInterval(of: .minute, for: $0)?.start ?? $0 })
        )
        .sorted()
    }

    private func snapshotState(_ snapshot: ClassTraxWidgetSnapshot?, at date: Date) -> ClassTraxWidgetSnapshot? {
        guard let snapshot else { return nil }

        let current = snapshot.current.flatMap { block -> ClassTraxWidgetSnapshot.BlockSummary? in
            guard date >= block.startTime, date < block.endTime else { return nil }
            return block
        }

        let next = snapshot.next.flatMap { block -> ClassTraxWidgetSnapshot.BlockSummary? in
            guard date < block.endTime else { return nil }
            return block
        }

        if let current {
            let normalizedNext = next?.id == current.id ? nil : next
            return ClassTraxWidgetSnapshot(
                updatedAt: date,
                current: current,
                next: normalizedNext,
                currentRoster: snapshot.currentRoster,
                ignoreUntil: snapshot.ignoreUntil
            )
        }

        if let next {
            if date >= next.startTime {
                return ClassTraxWidgetSnapshot(
                    updatedAt: date,
                    current: next,
                    next: nil,
                    currentRoster: snapshot.currentRoster,
                    ignoreUntil: snapshot.ignoreUntil
                )
            }

            return ClassTraxWidgetSnapshot(
                updatedAt: date,
                current: nil,
                next: next,
                currentRoster: [],
                ignoreUntil: snapshot.ignoreUntil
            )
        }

        return ClassTraxWidgetSnapshot(
            updatedAt: date,
            current: nil,
            next: nil,
            currentRoster: [],
            ignoreUntil: snapshot.ignoreUntil
        )
    }
}

struct ClassTraxHomeEntryView: View {
    let entry: ClassTraxHomeEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: ClassTraxWidgetSnapshot? {
        entry.snapshot
    }

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
                                colors: [accentColor(for: snapshot?.current ?? snapshot?.next).opacity(0.08), .clear],
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

            if let current = snapshot?.current {
                compactHero(title: "Now", block: current, timerDate: current.endTime)
                if let next = snapshot?.next {
                    compactNextRow(next)
                }
            } else if let next = snapshot?.next {
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

            if let current = snapshot?.current {
                compactHero(title: "Now", block: current, timerDate: current.endTime)
            } else {
                emptyState
            }

            if let next = snapshot?.next {
                compactNextRow(next)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Text("CLASSTRAX")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(headerStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(snapshot?.isStale == true ? .yellow : .secondary)
        }
    }

    private var headerStatusText: String {
        if snapshot?.isStale == true {
            return "Waiting"
        }

        return snapshot?.current == nil && snapshot?.next == nil ? "Wrapped" : "Now"
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

                    if title == "Now" && block.isHeld {
                        Label("Held", systemImage: "pause.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(timerDate, style: title == "Now" ? .timer : .relative)
                            .font(.system(size: family == .systemSmall ? 24 : 26, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
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

            Text(snapshot?.isStale == true ? "Waiting for Sync" : "Day Wrapped")
                .font(.title3.weight(.bold))

            Text(snapshot?.isStale == true
                 ? "Open ClassTrax on your iPhone if the schedule here looks out of date."
                 : "Open ClassTrax for tomorrow’s schedule, tasks, and supports.")
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
                id: UUID(),
                className: "Math",
                room: "204",
                gradeLevel: "5th Grade",
                symbolName: "function",
                startTime: .now.addingTimeInterval(-600),
                endTime: .now.addingTimeInterval(2400),
                typeName: "Math",
                isHeld: false,
                bellSkipped: false
            ),
            next: .init(
                id: UUID(),
                className: "Science",
                room: "Lab 2",
                gradeLevel: "5th Grade",
                symbolName: "atom",
                startTime: .now.addingTimeInterval(2700),
                endTime: .now.addingTimeInterval(4500),
                typeName: "Science",
                isHeld: false,
                bellSkipped: false
            ),
            currentRoster: [
                .init(
                    id: UUID(),
                    name: "Jordan Hale",
                    gradeLevel: "5",
                    attendanceStatusRawValue: "Present",
                    behaviorRatingRawValue: "neutral"
                )
            ],
            ignoreUntil: nil
        )
    )
}
