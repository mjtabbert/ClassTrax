//
//  ActiveTimerCard.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI

struct ActiveTimerCard: View {

    let item: AlarmItem
    let now: Date

    @Environment(\.horizontalSizeClass) var sizeClass

    // MARK: - Timing

    private var start: Date {
        item.start
    }

    private var end: Date {
        item.end
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

    // MARK: - View

    var body: some View {

        GeometryReader { geo in

            let landscape = geo.size.width > geo.size.height

            if landscape {

                VStack(spacing: 16) {

                    Text(timeRemaining)
                        .font(.system(size: 140, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(item.className)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {

                VStack {

                    ZStack {

                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 20)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        .red, .orange, .yellow,
                                        .green, .blue, .purple, .red
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 6) {

                            Text("NOW")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(item.className)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(timeRemaining)
                                .font(.system(size: 56, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 280, height: 280)

                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Time Formatting

    private var timeRemaining: String {

        let seconds = Int(remaining)

        let minutes = seconds / 60
        let secs = seconds % 60

        return String(format: "%02d:%02d", minutes, secs)
    }
}
