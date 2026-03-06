//
//  RootTabView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import SwiftUI

// MARK: - App Tabs

enum AppTab: Hashable {
    case today
    case schedule
    case todo
    case notes
    case settings
}

// MARK: - Weekday Tabs

enum WeekdayTab: Int, CaseIterable {

    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var shortTitle: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    static var today: WeekdayTab {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return WeekdayTab(rawValue: weekday) ?? .monday
    }
}

// MARK: - Root View

struct RootTabView: View {

    @State private var selectedTab: AppTab = .today
    @StateObject private var timerEngine = TimerEngine()

    // MARK: Persisted Storage

    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0

    // MARK: Runtime State

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []

    // MARK: Ignore Logic

    private var ignoreDate: Date? {
        ignoreUntil > 0 ? Date(timeIntervalSince1970: ignoreUntil) : nil
    }

    private var currentDate: Date {
        timerEngine.now
    }

    private var todaySchedule: [AlarmItem] {
        makeTodaySchedule()
    }

    private var activeTodayItem: AlarmItem? {
        let now = currentDate
        return todaySchedule.first { now >= $0.start && now <= $0.end }
    }

    private var nextTodayItem: AlarmItem? {
        let now = currentDate
        return todaySchedule.first { $0.start > now }
    }

    // MARK: UI

    var body: some View {
        TabView(selection: $selectedTab) {
            todayTab
            scheduleTab
            todoTab
            notesTab
            settingsTab
        }

        // MARK: Lifecycle

        .onAppear {
            loadSavedData()
            NotificationManager.shared.refreshNotifications(for: alarms)
        }

        .onChange(of: alarms) { _, newValue in
            persistAlarms(newValue)
        }

        .onChange(of: todos) { _, newValue in
            persistTodos(newValue)
        }
    }

    private var todayTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                todayHeader(now: currentDate)

                if let activeTodayItem {
                    LocalActiveTimerCard(item: activeTodayItem, now: currentDate)
                        .padding(.horizontal)
                }

                if let nextTodayItem {
                    LocalNextUpSummaryCard(item: nextTodayItem, now: currentDate)
                        .padding(.horizontal)
                }

                VStack(spacing: 8) {
                    ForEach(todaySchedule) { item in
                        TimelineRow(
                            item: item,
                            now: currentDate,
                            isHero: false
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .tabItem {
            Label("Today", systemImage: "clock")
        }
        .tag(AppTab.today)
    }

    private var scheduleTab: some View {
        ScheduleView(alarms: $alarms)
        .tabItem {
            Label("Schedule", systemImage: "calendar")
        }
        .tag(AppTab.schedule)
    }

    private var todoTab: some View {
        TodoListView(todos: $todos)
            .tabItem {
                Label("To Do", systemImage: "checklist")
            }
            .tag(AppTab.todo)
    }

    private var notesTab: some View {
        NotesView()
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .tag(AppTab.notes)
    }

    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
    }

    private func todayHeader(now: Date) -> some View {
        VStack(spacing: 4) {
            Text(now.formatted(.dateTime.weekday(.wide)))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .tracking(4)

            Text(now.formatted(.dateTime.month().day()))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(now.formatted(.dateTime.hour().minute()))
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    private func makeTodaySchedule() -> [AlarmItem] {
        [
            AlarmItem(
                name: "Advisory",
                start: dateToday(hour: 8, minute: 0),
                end: dateToday(hour: 8, minute: 20),
                location: "Homeroom"
            ),
            AlarmItem(
                name: "WIN",
                start: dateToday(hour: 8, minute: 25),
                end: dateToday(hour: 9, minute: 0),
                location: "Assigned Room"
            ),
            AlarmItem(
                name: "Period 1",
                start: dateToday(hour: 9, minute: 5),
                end: dateToday(hour: 9, minute: 50),
                location: "Room 201"
            ),
            AlarmItem(
                name: "Period 2",
                start: dateToday(hour: 9, minute: 55),
                end: dateToday(hour: 10, minute: 40),
                location: "Room 204"
            ),
            AlarmItem(
                name: "Lunch",
                start: dateToday(hour: 10, minute: 45),
                end: dateToday(hour: 11, minute: 15),
                location: "Cafeteria"
            ),
            AlarmItem(
                name: "Period 3",
                start: dateToday(hour: 11, minute: 20),
                end: dateToday(hour: 12, minute: 5),
                location: "Room 210"
            ),
            AlarmItem(
                name: "Period 4",
                start: dateToday(hour: 12, minute: 10),
                end: dateToday(hour: 12, minute: 55),
                location: "Room 212"
            )
        ]
    }

    private func dateToday(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    // MARK: Data Loading

    private func loadSavedData() {

        if let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) {
            alarms = decodedAlarms
        }

        if let decodedTodos = try? JSONDecoder().decode([TodoItem].self, from: savedTodos) {
            todos = decodedTodos
        }
    }

    // MARK: Persistence

    private func persistAlarms(_ alarms: [AlarmItem]) {

        if let encoded = try? JSONEncoder().encode(alarms) {
            savedAlarms = encoded
        }

        NotificationManager.shared.refreshNotifications(for: alarms)
    }

    private func persistTodos(_ todos: [TodoItem]) {

        if let encoded = try? JSONEncoder().encode(todos) {
            savedTodos = encoded
        }
    }
}

private struct LocalActiveTimerCard: View {
    let item: AlarmItem
    let now: Date

    private var remaining: TimeInterval {
        max(item.end.timeIntervalSince(now), 0)
    }

    private var total: TimeInterval {
        max(item.end.timeIntervalSince(item.start), 1)
    }

    private var progress: CGFloat {
        CGFloat(1 - (remaining / total))
    }

    private var timeRemainingText: String {
        let seconds = Int(remaining)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("NOW")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .red]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text(item.className)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(timeRemainingText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: 220, height: 220)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LocalNextUpSummaryCard: View {
    let item: AlarmItem
    let now: Date

    private var timeText: String {
        let seconds = max(Int(item.start.timeIntervalSince(now)), 0)
        return "Starts in \(seconds / 60)m"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("NEXT UP")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(item.className)
                .font(.headline)

            Text(timeText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
    }
}
