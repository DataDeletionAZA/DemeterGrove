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
    var dateStyle: Date.FormatStyle { Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone) }
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
        let dates = period.days
        let boundary = period.boundary
        let starts = dates.map { boundary.start(of: $0) } + [interval.end]
        let dayKeys = dates.map { CalendarDates.key($0, calendar: period.calendar) }
        var totals = zip(dates, dayKeys).map { day, key in
            StatsDay(date: day, seconds: 0, keys: data.keys[key, default: 0], clicks: data.mouseClicks?[key] ?? 0)
        }

        func dayIndex(for instant: Date) -> Int {
            var low = 0, high = dates.count
            while low < high {
                let mid = (low + high) / 2
                if starts[mid + 1] <= instant { low = mid + 1 } else { high = mid }
            }
            return low
        }
        func add(_ segment: FocusInterval, to field: WritableKeyPath<StatsDay, Double>) {
            let start = max(segment.beganAt, interval.start), end = min(segment.endedAt, interval.end)
            guard start < end else { return }
            var index = dayIndex(for: start)
            while index < totals.count && starts[index] < end {
                totals[index][keyPath: field] += min(end, starts[index + 1]).timeIntervalSince(max(start, starts[index]))
                index += 1
            }
        }
        sessions = 0
        restSessions = 0
        for entry in data.sessions {
            for pause in entry.pauseIntervals ?? [] { add(pause, to: \.pausedSeconds) }
            guard entry.recordedSeconds(in: interval) > 0 else { continue }
            let field: WritableKeyPath<StatsDay, Double> = entry.kind == .rest ? \.restSeconds : \.seconds
            if entry.kind == .rest { restSessions += 1 } else { sessions += 1 }
            if let segments = entry.segments {
                for segment in segments { add(segment, to: field) }
            } else {
                totals[dayIndex(for: entry.date)][keyPath: field] += entry.seconds
            }
        }
        days = totals
        let keys = Set(dayKeys)
        let diaries = data.diaries.filter { keys.contains($0.key) && !$0.value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        diaryDays = diaries.count
        characters = diaries.values.reduce(0) { $0 + $1.characters }
        completedTasks = data.taskCompletionRecords.filter { $0.completedAt >= interval.start && $0.completedAt < interval.end }.count
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
