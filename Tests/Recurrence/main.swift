import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
calendar.firstWeekday = 2
func date(_ y: Int = 2030, _ m: Int = 1, _ d: Int, _ hour: Int = 0) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))! }
func key(_ date: Date) -> String { CalendarDates.key(date, calendar: calendar) }
func revision(_ rule: RepeatRule, anchor: Date = date(2030,1,1), effective: Date? = nil) -> ScheduleRevision { ScheduleRevision(effectiveFrom: key(effective ?? anchor), anchor: key(anchor), rule: rule, firstWeekday: 2) }
let everyThree = revision(RepeatRule(every: 3))
assert(everyThree.occurs(on:date(2030,1,1),calendar:calendar) && everyThree.occurs(on:date(2030,1,4),calendar:calendar))
assert(!everyThree.occurs(on:date(2030,1,3),calendar:calendar))
let weekly = revision(RepeatRule(unit:.week,every:2,weekdays:[2,4,7]))
assert(weekly.occurs(on:date(2030,1,2),calendar:calendar))
assert(weekly.occurs(on:date(2030,1,5),calendar:calendar))
assert(!weekly.occurs(on:date(2030,1,7),calendar:calendar))
assert(weekly.occurs(on:date(2030,1,14),calendar:calendar))
var sunday = calendar; sunday.firstWeekday = 1
assert(weekly.occurs(on:date(2030,1,14),calendar:sunday))
let monthly = revision(RepeatRule(unit:.month),anchor:date(2030,1,31))
assert(monthly.occurs(on:date(2030,2,28),calendar:calendar) && monthly.occurs(on:date(2030,3,31),calendar:calendar))
assert(!monthly.occurs(on:date(2030,3,28),calendar:calendar))
let leap = revision(RepeatRule(unit:.month),anchor:date(2032,1,31))
assert(leap.occurs(on:date(2032,2,29),calendar:calendar))
let cycle = revision(RepeatRule(unit:.cycle,cycleLength:7,activeDays:[0,2,3,6]))
for offset in 0..<28 {
    let day = calendar.date(byAdding:.day,value:offset,to:date(2030,1,1))!
    assert(cycle.occurs(on:day,calendar:calendar) == [0,2,3,6].contains(offset%7))
}
let spring = revision(RepeatRule(every:2),anchor:date(2026,3,7))
assert(spring.occurs(on:date(2026,3,9),calendar:calendar))
let oldWeekly = revision(RepeatRule(unit: .week, weekdays: [2, 3, 4, 5, 6, 7]))
let cycleFromTomorrow = Recurrence.revised([oldWeekly], rule: .workRest(active: 14, rest: 1), anchor: date(2030,1,5), effective: date(2030,1,5), calendar: calendar)
assert(Recurrence.revision(cycleFromTomorrow, on: date(2030,1,4), calendar: calendar) == oldWeekly)
assert(Recurrence.nextRevision(cycleFromTomorrow, after: date(2030,1,4), calendar: calendar)?.rule == .workRest(active: 14, rest: 1))
assert(Recurrence.nextRevision(cycleFromTomorrow, after: date(2030,1,4), calendar: calendar)?.effectiveFrom == "2030-01-05")
assert(Recurrence.revision(cycleFromTomorrow, on: date(2030,1,5), calendar: calendar)?.rule == .workRest(active: 14, rest: 1))
assert(Recurrence.nextRevision(cycleFromTomorrow, after: date(2030,1,5), calendar: calendar) == nil)
var data = AppData()
var task = GardenTask(title:"整理",scheduleRevisions:[everyThree])
data.tasks = [task]
var occurrences = data.taskOccurrences(from:date(2030,1,1),through:date(2030,1,10),calendar:calendar)
assert(occurrences.map(\.scheduledDay) == ["2030-01-01","2030-01-04","2030-01-07","2030-01-10"])
let first = occurrences[0]
data.recurringTaskCompletions = [TaskCompletionRecord(id:first.id,taskID:task.id,title:task.title,scheduledDay:first.scheduledDay,completedAt:date(2030,1,2))]
occurrences = data.taskOccurrences(from:date(2030,1,1),through:date(2030,1,10),calendar:calendar)
assert(occurrences[0].completedAt == date(2030,1,2) && occurrences[1].completedAt == nil && occurrences[2].completedAt == nil)
let revised = Recurrence.revised(task.scheduleRevisions,rule:RepeatRule(every:2),anchor:date(2030,1,8),effective:date(2030,1,8),calendar:calendar)
data.tasks[0].scheduleRevisions = revised
assert(data.taskOccurrences(from:date(2030,1,1),through:date(2030,1,7),calendar:calendar).map(\.scheduledDay) == ["2030-01-01","2030-01-04","2030-01-07"])
assert(data.taskCompletionRecords.count == 1)
data.tasks.removeAll(); assert(data.taskCompletionRecords.count == 1)
print("PASS: calendar intervals, multiple weekdays, month-end restoration, leap days, DST, arbitrary cycle masks, unchanged old occurrences and independent completion history")

var library = ReminderTextLibrary(texts:["甲", "乙", "丙", "  ", "甲"])
assert(library.phrases.count == 3)
var last: UUID?
for _ in 0..<30 {
    var round: Set<UUID> = []
    for _ in 0..<3 {
        let next = library.draw()!
        assert(next.id != last && round.insert(next.id).inserted)
        last = next.id
    }
    assert(round.count == 3)
}
var large = ReminderTextLibrary(texts:(0..<1200).map { "语句\($0)" })
assert(Set((0..<1200).map { _ in large.draw()!.id }).count == 1200)
var reminders = AppData()
let habit = Habit(title:"阅读",reminderMinutes:8*60,scheduleRevisions:[revision(RepeatRule())],messageLibrary:ReminderTextLibrary(texts:["甲","乙","丙"]))
reminders.habits = [habit]
let planned = reminders.planReminders(at:date(2030,1,1),calendar:calendar,horizonDays:9)
assert(planned.count == 9 && reminders.habits[0].messageLibrary!.used.isEmpty)
for start in stride(from:0,to:9,by:3) { assert(Set(planned[start..<start+3].compactMap(\.phraseID)).count == 3) }
let again = reminders.planReminders(at:date(2030,1,1),calendar:calendar,horizonDays:9)
assert(planned == again && reminders.habits[0].messageLibrary!.used.isEmpty)
reminders.reminderAssignments![0].registered = true
let advanced = reminders.planReminders(at:date(2030,1,2),calendar:calendar,horizonDays:8)
assert(advanced.map(\.phraseID) == Array(planned.dropFirst()).map(\.phraseID))
assert(reminders.habits[0].messageLibrary!.used.count == 1)
_ = reminders.planReminders(at:date(2030,1,2),calendar:calendar,horizonDays:8)
assert(reminders.habits[0].messageLibrary!.used.count == 1)
reminders.habits[0].checkIns = ["2030-01-02":HabitCheckIn(text:"书页",image:nil,submittedAt:date(2030,1,2))]
let canceled = reminders.planReminders(at:date(2030,1,2),calendar:calendar,horizonDays:8)
assert(canceled.count == 7 && Set(canceled.prefix(2).compactMap(\.phraseID) + [planned[0].phraseID!]).count == 3)
print("PASS: unbounded phrase counts, blank/duplicate normalization, random bags, no boundary repeat, stable future reservations, single consumption and canceled-slot release")

var old = AppData(); old.version = 2
old.habits = [Habit(title:"旧习惯",days:["2029-12-31"],encouragement:"继续")]
let migrated = try old.validated(at:date(2030,1,1))
assert(migrated.version == 4 && migrated.habits[0].days == old.habits[0].days)
assert(migrated.habits[0].messageLibrary!.phrases.map(\.text) == ["继续"])
assert(!migrated.habits[0].isScheduled(on:date(2029,12,30),calendar:calendar))
let reopened = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(migrated)).validated(at:date(2030,1,2))
assert(reopened.habits == migrated.habits)
var invalid = migrated; invalid.habits[0].scheduleRevisions![0].rule!.cycleLength = 0
assert((try? invalid.validated()) == nil)
print("PASS: legacy habit migration, retained dates, phrase migration, no invented missed history, restart idempotence and rule validation")

var restHabit = Habit(title:"练习", days:["2030-01-01","2030-01-03","2030-01-04"], scheduleRevisions:[cycle])
assert(restHabit.streak(at:date(2030,1,5),calendar:calendar) == 3)
restHabit.days.remove("2030-01-03")
assert(restHabit.streak(at:date(2030,1,5),calendar:calendar) == 1)
print("PASS: planned streaks skip rest days while missed execution days break the sequence")

var sharedIDs = AppData()
var sameIDTask = GardenTask(title:"任务",due:date(2030,1,1),reminderMinutes:10*60,messageLibrary:ReminderTextLibrary(texts:["任务文字"]))
sameIDTask.id = habit.id
sharedIDs.habits = [habit]; sharedIDs.tasks = [sameIDTask]
let sharedPlan = sharedIDs.planReminders(at:date(2030,1,1),calendar:calendar,horizonDays:1)
assert(sharedPlan.first { !$0.isHabit }?.text == "任务文字")
assert(sharedPlan.first { $0.isHabit }?.text != "任务文字")
var malformed = AppData()
malformed.recurringTaskCompletions = [TaskCompletionRecord(id:sameIDTask.id.uuidString,taskID:sameIDTask.id,title:"任务",scheduledDay:nil,completedAt:date(2030,1,1))]
assert((try? malformed.validated()) == nil)
print("PASS: task/habit libraries stay independent across shared identifiers and malformed completion-ledger entries are rejected")

var replanned = AppData()
let series = GardenTask(title: "每日阅读", scheduleRevisions: [ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule())], reminderMinutes: 10*60)
replanned.tasks = [series]
let originalOccurrence = replanned.taskOccurrences(from: date(2030,1,1), through: date(2030,1,1), calendar: calendar)[0]
let reflection = FocusSession(id: UUID(), taskID: series.id, title: series.title, kind: .stopwatch, date: date(2030,1,1), seconds: 60, occurrenceID: originalOccurrence.id)
replanned.sessions = [reflection]
assert(replanned.editFocusSession(reflection.id, title: "读第一节", notes: "明天继续", mood: nil, moodSymbol: nil, moodImage: nil, taskAction: .reschedule, rescheduleDate: date(2030,1,3), at: date(2030,1,1), calendar: calendar))
assert(replanned.tasks == [series] && replanned.taskCompletionRecords.isEmpty)
assert(replanned.taskOccurrences(from: date(2030,1,1), through: date(2030,1,1), calendar: calendar).isEmpty)
let moved = replanned.taskOccurrences(from: date(2030,1,3), through: date(2030,1,3), calendar: calendar)
assert(moved.count == 2 && Set(moved.map(\.id)).count == 2)
assert(moved.first { $0.id == originalOccurrence.id }?.displayDay == "2030-01-03")
assert(moved.first { $0.id == originalOccurrence.id }?.scheduledDay == "2030-01-01")
let futurePlan = replanned.planReminders(at: date(2030,1,1), calendar: calendar, horizonDays: 4)
assert(futurePlan.first { $0.id == "task-" + originalOccurrence.id }?.fireAt == calendar.date(bySettingHour:10,minute:0,second:0,of:date(2030,1,3)))
assert(replanned.editFocusSession(reflection.id, title: "读第一节", notes: "补完", mood: nil, moodSymbol: nil, moodImage: nil, taskAction: .complete, at: date(2030,1,3), calendar: calendar))
assert(replanned.taskCompletionRecords.count == 1 && replanned.taskCompletionRecords[0].id == originalOccurrence.id && replanned.taskCompletionRecords[0].scheduledDay == "2030-01-01")
assert(replanned.taskOccurrences(from:date(2030,1,3),through:date(2030,1,3),calendar:calendar).filter { $0.completedAt == nil }.count == 1)
let movedReload = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(replanned)).validated(at:date(2030,1,3))
assert(movedReload.taskOccurrenceReschedules == replanned.taskOccurrenceReschedules && movedReload.taskCompletionRecords == replanned.taskCompletionRecords)
var archivePlan = AppData()
archivePlan.habits = [Habit(title:"归档",reminderMinutes:600,archivedAt:date(2030,1,1))]
assert(archivePlan.planReminders(at:date(2030,1,1),calendar:calendar).isEmpty)
assert(!archivePlan.habits[0].isScheduled(on:date(2030,1,2),calendar:calendar))
var longLibrary = ReminderTextLibrary(texts:[String(repeating:"长",count:4000)])
assert(longLibrary.isValid && longLibrary.phrases[0].text.count == 4000)
longLibrary.phrases[0].text += "长"; longLibrary.normalize()
assert(!longLibrary.isValid && longLibrary.phrases[0].text.count == 4001)
print("PASS: occurrence-only rescheduling preserves identity, history and series; reminders follow moved dates; archives and long-phrase bounds are validated")
