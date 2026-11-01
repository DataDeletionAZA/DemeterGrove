import Foundation

let iso = ISO8601DateFormatter()
func instant(_ value: String) -> Date { iso.date(from: value)! }
let shanghai = DayBoundary(timeZoneID: "Asia/Shanghai", rolloverMinutes: 240)
let ny = DayBoundary(timeZoneID: "America/New_York", rolloverMinutes: 240)
func day(_ key: String, _ boundary: DayBoundary = shanghai) -> Date { Recurrence.date(key, calendar: boundary.calendar)! }
assert(shanghai.key(for: instant("2030-01-02T19:59:59Z")) == "2030-01-02")
assert(shanghai.key(for: instant("2030-01-02T20:00:00Z")) == "2030-01-03")
assert(shanghai.key(for: instant("2030-01-02T18:00:00Z")) == "2030-01-02")
assert(ny.key(for: instant("2030-01-03T08:59:59Z")) == "2030-01-02")
assert(ny.key(for: instant("2030-01-03T09:00:00Z")) == "2030-01-03")
assert(ny.interval(forDay: day("2026-03-07", ny)).duration == 23 * 3600)
assert(ny.interval(forDay: day("2026-10-31", ny)).duration == 25 * 3600)
let skipped = DayBoundary(timeZoneID: "America/New_York", rolloverMinutes: 150)
assert(skipped.start(of: day("2026-03-08", skipped)) == instant("2026-03-08T07:00:00Z"))
let repeated = DayBoundary(timeZoneID: "America/New_York", rolloverMinutes: 90)
assert(repeated.start(of: day("2026-11-01", repeated)) == instant("2026-11-01T05:30:00Z"))
assert(repeated.key(for: instant("2026-11-01T06:15:00Z")) == "2026-11-01")
assert(shanghai.time(onDay: day("2030-01-02"), minutes: 120) == instant("2030-01-02T18:00:00Z"))
assert(shanghai.timestamp(instant("2030-01-02T18:00:00Z")).contains("2030-01-03 02:00"))
assert(!DayBoundary(timeZoneID: "invalid").isValid && !DayBoundary(rolloverMinutes: 1440).isValid)
assert(DayBoundary().calendar.timeZone == TimeZone.current)

let cycle = RepeatRule.workRest(active: 14, rest: 1)
assert(cycle.isValid && cycle.cycleLength == 15 && cycle.activeDays == Set(0..<14))
assert(cycle.summary.contains("连续执行 14 天，再休息 1 天"))
let revision = ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: cycle)
for offset in 0..<46 {
    let date = shanghai.calendar.date(byAdding: .day, value: offset, to: day("2030-01-01"))!
    assert(revision.occurs(on: date, calendar: shanghai.calendar) == (offset % 15 < 14))
}
assert(!ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule(every: 14)).occurs(on: day("2030-01-02"), calendar: shanghai.calendar))
let arbitrary = RepeatRule(unit: .cycle, cycleLength: 17, activeDays: [0, 2, 8, 16])
assert(arbitrary.isValid && arbitrary.continuousActiveDays == nil)
assert(RepeatRule.workRest(active: 3, rest: 0).isValid)

var data = AppData()
data.preferences.dayTimeZoneID = "Asia/Shanghai"
data.preferences.dayRolloverMinutes = 240
let now = instant("2030-01-02T18:00:00Z")
let habit = Habit(title: "阅读", scheduleRevisions: [ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule())])
data.habits = [habit]
assert(data.submitHabitEvidence(habit.id, date: day("2030-01-02"), text: "读了三页", image: nil, now: now))
assert(data.habits[0].checkIns?["2030-01-02"] != nil)
assert(data.applyHabitReview(habit.id, day: "2030-01-02", approved: true, feedback: "好", now: now)?.coins == 1)
let balance = data.garden.coins
let originalDays = data.habits[0].days
let previousEnd = data.preferences.dayBoundary.interval(forDay: day("2030-01-02")).end
data.habitRewardNotBefore = previousEnd
data.preferences.dayRolloverMinutes = 0
assert(data.submitHabitEvidence(habit.id, date: day("2030-01-03"), text: "第二次", image: nil, now: now))
assert(data.applyHabitReview(habit.id, day: "2030-01-03", approved: true, feedback: "好", now: now)?.coins == 0)
assert(data.garden.coins == balance && originalDays.isSubset(of: data.habits[0].days))
data.diaries["2029-12-31"] = Diary(text: "旧日记")
data.keys["2029-12-31"] = 1234
data.mouseClicks = ["2029-12-31": 41]
let restored = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data)).validated(at: now)
assert(restored.diaries == data.diaries && restored.keys == data.keys && restored.mouseClicks == data.mouseClicks && restored.garden.coins == balance)
assert(restored.habitRewardNotBefore == previousEnd)
assert(!restored.preferences.dayBoundary.calendar.isDate(day("2030-01-02"), inSameDayAs: restored.preferences.dayBoundary.day(for: now)))

var milestones = AppData()
milestones.preferences.dayTimeZoneID = "Asia/Shanghai"
let priorDays = Set((1...6).map { String(format: "2029-12-%02d", $0) })
let milestoneHabit = Habit(title: "里程碑", days: priorDays)
milestones.habits = [milestoneHabit]
milestones.habitProgress = HabitProgress(days: priorDays, rewardedDays: priorDays)
milestones.habitRewardNotBefore = now.addingTimeInterval(3600)
assert(milestones.submitHabitEvidence(milestoneHabit.id, date: day("2030-01-03"), text: "记录", image: nil, now: now))
assert(milestones.applyHabitReview(milestoneHabit.id, day: "2030-01-03", approved: true, feedback: "好", now: now)?.milestones.isEmpty == true)
let tomorrow = now.addingTimeInterval(86400)
assert(milestones.submitHabitEvidence(milestoneHabit.id, date: day("2030-01-04"), text: "记录", image: nil, now: tomorrow))
assert(milestones.applyHabitReview(milestoneHabit.id, day: "2030-01-04", approved: true, feedback: "好", now: tomorrow)?.milestones == [7])

var statsData = AppData()
statsData.preferences = data.preferences
let began = instant("2030-01-02T19:30:00Z"), ended = instant("2030-01-02T20:30:00Z")
let run = TimerRun(kind: .stopwatch, target: 3600, taskTitle: "", startedAt: began, resumedAt: began, segments: [], pauseIntervals: [])
statsData.timer = run
_ = statsData.finishTimer(at: ended)
statsData.keys = ["2030-01-02": 50, "2030-01-03": 70]
statsData.mouseClicks = ["2030-01-02": 3]
let period = StatsPeriod(date: day("2030-01-02"), range: .month, calendar: shanghai.calendar, rolloverMinutes: 240)
let summary = StatsSummary(data: statsData, period: period)
assert(summary.days.first { CalendarDates.key($0.date, calendar: shanghai.calendar) == "2030-01-02" }!.seconds == 1800)
assert(summary.days.first { CalendarDates.key($0.date, calendar: shanghai.calendar) == "2030-01-03" }!.seconds == 1800)
assert(summary.keys == 120 && summary.clicks == 3)
assert(DailyRecords(date: day("2030-01-02"), calendar: shanghai.calendar, rolloverMinutes: 240).sessions(in: statsData).count == 1)
let appointment = Appointment(title: "凌晨约定", start: now, end: now.addingTimeInterval(1800))
statsData.events = [appointment]
assert(DailyRecords(date: day("2030-01-02"), calendar: shanghai.calendar, rolloverMinutes: 240).events(in: statsData)[0].start == now)
assert(DailyRecords(date: day("2030-01-03"), calendar: shanghai.calendar, rolloverMinutes: 240).events(in: statsData).isEmpty)

var reminders = AppData()
reminders.preferences.dayTimeZoneID = "Asia/Shanghai"
reminders.preferences.dayRolloverMinutes = 240
reminders.habits = [Habit(title: "凌晨提醒", reminderMinutes: 120, scheduleRevisions: [ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule())])]
let assignments = reminders.planReminders(at: instant("2030-01-02T17:00:00Z"), calendar: shanghai.calendar, horizonDays: 1)
assert(assignments.count == 1 && assignments[0].id.hasSuffix("2030-01-02") && assignments[0].fireAt == now)
let repeatedAssignments = reminders.planReminders(at: instant("2030-01-02T17:00:00Z"), calendar: shanghai.calendar, horizonDays: 1)
assert(repeatedAssignments == assignments)
print("PASS: named/system zones, custom rollover, DST gaps/folds, 14+1/arbitrary cycles, late-night review/rewards, history and balance preservation, focus/day grouping and recurring reminders")
