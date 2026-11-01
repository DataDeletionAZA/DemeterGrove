import Foundation

struct HabitDayRecord: Identifiable {
    var habit: Habit
    var day: String
    var id: UUID { habit.id }
    var entry: HabitCheckIn? { habit.checkIns?[day] }
    var completed: Bool { habit.days.contains(day) }
}

struct DailyRecords {
    var date: Date
    var calendar: Calendar
    var rolloverMinutes = 0
    private var boundary: DayBoundary { DayBoundary(timeZoneID: calendar.timeZone.identifier, rolloverMinutes: rolloverMinutes, firstWeekday: calendar.firstWeekday) }
    var interval: DateInterval {
        boundary.interval(forDay: date)
    }
    var key: String { CalendarDates.key(date, calendar: calendar) }
    func events(in data: AppData) -> [Appointment] {
        data.events.filter { event in
            event.start < interval.end && (event.end > interval.start || (event.start == event.end && event.start >= interval.start))
        }.sorted { $0.start < $1.start }
    }
    func tasks(in data: AppData) -> [TaskOccurrence] {
        data.taskOccurrences(from: date, through: date, calendar: calendar).filter { occurrence in
            if let scheduled = occurrence.displayDay { return scheduled == key }
            if let due = occurrence.task.due { return calendar.isDate(due, inSameDayAs: date) }
            return occurrence.completedAt.map { boundary.key(for: $0) == key } ?? false
        }
    }
    func habits(in data: AppData) -> [HabitDayRecord] {
        data.habits.compactMap { habit in
            guard habit.days.contains(key) || habit.checkIns?[key] != nil else { return nil }
            return HabitDayRecord(habit: habit, day: key)
        }
    }
    func sessions(in data: AppData) -> [FocusSession] {
        data.sessions.filter { $0.recordedSeconds(in: interval) > 0 || ($0.pauseIntervals ?? []).contains { $0.beganAt < interval.end && $0.endedAt > interval.start } }
            .sorted { ($0.beganAt ?? $0.date) < ($1.beganAt ?? $1.date) }
    }
}
