import Foundation

enum CalendarDates {
    static var defaultCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    static func replacingMonth(of date: Date, year: Int, month: Int, calendar: Calendar = .current) -> Date {
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let day = min(calendar.component(.day, from: date), calendar.range(of: .day, in: .month, for: first)!.count)
        let target = calendar.date(byAdding: .day, value: day - 1, to: first)!
        return replacingDay(of: date, with: target, calendar: calendar)
    }
    static func monthStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
    static func weekStart(_ date: Date, calendar: Calendar = defaultCalendar) -> Date {
        let offset = (calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date))!
    }
    static func days(in date: Date, week: Bool, calendar: Calendar = defaultCalendar) -> [Date?] {
        let start = week ? weekStart(date, calendar: calendar) : monthStart(date, calendar: calendar)
        let offset = week ? 0 : (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let count = week ? 7 : calendar.range(of: .day, in: .month, for: date)!.count
        let slots = ((offset + count + 6) / 7) * 7
        return (0..<slots).map { index in
            guard index >= offset, index < offset + count else { return nil }
            return calendar.date(byAdding: .day, value: index - offset, to: start)!
        }
    }
    static func replacingDay(of value: Date, with day: Date, calendar: Calendar = .current) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: value)
        return calendar.date(bySettingHour: time.hour!, minute: time.minute!, second: time.second!, of: day)!
    }
    static func allowed(_ date: Date, minimum: Date?, maximum: Date?, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return (minimum.map { day >= calendar.startOfDay(for: $0) } ?? true)
            && (maximum.map { day <= calendar.startOfDay(for: $0) } ?? true)
    }
}


struct DayBoundary: Equatable {
    var timeZoneID: String? = nil
    var rolloverMinutes = 0
    var firstWeekday = 2
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        value.firstWeekday = firstWeekday
        return value
    }
    var isValid: Bool { (0..<1440).contains(rolloverMinutes) && (timeZoneID.map { TimeZone(identifier: $0) != nil } ?? true) }
    func start(of day: Date) -> Date {
        let midnight = calendar.startOfDay(for: day)
        if rolloverMinutes == 0 { return midnight }
        // A skipped clock time uses the first valid time; a repeated clock time uses its first occurrence.
        return calendar.nextDate(after: midnight.addingTimeInterval(-1), matching: DateComponents(hour: rolloverMinutes / 60, minute: rolloverMinutes % 60, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)!
    }
    func day(for instant: Date) -> Date {
        let civilDay = calendar.startOfDay(for: instant)
        return instant < start(of: civilDay) ? calendar.date(byAdding: .day, value: -1, to: civilDay)! : civilDay
    }
    func key(for instant: Date) -> String { CalendarDates.key(day(for: instant), calendar: calendar) }
    func interval(forDay day: Date) -> DateInterval {
        DateInterval(start: start(of: day), end: start(of: calendar.date(byAdding: .day, value: 1, to: day)!))
    }
    func time(onDay day: Date, minutes: Int) -> Date {
        let civilDay = calendar.date(byAdding: .day, value: minutes < rolloverMinutes ? 1 : 0, to: calendar.startOfDay(for: day))!
        return calendar.nextDate(after: civilDay.addingTimeInterval(-1), matching: DateComponents(hour: minutes / 60, minute: minutes % 60, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)!
    }
    func timestamp(_ instant: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
        return formatter.string(from: instant)
    }
    func dateText(_ day: Date) -> String { CalendarDates.key(day, calendar: calendar) }
}
