import Foundation

enum StatsRange: String, CaseIterable {
    case week = "周", month = "月"
}

struct StatsPeriod {
    var date: Date
    var range: StatsRange
    var calendar: Calendar = .current
    var start: Date { range == .week ? CalendarDates.weekStart(date, calendar: calendar) : CalendarDates.monthStart(date, calendar: calendar) }
    var end: Date { calendar.date(byAdding: range == .week ? .weekOfYear : .month, value: 1, to: start)! }
    var days: [Date] {
        let count = calendar.dateComponents([.day], from: start, to: end).day!
        return (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    func contains(_ date: Date) -> Bool { date >= start && date < end }
    func shifted(_ amount: Int) -> Date { calendar.date(byAdding: range == .week ? .weekOfYear : .month, value: amount, to: date)! }
    var title: String {
        if range == .month { return start.formatted(.dateTime.year().month(.wide)) }
        return start.formatted(.dateTime.year().month().day()) + " — " + days.last!.formatted(.dateTime.year().month().day())
    }
}

struct StatsDay: Identifiable {
    var date: Date
    var seconds: Double
    var keys: Int
    var clicks: Int
    var id: Date { date }
    var minutes: Double { seconds / 60 }
    var actions: Int { keys + clicks }
}

struct StatsSummary {
    var days: [StatsDay]
    var sessions: Int
    var diaryDays: Int
    var characters: Int
    var completedTasks: Int
    var habitDays: Int
    var habitCompletions: Int
    var seconds: Double { days.reduce(0) { $0 + $1.seconds } }
    var keys: Int { days.reduce(0) { $0 + $1.keys } }
    var clicks: Int { days.reduce(0) { $0 + $1.clicks } }
    var actions: Int { keys + clicks }
    init(data: AppData, period: StatsPeriod) {
        let entries = data.sessions.filter { period.contains($0.date) }
        var focused: [String: Double] = [:]
        for entry in entries { focused[CalendarDates.key(entry.date, calendar: period.calendar), default: 0] += entry.seconds }
        days = period.days.map { day in
            let key = CalendarDates.key(day, calendar: period.calendar)
            return StatsDay(date: day, seconds: focused[key, default: 0], keys: data.keys[key, default: 0], clicks: data.mouseClicks?[key] ?? 0)
        }
        let keys = Set(period.days.map { CalendarDates.key($0, calendar: period.calendar) })
        let diaries = data.diaries.filter { keys.contains($0.key) && !$0.value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        sessions = entries.count
        diaryDays = diaries.count
        characters = diaries.values.reduce(0) { $0 + $1.characters }
        completedTasks = data.tasks.filter { $0.completedAt.map(period.contains) ?? false }.count
        habitDays = data.habitDays.intersection(keys).count
        habitCompletions = data.habits.reduce(0) { $0 + $1.days.intersection(keys).count }
    }
}
