import Foundation

enum HabitDayState: String {
    case completed = "已完成", pending = "待审核", needsMore = "待补充", empty = "未打卡", upcoming = "未到日期"
    static func value(for habit: Habit, on date: Date, today: Date, calendar: Calendar = .current) -> HabitDayState {
        let key = CalendarDates.key(date, calendar: calendar)
        if habit.days.contains(key) { return .completed }
        if let entry = habit.checkIns?[key] {
            switch entry.status { case .approved: return .completed; case .pending: return .pending; case .rejected: return .needsMore }
        }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: today) ? .upcoming : .empty
    }
}
