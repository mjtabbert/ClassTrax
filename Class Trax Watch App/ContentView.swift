import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var snapshotStore: WatchSnapshotStore

    @State private var lastHapticMarker: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date

            ZStack {
                watchBackground(for: snapshotStore.snapshot?.current ?? snapshotStore.snapshot?.next)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
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

    private func activeTimerSurface(_ block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                timerPill(title: "Now", accent: accentColor(for: block.symbolName))
                Text(block.typeName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(block.className)
                .font(.title3.weight(.black))
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            Text(block.endTime, style: .timer)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                timerInfoChip(
                    title: "Ends \(block.endTime.formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock",
                    accent: accentColor(for: block.symbolName)
                )

                if !block.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    timerInfoChip(
                        title: block.room,
                        systemImage: "mappin.and.ellipse",
                        accent: accentColor(for: block.symbolName)
                    )
                }
            }

            compactControls(for: block)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activeSurfaceBackground(for: block))
        .overlay(activeSurfaceBorder(for: block))
    }

    private func nextUpSurface(_ block: ClassTraxWatchSnapshot.BlockSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .lineLimit(2)

            Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if !block.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    timerInfoChip(
                        title: block.room,
                        systemImage: "mappin.and.ellipse",
                        accent: accentColor(for: block.symbolName)
                    )
                }

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
                Text("Next up is \(next.className) at \(next.startTime.formatted(date: .omitted, time: .shortened)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("The watch is waiting for the next schedule update from your iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func compactControls(for block: ClassTraxWatchSnapshot.BlockSummary) -> some View {
        HStack(spacing: 8) {
            Button {
                snapshotStore.toggleHold(for: block.id)
            } label: {
                Label("Hold", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                snapshotStore.skipBell(for: block.id)
            } label: {
                Label("Skip", systemImage: "bell.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .font(.caption2.weight(.bold))
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

    private func timerInfoChip(title: String, systemImage: String, accent: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
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
}

#Preview {
    ContentView()
        .environmentObject(WatchSnapshotStore.shared)
}
