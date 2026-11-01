import Foundation

enum StatsRange: String, CaseIterable {
    case week = "周", month = "月", year = "年"
}

struct StatsPeriod {
    var date: Date
    var range: StatsRange
    var calendar: Calendar = CalendarDates.defaultCalendar
    var rolloverMinutes = 0
    var boundary: DayBoundary { DayBoundary(timeZoneID: calendar.timeZone.identifier, rolloverMinutes: rolloverMinutes, firstWeekday: calendar.firstWeekday) }
    var interval: DateInterval { DateInterval(start: boundary.start(of: start), end: boundary.start(of: end)) }
    private var component: Calendar.Component { range == .week ? .weekOfYear : (range == .month ? .month : .year) }
    var start: Date {
        if range == .week { return CalendarDates.weekStart(date, calendar: calendar) }
        if range == .month { return CalendarDates.monthStart(date, calendar: calendar) }
        return calendar.date(from: calendar.dateComponents([.year], from: date))!
    }
    var end: Date { calendar.date(byAdding: component, value: 1, to: start)! }
    var days: [Date] {
        let count = calendar.dateComponents([.day], from: start, to: end).day!
        return (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    func contains(_ date: Date) -> Bool { date >= interval.start && date < interval.end }
    func shifted(_ amount: Int) -> Date { calendar.date(byAdding: component, value: amount, to: date)! }
    var title: String {
        if range == .year { return "\(calendar.component(.year, from: start))年" }
        if range == .month { return String(format: "%04d年%d月", calendar.component(.year, from: start), calendar.component(.month, from: start)) }
        return CalendarDates.key(start, calendar: calendar) + " — " + CalendarDates.key(days.last!, calendar: calendar)
    }
}

struct StatsDay: Identifiable {
    var date: Date
    var seconds: Double
    var restSeconds: Double = 0
    var pausedSeconds: Double = 0
    var keys: Int
    var clicks: Int
    var id: Date { date }
    var minutes: Double { seconds / 60 }
    var actions: Int { keys + clicks }
}

struct StatsSummary {
    var days: [StatsDay]
    var sessions: Int
    var restSessions: Int
    var diaryDays: Int
    var characters: Int
    var completedTasks: Int
    var habitDays: Int
    var habitCompletions: Int
    var seconds: Double { days.reduce(0) { $0 + $1.seconds } }
    var restSeconds: Double { days.reduce(0) { $0 + $1.restSeconds } }
    var pausedSeconds: Double { days.reduce(0) { $0 + $1.pausedSeconds } }
    var keys: Int { days.reduce(0) { $0 + $1.keys } }
    var clicks: Int { days.reduce(0) { $0 + $1.clicks } }
    var actions: Int { keys + clicks }
    init(data: AppData, period: StatsPeriod) {
        let interval = period.interval
        let entries = data.sessions.filter { $0.recordedSeconds(in: interval) > 0 }
        days = period.days.map { day in
            let key = CalendarDates.key(day, calendar: period.calendar)
            let span = period.boundary.interval(forDay: day)
            let start = span.start, end = span.end
            let focused = entries.filter { $0.kind != .rest }.reduce(0) { $0 + $1.recordedSeconds(in: span) }
            let rested = entries.filter { $0.kind == .rest }.reduce(0) { $0 + $1.recordedSeconds(in: span) }
            let paused = data.sessions.flatMap { $0.pauseIntervals ?? [] }.reduce(0.0) { total, pause in
                total + max(0, min(pause.endedAt, end).timeIntervalSince(max(pause.beganAt, start)))
            }
            return StatsDay(date: day, seconds: focused, restSeconds: rested, pausedSeconds: paused, keys: data.keys[key, default: 0], clicks: data.mouseClicks?[key] ?? 0)
        }
        let keys = Set(period.days.map { CalendarDates.key($0, calendar: period.calendar) })
        let diaries = data.diaries.filter { keys.contains($0.key) && !$0.value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        sessions = entries.filter { $0.kind != .rest }.count
        restSessions = entries.filter { $0.kind == .rest }.count
        diaryDays = diaries.count
        characters = diaries.values.reduce(0) { $0 + $1.characters }
        completedTasks = data.taskCompletionRecords.filter { period.contains($0.completedAt) }.count
        habitDays = data.habitDays.intersection(keys).count
        habitCompletions = data.habits.reduce(0) { $0 + $1.days.intersection(keys).count }
    }
}

struct StatsMonth: Identifiable {
    var date: Date
    var summary: StatsSummary
    var id: Date { date }
    static func months(data: AppData, year: StatsPeriod) -> [StatsMonth] {
        (0..<12).map { offset in
            let date = year.calendar.date(byAdding: .month, value: offset, to: year.start)!
            return StatsMonth(date: date, summary: StatsSummary(data: data, period: StatsPeriod(date: date, range: .month, calendar: year.calendar, rolloverMinutes: year.rolloverMinutes)))
        }
    }
}
