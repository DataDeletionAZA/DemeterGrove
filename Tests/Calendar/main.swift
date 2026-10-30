import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.firstWeekday = 2
calendar.timeZone = TimeZone(identifier: "America/New_York")!
func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
let leap = CalendarDates.days(in: date(2024, 2, 15), week: false, calendar: calendar)
assert(leap.compactMap { $0 }.count == 29 && leap.count % 7 == 0)
assert(leap.prefix(3).allSatisfy { $0 == nil })
assert(CalendarDates.days(in: date(2026, 2, 1), week: false, calendar: calendar).compactMap { $0 }.count == 28)
let sixWeeks = CalendarDates.days(in: date(2021, 5, 15), week: false, calendar: calendar)
assert(sixWeeks.count == 42 && sixWeeks.compactMap { $0 }.count == 31)
let week = CalendarDates.days(in: date(2026, 1, 1), week: true, calendar: calendar).compactMap { $0 }
assert(week.count == 7 && calendar.component(.weekday, from: week[0]) == 2)
assert(calendar.isDate(week[0], inSameDayAs: date(2025, 12, 29)))
assert(calendar.isDate(week[6], inSameDayAs: date(2026, 1, 4)))
let replacement = CalendarDates.replacingDay(of: date(2026, 3, 7, 13, 37), with: date(2026, 3, 8), calendar: calendar)
assert(calendar.isDate(replacement, inSameDayAs: date(2026, 3, 8)))
assert(calendar.component(.hour, from: replacement) == 13 && calendar.component(.minute, from: replacement) == 37)
assert(CalendarDates.allowed(date(2026, 5, 10, 23), minimum: date(2026, 5, 10), maximum: date(2026, 5, 12), calendar: calendar))
assert(!CalendarDates.allowed(date(2026, 5, 9), minimum: date(2026, 5, 10), maximum: date(2026, 5, 12), calendar: calendar))
assert(!CalendarDates.allowed(date(2026, 5, 13), minimum: date(2026, 5, 10), maximum: date(2026, 5, 12), calendar: calendar))
assert(CalendarDates.allowed(date(2026, 5, 12, 23), minimum: nil, maximum: date(2026, 5, 12, 0), calendar: calendar))
assert(!CalendarDates.allowed(date(2026, 5, 13), minimum: nil, maximum: date(2026, 5, 12), calendar: calendar))
print("PASS: leap months, aligned weeks across years, day replacement across DST, preserved clock time, inclusive day bounds")

var sundayCalendar = calendar
sundayCalendar.firstWeekday = 1
let sundayWeek = CalendarDates.days(in:date(2026, 1, 1),week:true,calendar:sundayCalendar).compactMap { $0 }
assert(sundayCalendar.isDate(sundayWeek[0],inSameDayAs:date(2025, 12, 28)))
assert(sundayCalendar.isDate(sundayWeek[6],inSameDayAs:date(2026, 1, 3)))
assert(CalendarDates.days(in:date(2026, 2, 1),week:false,calendar:sundayCalendar)[0] != nil)
print("PASS: Monday and Sunday week boundaries and month grid alignment")
