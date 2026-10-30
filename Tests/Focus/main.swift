import Foundation

var checks = 0
func check(_ value: Bool, _ name: String) { guard value else { fatalError("FAIL: \(name)") }; checks += 1 }
let start = Date(timeIntervalSince1970: 1_800_000_000)
func at(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }
var data = AppData()
data.timer = TimerRun(kind: .pomodoro, target: 600, taskTitle: "阅读", startedAt: start, resumedAt: start, segments: [], pauseIntervals: [])
data.timer!.pause(at: at(100))
check(data.timer!.accumulated == 100 && data.timer!.segments == [FocusInterval(beganAt: start, endedAt: at(100))], "first active segment")
data.timer!.pause(at: at(150))
data.timer!.resume(at: at(200))
data.timer!.pause(at: at(350))
data.timer!.resume(at: at(400))
check(data.timer!.historyIsValid && data.timer!.elapsed(at: at(900)) == 600, "timer tracks active time and caps target")
let result = data.finishTimer(at: at(900))!
let session = data.sessions[0]
check(result.seconds == 600 && result.water == 2 && data.pomodoroBreakReady == true, "focus rewards use active seconds")
check(session.beganAt == start && session.endedAt == at(750) && session.date == at(750), "late automatic finish uses actual target time")
check(session.pauseCount == 2 && session.pausedSeconds == 150 && session.wallSeconds == 750, "pause count duration and wall duration")
check(session.segments!.map(\.seconds) == [100, 150, 350] && session.pauseIntervals!.map(\.seconds) == [100, 50] && session.isValid, "nonoverlapping segments and pauses")
check(data.finishTimer(at: at(901)) == nil && data.sessions.count == 1, "finish is idempotent")
let water = data.garden.water, focus = data.totalFocus
let level = data.levelProgress
let restStart = at(1000)
data.timer = TimerRun(kind: .rest, target: 300, taskTitle: "休息", startedAt: restStart, resumedAt: restStart, segments: [], pauseIntervals: [])
data.timer!.pause(at: at(1100)); data.timer!.resume(at: at(1200))
let rest = data.finishTimer(at: at(1500))!
check(rest.rest && rest.seconds == 300 && rest.water == 0 && data.sessions.count == 2, "rest is saved as its own record")
check(data.sessions[1].pauseCount == 0 && data.sessions[1].pausedSeconds == 0 && data.sessions[1].kind == .rest && data.sessions[1].isValid, "rest has no focus pause count")
check(data.totalFocus == focus && data.garden.water == water && data.levelProgress.level == level.level && data.levelProgress.experience == level.experience, "rest has no focus water or experience")
var paused = TimerRun(kind: .stopwatch, target: 60, taskTitle: "写作", startedAt: start, resumedAt: start, segments: [], pauseIntervals: [])
paused.pause(at: at(20))
let pausedRecord = paused.record(endingAt: at(80))
check(pausedRecord.seconds == 20 && pausedRecord.pauseCount == 1 && pausedRecord.pausedSeconds == 60 && pausedRecord.endedAt == at(80), "finish while paused closes interval")
var legacy = TimerRun(kind: .stopwatch, target: 60, taskTitle: "旧计时", startedAt: start, resumedAt: start)
legacy.pause(at: at(20)); legacy.resume(at: at(30))
check(legacy.historyIsValid && legacy.record(endingAt: at(50)).segments == nil && legacy.record(endingAt: at(50)).pauseCount == nil, "legacy timer detail remains unknown")
var clockChange = TimerRun(kind: .stopwatch, target: 60, taskTitle: "时钟变化", startedAt: start, resumedAt: start, segments: [], pauseIntervals: [])
clockChange.pause(at: at(20)); clockChange.resume(at: at(40)); clockChange.pause(at: at(30))
check(clockChange.historyIsValid && clockChange.pausedAt == at(40) && clockChange.record(endingAt:at(35)).isValid, "clock reversal cannot create overlapping pause intervals")
let oldSession = FocusSession(id: UUID(), title: "旧记录", kind: .stopwatch, date: start, seconds: 120)
let decoded = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(oldSession))
check(decoded == oldSession && decoded.beganAt == nil && decoded.endedAt == nil && decoded.pauseCount == nil && decoded.isValid, "old record optional fields migrate without inventing detail")
var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let midnight = calendar.date(from: DateComponents(year: 2030, month: 1, day: 2))!
let cross = FocusSession(id: UUID(), title: "跨日", kind: .stopwatch, date: midnight.addingTimeInterval(120), seconds: 180,
                         beganAt: midnight.addingTimeInterval(-120), endedAt: midnight.addingTimeInterval(120),
                         segments: [FocusInterval(beganAt: midnight.addingTimeInterval(-120), endedAt: midnight.addingTimeInterval(-30)), FocusInterval(beganAt: midnight.addingTimeInterval(30), endedAt: midnight.addingTimeInterval(120))],
                         pauseIntervals: [FocusInterval(beganAt: midnight.addingTimeInterval(-30), endedAt: midnight.addingTimeInterval(30))])
check(cross.isValid && cross.focusSeconds(in: DateInterval(start: midnight.addingTimeInterval(-86400), end: midnight)) == 90 && cross.focusSeconds(in: DateInterval(start: midnight, duration: 86400)) == 90, "cross-midnight focus follows actual segments")
var broken = cross; broken.segments![1].beganAt = midnight.addingTimeInterval(-40)
check(!broken.isValid, "overlapping incorrect segment time is refused")
broken = cross; broken.pauseIntervals![0].beganAt = midnight.addingTimeInterval(-50)
check(!broken.isValid, "pause and focus cannot overlap")
var restCopy = cross; restCopy.kind = .rest; restCopy.pauseIntervals = []
check(restCopy.focusSeconds(in: DateInterval(start: midnight, duration: 86400)) == 0 && restCopy.recordedSeconds(in: DateInterval(start: midnight, duration: 86400)) == 90, "rest display retains timing without focus aggregation")
var edit = AppData(); edit.sessions = [session]
let beforeTotal = edit.totalFocus, beforeWater = edit.garden.water
check(edit.editFocusSession(session.id, title: "改名", notes: "读了三节", mood: "满足", moodSymbol: "content", moodImage: nil, at: at(2000)), "edit reflection")
check(edit.totalFocus == beforeTotal && edit.garden.water == beforeWater && edit.sessions[0].seconds == session.seconds && edit.sessions[0].segments == session.segments, "history edit never regrants rewards or changes timing")
edit.sessions[0].aiFeedback = "回顾"; edit.sessions[0].aiReviewedAt = at(2100)
check(edit.editFocusSession(session.id, title: "再次改名", notes: "加了感想", mood: "满足", moodSymbol: "content", moodImage: nil, at: at(2200)) && edit.sessions[0].aiFeedback == "回顾" && edit.sessions[0].aiFeedbackIsEarlierVersion, "reflection edit retains earlier AI feedback")
var invalid = edit; invalid.sessions[0].notes = String(repeating: "字", count: 20_001)
do { _ = try invalid.validated(); fatalError("Oversize note accepted") } catch { checks += 1 }
let temp = FileManager.default.temporaryDirectory.appendingPathComponent("focus-records-\(UUID().uuidString).json")
defer { try? FileManager.default.removeItem(at: temp) }
try SaveFile.write(data, to: temp)
let restored = try SaveFile.read(temp)
check(restored.sessions == data.sessions && restored.totalFocus == data.totalFocus && restored.garden.water == data.garden.water && restored.version == 4, "new records save reload with version four")
print("PASS: \(checks) focus timing, pause, rest, cross-day, legacy, edit and persistence checks")

var legacyV3 = AppData(); legacyV3.version = 3; legacyV3.savedAt = at(100)
let legacyDay = dayKey(start)
let legacyRevision = ScheduleRevision(effectiveFrom: legacyDay, anchor: legacyDay, rule: RepeatRule())
legacyV3.tasks = [GardenTask(title:"旧任务",notes:"任务记录",due:start,messageLibrary:ReminderTextLibrary(texts:["继续一小步"]))]
legacyV3.events = [Appointment(title:"旧日程",start:start,end:at(60),notes:"日程记录")]
legacyV3.habits = [Habit(title:"旧习惯",days:[legacyDay],checkIns:[legacyDay:HabitCheckIn(text:"阅读摘记",image:nil,submittedAt:start,status:.approved,reviewedAt:at(1),feedback:"材料相关")],scheduleRevisions:[legacyRevision],messageLibrary:ReminderTextLibrary(texts:["读一点"]))]
legacyV3.habitProgress = HabitProgress(days:[legacyDay],rewardedDays:[legacyDay])
legacyV3.sessions = [oldSession]; legacyV3.diaries = [legacyDay:Diary(text:"当日记录",mood:"平静")]
legacyV3.keys = [legacyDay:1234];legacyV3.mouseClicks = [legacyDay:56]
legacyV3.timer = TimerRun(kind:.stopwatch,target:60,taskTitle:"旧暂停计时",startedAt:start,accumulated:10)
legacyV3.garden.coins = 87;legacyV3.garden.water = 9
legacyV3.garden.economy.owned.insert("travel");legacyV3.garden.economy.outfit = "travel"
let encoder = JSONEncoder();encoder.outputFormatting = [.sortedKeys]
try encoder.encode(legacyV3).write(to:temp)
let upgraded = try SaveFile.read(temp)
var expected = legacyV3;expected.version = 4
func migrationMatches(_ first: AppData, _ second: AppData) throws -> Bool {
    guard first.habits == second.habits, first.tasks == second.tasks, first.habitProgress == second.habitProgress,
          first.garden.economy.owned == second.garden.economy.owned else { return false }
    var first = first, second = second
    first.habits = []; second.habits = []; first.tasks = []; second.tasks = []
    first.habitProgress = nil; second.habitProgress = nil
    first.garden.economy.owned = []; second.garden.economy.owned = []
    let firstFields = try JSONSerialization.jsonObject(with: encoder.encode(first)) as! [String: Any]
    let secondFields = try JSONSerialization.jsonObject(with: encoder.encode(second)) as! [String: Any]
    return NSDictionary(dictionary: firstFields).isEqual(to: secondFields)
}
check(try migrationMatches(upgraded, expected), "version-three upgrade preserves all stored fields except format number")
check(upgraded.sessions[0].segments == nil && upgraded.sessions[0].pauseCount == nil && upgraded.habits[0].archivedAt == nil, "legacy timing stays unknown and habits stay active")
try SaveFile.write(upgraded,to:temp)
let upgradedAgain = try SaveFile.read(temp)
check(try migrationMatches(upgradedAgain, upgraded), "version-four migration is stable across write and read")
var futureVersion = upgraded;futureVersion.version = 5
check((try? futureVersion.validated()) == nil, "unknown future format is rejected")
print("PASS: version 3 to 4 migration preserves properties, counters, tasks, events, diaries, habit evidence, wardrobe and paused timers")
