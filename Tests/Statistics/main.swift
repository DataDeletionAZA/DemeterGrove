import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.firstWeekday = 2
calendar.timeZone = TimeZone(identifier: "America/New_York")!
func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
func key(_ value: Date) -> String { CalendarDates.key(value, calendar: calendar) }
let february = StatsPeriod(date: date(2030, 2, 15), range: .month, calendar: calendar)
assert(february.days.count == 28 && key(february.start) == "2030-02-01" && key(february.end) == "2030-03-01")
assert(february.contains(date(2030, 2, 1, 0)) && february.contains(date(2030, 2, 28, 23, 59)))
assert(!february.contains(date(2030, 1, 31, 23, 59)) && !february.contains(february.end))
assert(StatsPeriod(date: date(2032, 2, 15), range: .month, calendar: calendar).days.count == 29)
assert(key(february.shifted(1)) == "2030-03-15" && key(february.shifted(-1)) == "2030-01-15")
let newYear = StatsPeriod(date: date(2030, 1, 1), range: .week, calendar: calendar)
assert(key(newYear.start) == "2029-12-31" && key(newYear.end) == "2030-01-07" && newYear.days.count == 7)
assert(key(newYear.shifted(1)) == "2030-01-08")
let spring = StatsPeriod(date: date(2026, 3, 8), range: .week, calendar: calendar)
let autumn = StatsPeriod(date: date(2026, 11, 1), range: .week, calendar: calendar)
assert(spring.days.count == 7 && spring.end.timeIntervalSince(spring.start) == 167 * 3600)
assert(autumn.days.count == 7 && autumn.end.timeIntervalSince(autumn.start) == 169 * 3600)
assert(key(CalendarDates.replacingMonth(of: date(2030, 1, 31), year: 2030, month: 2, calendar: calendar)) == "2030-02-28")
assert(key(CalendarDates.replacingMonth(of: date(2030, 1, 31), year: 2032, month: 2, calendar: calendar)) == "2032-02-29")
assert(calendar.component(.hour, from: CalendarDates.replacingMonth(of: date(2030, 1, 31, 17, 42), year: 2030, month: 2, calendar: calendar)) == 17)

var data = AppData()
for (at, seconds) in [(date(2030, 1, 31, 23, 59), 600.0), (date(2030, 2, 1, 0), 180), (date(2030, 2, 5), 30), (date(2030, 2, 28, 23, 59), 120), (date(2030, 3, 1, 0), 900)] {
    data.sessions.append(FocusSession(id: UUID(), title: "阅读", kind: .stopwatch, date: at, seconds: seconds))
}
data.keys = [key(date(2030, 2, 1)):10, key(date(2030, 2, 28)):20, key(date(2030, 3, 1)):100, "unknown":999]
data.mouseClicks = [key(date(2030, 2, 5)):7, key(date(2030, 2, 28)):3, key(date(2030, 1, 31)):20]
data.diaries = [key(date(2030, 2, 1)):Diary(text:"今天 读书\n"), key(date(2030, 2, 2)):Diary(text:" \n "), key(date(2030, 2, 28)):Diary(text:"abc"), key(date(2030, 3, 1)):Diary(text:"下个月")]
data.tasks = [GardenTask(title:"甲", completedAt:date(2030, 2, 1)), GardenTask(title:"乙", completedAt:date(2030, 2, 28, 23, 59)), GardenTask(title:"丙", completedAt:date(2030, 3, 1)), GardenTask(title:"丁")]
data.habits = [Habit(title:"读书",days:[key(date(2030, 2, 1)), key(date(2030, 2, 5))]), Habit(title:"散步",days:[key(date(2030, 2, 5)), key(date(2030, 2, 28))])]
data.habitProgress = HabitProgress(days:[key(date(2030, 2, 10))])
let totalFocus = data.totalFocus, totalActions = data.totalActions
let summary = StatsSummary(data:data, period:february)
assert(summary.seconds == 330 && summary.sessions == 3 && summary.days.count == 28)
assert(summary.keys == 30 && summary.clicks == 10 && summary.actions == 40)
assert(summary.diaryDays == 2 && summary.characters == 7 && summary.completedTasks == 2)
assert(summary.habitDays == 4 && summary.habitCompletions == 4)
assert(summary.days.first!.seconds == 180 && summary.days.last!.seconds == 120)
assert(summary.days.first { key($0.date) == "2030-02-05" }?.minutes == 0.5)
assert(data.totalFocus == totalFocus && data.totalActions == totalActions)
let recurringID = UUID(), revisionID = UUID()
data.recurringTaskCompletions = [
    TaskCompletionRecord(id:recurringID.uuidString + "/" + revisionID.uuidString + "/2030-01-31",taskID:recurringID,title:"阅读",scheduledDay:"2030-01-31",completedAt:date(2030,2,3)),
    TaskCompletionRecord(id:recurringID.uuidString + "/" + revisionID.uuidString + "/2030-02-28",taskID:recurringID,title:"阅读",scheduledDay:"2030-02-28",completedAt:date(2030,3,1))
]
assert(StatsSummary(data:data,period:february).completedTasks == 3)
assert(StatsSummary(data:data,period:StatsPeriod(date:date(2030,3,1),range:.month,calendar:calendar)).completedTasks == 2)
let empty = StatsSummary(data:data, period:StatsPeriod(date:date(2035, 6, 15), range:.month, calendar:calendar))
assert(empty.days.count == 30 && empty.seconds == 0 && empty.actions == 0 && empty.diaryDays == 0 && empty.completedTasks == 0 && empty.habitDays == 0)
print("PASS: arbitrary future months/weeks, leap years, year boundaries, DST-length weeks, clamped month selection, half-open aggregation of focus/input/diaries/tasks/habits, empty future periods and preserved global totals")

let today = date(2030, 2, 15)
var habit = Habit(title:"阅读", days:[key(today)])
assert(HabitDayState.value(for:habit, on:today, today:today, calendar:calendar) == .completed)
habit.days = []
habit.checkIns = [key(today):HabitCheckIn(text:"书页", image:nil, submittedAt:today)]
assert(HabitDayState.value(for:habit, on:today, today:today, calendar:calendar) == .pending)
habit.checkIns?[key(today)]?.status = .rejected
assert(HabitDayState.value(for:habit, on:today, today:today, calendar:calendar) == .needsMore)
habit.checkIns = nil
assert(HabitDayState.value(for:habit, on:today, today:today, calendar:calendar) == .empty)
assert(HabitDayState.value(for:habit, on:date(2030, 2, 14), today:today, calendar:calendar) == .empty)
assert(HabitDayState.value(for:habit, on:date(2030, 2, 16), today:today, calendar:calendar) == .upcoming)
print("PASS: weekly habit card states distinguish completed, pending, rejected, missing and upcoming days")

let yearPeriod = StatsPeriod(date: date(2032, 8, 15), range: .year, calendar: calendar)
assert(yearPeriod.days.count == 366 && key(yearPeriod.start) == "2032-01-01" && key(yearPeriod.end) == "2033-01-01")
assert(key(yearPeriod.shifted(-1)) == "2031-08-15")
let midnight = date(2030, 2, 1, 0)
let beforeMidnight = midnight.addingTimeInterval(-600), afterMidnight = midnight.addingTimeInterval(900)
var crossing = AppData()
crossing.sessions = [
    FocusSession(id: UUID(), title: "跨日阅读", kind: .stopwatch, date: afterMidnight, seconds: 1200,
                 beganAt: beforeMidnight, endedAt: afterMidnight,
                 segments: [FocusInterval(beganAt: beforeMidnight, endedAt: midnight), FocusInterval(beganAt: midnight.addingTimeInterval(300), endedAt: afterMidnight)],
                 pauseIntervals: [FocusInterval(beganAt: midnight, endedAt: midnight.addingTimeInterval(300))]),
    FocusSession(id: UUID(), title: "休息", kind: .rest, date: afterMidnight, seconds: 600,
                 beganAt: midnight.addingTimeInterval(300), endedAt: afterMidnight,
                 segments: [FocusInterval(beganAt: midnight.addingTimeInterval(300), endedAt: afterMidnight)], pauseIntervals: [])
]
let januarySummary = StatsSummary(data: crossing, period: StatsPeriod(date: date(2030, 1, 31), range: .month, calendar: calendar))
let februarySummary = StatsSummary(data: crossing, period: february)
assert(januarySummary.seconds == 600 && januarySummary.sessions == 1 && januarySummary.restSeconds == 0)
assert(februarySummary.seconds == 600 && februarySummary.sessions == 1 && februarySummary.restSeconds == 600 && februarySummary.restSessions == 1 && februarySummary.pausedSeconds == 300)
let fullYear = StatsPeriod(date: date(2030, 2, 15), range: .year, calendar: calendar)
let months = StatsMonth.months(data: crossing, year: fullYear)
assert(months.count == 12 && months[0].summary.seconds == 600 && months[1].summary.seconds == 600)
assert(months.reduce(0) { $0 + $1.summary.seconds } == StatsSummary(data: crossing, period: fullYear).seconds)
let archivedDay = key(date(2030, 2, 5))
crossing.habits = [Habit(title: "归档阅读", days: [archivedDay], archivedAt: date(2030, 2, 10))]
assert(StatsSummary(data: crossing, period: february).habitCompletions == 1)
let febRecords = DailyRecords(date: midnight, calendar: calendar)
let janRecords = DailyRecords(date: beforeMidnight, calendar: calendar)
assert(febRecords.sessions(in: crossing).count == 2 && janRecords.sessions(in: crossing).count == 1)
crossing.events = [Appointment(title: "跨日", start: beforeMidnight, end: midnight), Appointment(title: "当天", start: midnight, end: afterMidnight)]
assert(febRecords.events(in: crossing).map(\.title) == ["当天"] && janRecords.events(in: crossing).map(\.title) == ["跨日"])
let habitRecords = DailyRecords(date: date(2030, 2, 5), calendar: calendar).habits(in: crossing)
assert(habitRecords.count == 1 && habitRecords[0].habit.archivedAt != nil)
let revision = ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule(), firstWeekday: 2)
let task = GardenTask(title: "每日阅读", scheduleRevisions: [revision])
crossing.tasks = [task]
assert(febRecords.tasks(in: crossing).count == 1)
let occurrence = febRecords.tasks(in: crossing)[0]
crossing.taskOccurrenceReschedules = [TaskOccurrenceReschedule(id: occurrence.id, taskID: task.id, scheduledDay: "2030-02-01", rescheduledDay: "2030-02-02", updatedAt: midnight)]
assert(febRecords.tasks(in: crossing).isEmpty)
assert(DailyRecords(date: date(2030, 2, 2), calendar: calendar).tasks(in: crossing).count == 2)
print("PASS: annual leap-year months, cross-midnight focus/rest/pause allocation, legacy focus compatibility, archived habit statistics, half-open appointments, unique-source daily records and recurring task rescheduling")
