import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var snapshotStore: WatchSnapshotStore

    @State private var lastHapticMarker: String?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let now = context.date

                ZStack {
                    watchBackground(for: snapshotStore.snapshot?.current ?? snapshotStore.snapshot?.next)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let feedback = snapshotStore.commandFeedback {
                                commandFeedbackSurface(feedback)
                            }

                            if snapshotStore.snapshot?.isStale == true {
                                staleSyncSurface
                            }

                            if let current = snapshotStore.snapshot?.current {
                                activeTimerSurface(current, now: now)
                            } else {
                                wrappedSurface(now: now)
                            }

                            if let next = nextBlock(for: now) {
                                nextUpSurface(next, now: now)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
                .onAppear {
                    triggerHapticsIfNeeded(now: now)
                }
                .onChange(of: hapticMarker(now: now)) { _, _ in
                    triggerHapticsIfNeeded(now: now)
                }
            }
            .containerBackground(.clear, for: .navigation)
        }
    }

    private func activeTimerSurface(_ block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> some View {
        let grade = block.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = block.room.trimmingCharacters(in: .whitespacesAndNewlines)
        let supportingLine = [grade, room]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                timerPill(title: "Now", accent: accentColor(for: block.symbolName))

                Spacer(minLength: 0)
            }

            Text(block.className)
                .font(.title3.weight(.black))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if block.isHeld {
                Label("Held", systemImage: "pause.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(block.endTime, style: .timer)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)

            if !supportingLine.isEmpty {
                Text(supportingLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if block.bellSkipped {
                Label("Bell skipped", systemImage: "bell.slash.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let ignoreUntil = snapshotStore.snapshot?.ignoreUntil, ignoreUntil > now {
                Label(
                    "Snoozed until \(ignoreUntil.formatted(date: .omitted, time: .shortened))",
                    systemImage: "bell.slash.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            controlGrid(for: block, now: now)

            if !snapshotStore.snapshot.map(\.currentRoster).unwrap(or: []).isEmpty {
                rosterSection(for: block)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activeSurfaceBackground(for: block))
        .overlay(activeSurfaceBorder(for: block))
    }

    private func nextUpSurface(_ block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> some View {
        let grade = block.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                timerPill(title: "Next", accent: accentColor(for: block.symbolName))

                Spacer(minLength: 0)

                Text(timeUntilStartText(for: block, now: now))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(block.className)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)

            if !grade.isEmpty {
                Text(grade)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accentColor(for: block.symbolName).opacity(0.16), lineWidth: 1)
        )
    }

    private func wrappedSurface(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            timerPill(title: "Wrapped", accent: .gray)

            Text("No active block")
                .font(.headline.weight(.bold))

            if let next = nextBlock(for: now) {
                Text("\(next.className) at \(next.startTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Waiting for the next schedule update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var staleSyncSurface: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.slash")
                .foregroundStyle(.yellow)

            Text("Waiting for iPhone sync")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.yellow.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.yellow.opacity(0.18), lineWidth: 1)
        )
    }

    private func commandFeedbackSurface(_ feedback: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .foregroundStyle(.green)

            Text(feedback)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.green.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.20), lineWidth: 1)
        )
    }

    private func timerPill(title: String, accent: Color) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.black))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.14))
            )
    }

    private func controlGrid(for block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                watchActionButton(
                    title: block.isHeld ? "Resume" : "Hold",
                    systemImage: block.isHeld ? "play.fill" : "pause.fill",
                    tint: .orange
                ) {
                    snapshotStore.toggleHold(for: block.id)
                }

                watchActionButton(
                    title: "+1 Min",
                    systemImage: "plus.circle.fill",
                    tint: .blue
                ) {
                    snapshotStore.extend(itemID: block.id, minutes: 1)
                }
            }

            HStack(spacing: 8) {
                watchActionButton(
                    title: block.bellSkipped ? "Skipped" : "Skip Bell",
                    systemImage: "bell.slash.fill",
                    tint: .yellow
                ) {
                    snapshotStore.skipBell(for: block.id)
                }

                if let ignoreUntil = snapshotStore.snapshot?.ignoreUntil, ignoreUntil > now {
                    watchActionButton(
                        title: "Unsnooze",
                        systemImage: "bell.fill",
                        tint: .green
                    ) {
                        snapshotStore.clearSnooze()
                    }
                } else {
                    watchActionButton(
                        title: "Snooze 15",
                        systemImage: "zzz",
                        tint: .purple
                    ) {
                        snapshotStore.snoozeBell(minutes: 15)
                    }
                }
            }
        }
    }

    private func rosterSection(for block: ClassTraxWatchSnapshot.BlockSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Roster")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("\(snapshotStore.snapshot?.currentRoster.count ?? 0)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            ForEach(snapshotStore.snapshot?.currentRoster ?? []) { student in
                NavigationLink {
                    WatchStudentActionView(
                        block: block,
                        student: student,
                        onAttendance: { status in
                            snapshotStore.markAttendance(block: block, student: student, status: status)
                        },
                        onBehavior: { rating in
                            snapshotStore.logBehavior(block: block, student: student, rating: rating)
                        }
                    )
                } label: {
                    studentRow(student)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func studentRow(_ student: ClassTraxWatchSnapshot.StudentSummary) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(student.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !student.gradeLevel.isEmpty {
                    Text(student.gradeLevel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let attendance = student.attendanceStatusRawValue {
                compactStatusPill(label: attendanceLabel(for: attendance), tint: attendanceTint(for: attendance))
            }

            if let rating = student.behaviorRatingRawValue {
                compactStatusPill(label: behaviorLabel(for: rating), tint: behaviorTint(for: rating))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func compactStatusPill(label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }

    private func watchActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .tint(tint)
    }

    private func watchBackground(for block: ClassTraxWatchSnapshot.BlockSummary?) -> some View {
        let accent = accentColor(for: block?.symbolName ?? "")

        return LinearGradient(
            colors: [
                accent.opacity(0.28),
                Color.black,
                Color.black.opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func activeSurfaceBackground(for block: ClassTraxWatchSnapshot.BlockSummary) -> some View {
        let accent = accentColor(for: block.symbolName)

        return RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.24),
                        accent.opacity(0.08),
                        Color.black.opacity(0.40)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func activeSurfaceBorder(for block: ClassTraxWatchSnapshot.BlockSummary) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(accentColor(for: block.symbolName).opacity(0.22), lineWidth: 1)
    }

    private func nextBlock(for now: Date) -> ClassTraxWatchSnapshot.BlockSummary? {
        guard let next = snapshotStore.snapshot?.next else { return nil }
        return next.startTime > now ? next : snapshotStore.snapshot?.current == nil ? next : nil
    }

    private func timeUntilStartText(for block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> String {
        let interval = max(Int(block.startTime.timeIntervalSince(now)), 0)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private func hapticMarker(now: Date) -> String? {
        guard let current = snapshotStore.snapshot?.current else { return nil }
        let remainingSeconds = Int(current.endTime.timeIntervalSince(now))
        guard remainingSeconds >= 0 else { return "\(current.id.uuidString)-end" }

        let markers = [300, 120, 60, 10, 0]
        guard let matched = markers.first(where: { abs(remainingSeconds - $0) <= 1 }) else { return nil }
        return "\(current.id.uuidString)-\(matched)"
    }

    private func triggerHapticsIfNeeded(now: Date) {
        guard let marker = hapticMarker(now: now), marker != lastHapticMarker else { return }
        lastHapticMarker = marker

        if marker.hasSuffix("-0") {
            WKInterfaceDevice.current().play(.notification)
        } else if marker.hasSuffix("-10") {
            WKInterfaceDevice.current().play(.retry)
        } else {
            WKInterfaceDevice.current().play(.directionUp)
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

    private func attendanceLabel(for rawValue: String) -> String {
        switch rawValue {
        case "Present":
            return "P"
        case "Absent":
            return "A"
        case "Tardy":
            return "T"
        case "Excused":
            return "E"
        default:
            return rawValue.prefix(1).uppercased()
        }
    }

    private func attendanceTint(for rawValue: String) -> Color {
        switch rawValue {
        case "Present":
            return .green
        case "Absent":
            return .red
        case "Tardy":
            return .orange
        case "Excused":
            return .blue
        default:
            return .gray
        }
    }

    private func behaviorLabel(for rawValue: String) -> String {
        switch rawValue {
        case "onTask":
            return "🙂"
        case "neutral":
            return "😐"
        case "needsSupport":
            return "☹️"
        default:
            return "•"
        }
    }

    private func behaviorTint(for rawValue: String) -> Color {
        switch rawValue {
        case "onTask":
            return .green
        case "neutral":
            return .yellow
        case "needsSupport":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSnapshotStore.shared)
}

private struct WatchStudentActionView: View {
    let block: ClassTraxWatchSnapshot.BlockSummary
    let student: ClassTraxWatchSnapshot.StudentSummary
    let onAttendance: (String) -> Void
    let onBehavior: (String) -> Void

    private let attendanceOptions = ["Present", "Absent", "Tardy", "Excused"]
    private let behaviorOptions: [(label: String, value: String, tint: Color)] = [
        ("🙂", "onTask", .green),
        ("😐", "neutral", .yellow),
        ("☹️", "needsSupport", .red)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.headline.weight(.bold))

                    Text(block.className)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !student.gradeLevel.isEmpty {
                        Text(student.gradeLevel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Attendance")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    ForEach(attendanceOptions, id: \.self) { option in
                        Button {
                            onAttendance(option)
                        } label: {
                            Text(option)
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(attendanceTint(for: option).opacity(0.16))
                                )
                        }
                        .buttonStyle(.plain)
                        .tint(attendanceTint(for: option))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavior")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(behaviorOptions, id: \.value) { option in
                            Button {
                                onBehavior(option.value)
                            } label: {
                                Text(option.label)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(option.tint.opacity(0.16))
                                    )
                            }
                            .buttonStyle(.plain)
                            .tint(option.tint)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .navigationTitle(student.name)
    }

    private func attendanceTint(for rawValue: String) -> Color {
        switch rawValue {
        case "Present":
            return .green
        case "Absent":
            return .red
        case "Tardy":
            return .orange
        case "Excused":
            return .blue
        default:
            return .gray
        }
    }
}

private extension Optional {
    func unwrap(or defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }
}
