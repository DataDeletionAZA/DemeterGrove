import Foundation

enum CalendarDates {
    static func monthStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
    static func weekStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let offset = (calendar.component(.weekday, from: date) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date))!
    }
    static func days(in date: Date, week: Bool, calendar: Calendar = .current) -> [Date?] {
        let start = week ? weekStart(date, calendar: calendar) : monthStart(date, calendar: calendar)
        let offset = week ? 0 : (calendar.component(.weekday, from: start) + 5) % 7
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
