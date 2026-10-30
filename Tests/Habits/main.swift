import Foundation

let calendar = Calendar.current
let first = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: first)! }
func rejected(_ data: AppData) {
    do { _ = try data.validated(); fatalError("Invalid habit data accepted") } catch DataIssue.invalid { } catch { fatalError("Unexpected validation failure") }
}

let oldTask = GardenTask(title: "阅读", due: first)
let oldHabit = Habit(title: "读书", days: [dayKey(first)])
var old = AppData(); old.tasks = [oldTask]; old.habits = [oldHabit]
var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
oldJSON.removeValue(forKey: "habitProgress")
var oldTasks = oldJSON["tasks"] as! [[String: Any]]; oldTasks[0].removeValue(forKey: "category"); oldJSON["tasks"] = oldTasks
var oldHabits = oldJSON["habits"] as! [[String: Any]]
for key in ["reminderMinutes", "encouragement", "checkIns"] { oldHabits[0].removeValue(forKey: key) }
oldJSON["habits"] = oldHabits
let restored = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: oldJSON)).validated()
assert(restored.tasks[0].categoryName == "任务" && restored.tasks[0].due == first)
assert(restored.habits[0].days == oldHabit.days && restored.habitDays.count == 1 && restored.habitProgress == nil && restored.garden.coins == 0)

var data = AppData(); data.habits = [Habit(title: "读书"), Habit(title: "散步")]
let reader = data.habits[0].id, walker = data.habits[1].id
assert(!data.submitHabitEvidence(reader, date: day(-1), text: "书", image: nil, now: first))
assert(!data.submitHabitEvidence(reader, date: day(1), text: "书", image: nil, now: first))
assert(!data.submitHabitEvidence(reader, date: first, text: " \n ", image: nil, now: first))
assert(!data.submitHabitEvidence(reader, date: first, text: "书", image: Data(), now: first))
assert(!data.submitHabitEvidence(reader, date: first, text: String(repeating: "x", count: 4001), image: nil, now: first))
assert(data.submitHabitEvidence(reader, date: first, text: "今天读了三页", image: nil, now: first))
assert(data.garden.coins == 0 && data.habitDays.isEmpty)
assert(!data.cancelHabitSubmission(reader, date: first, now: day(1)))
assert(data.cancelHabitSubmission(reader, date: first, now: first))
assert(data.habits[0].checkIns?.isEmpty == true && data.garden.coins == 0)
assert(data.submitHabitEvidence(reader, date: first, text: "读书", image: nil, now: first))
assert(data.applyHabitReview(reader, day: dayKey(first), approved: true, feedback: "相关", now: day(1)) == nil)
let rejectedReview = data.applyHabitReview(reader, day: dayKey(first), approved: false, feedback: "请补充与读书有关的记录", now: first)!
assert(rejectedReview.coins == 0 && data.habitDays.isEmpty)
assert(data.submitHabitEvidence(reader, date: first, text: "我读完了第一章", image: nil, now: first))
assert(data.applyHabitReview(reader, day: dayKey(first), approved: true, feedback: "相关", now: first)?.coins == 1)
assert(data.applyHabitReview(reader, day: dayKey(first), approved: true, feedback: "相关", now: first) == nil)
assert(!data.submitHabitEvidence(reader, date: first, text: "再次提交", image: nil, now: first))
assert(data.submitHabitEvidence(walker, date: first, text: "在公园散步", image: nil, now: first))
assert(data.applyHabitReview(walker, day: dayKey(first), approved: true, feedback: "相关", now: first)?.coins == 0)
assert(data.habitDays.count == 1 && data.garden.coins == 1)

for offset in 1..<90 {
    let now = day(offset * 2)
    assert(data.submitHabitEvidence(reader, date: now, text: "阅读记录", image: nil, now: now))
    let result = data.applyHabitReview(reader, day: dayKey(now), approved: true, feedback: "与习惯有关", now: now)!
    assert(result.coins == 1)
    assert(result.milestones == (HabitProgress.milestones.contains(offset + 1) ? [offset + 1] : []))
}
assert(data.habitDays.count == 90 && data.garden.coins == 90)
assert(data.habitProgress?.rewardedDays.count == 90 && data.habitProgress?.milestones == Set([7, 30, 66, 90]))
assert(data.garden.cropSeeds[Crop.starlightCarrot.rawValue] == 3)
assert(data.garden.economy.owned.contains("travel") && data.garden.economy.owned.contains("winter"))
assert(data.garden.economy.finds["bloom"] == 1)
_ = try data.validated()
let beforePotion = data.garden.economy.finds["bloom"]
assert(!data.usePotion("bloom") && data.garden.economy.finds["bloom"] == beforePotion)
let plot = data.garden.plots[0].id
assert(data.plant(.starlightCarrot, in: plot))
assert(data.usePotion("bloom") && data.garden.economy.finds["bloom"] == 0)
data.sessions = [FocusSession(id: UUID(), title: "种植", kind: .stopwatch, date: first, seconds: 600)]
let beforeHarvest = data.garden.ingredients["胡萝卜", default: 0]
let yield = data.harvestYield
assert(data.harvest(plot) && data.garden.ingredients["胡萝卜"] == beforeHarvest + yield * 2)
assert(!data.buySeeds(.starlightCarrot) && !data.exchangeSeed(.starlightCarrot))
assert(Garden.distributeSeeds(1000)[Crop.starlightCarrot.rawValue] == nil)
_ = try data.validated()
let originalZone = NSTimeZone.default
NSTimeZone.default = TimeZone(secondsFromGMT: 14 * 3600)!
_ = try data.validated()
NSTimeZone.default = TimeZone(secondsFromGMT: -12 * 3600)!
_ = try data.validated()
NSTimeZone.default = originalZone
let roundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data)).validated()
assert(roundTrip.habitProgress == data.habitProgress && roundTrip.habits == data.habits)
data.removeHabit(reader); data.removeHabit(walker)
assert(data.habitDays.count == 90 && data.habitProgress?.rewardedDays.count == 90)

var legacy = AppData()
legacy.habits = [Habit(title: "旧习惯", days: Set((0..<66).map { dayKey(day($0)) }))]
let legacyID = legacy.habits[0].id
assert(legacy.submitHabitEvidence(legacyID, date: day(66), text: "今天阅读", image: nil, now: day(66)))
assert(legacy.applyHabitReview(legacyID, day: dayKey(day(66)), approved: true, feedback: "相关", now: day(66)) == HabitReward(coins: 1, milestones: []))
assert(legacy.habitProgress?.pastMilestones == Set([7, 30, 66]) && legacy.habitProgress?.milestones.isEmpty == true)
assert(legacy.garden.cropSeeds[Crop.starlightCarrot.rawValue] == nil && legacy.garden.economy.owned.isEmpty && legacy.garden.economy.finds.isEmpty)
_ = try legacy.validated()

var boundary = AppData(); boundary.habits = [Habit(title: "读书", reminderMinutes: 0, encouragement: "加油")]
_ = try boundary.validated(); boundary.habits[0].reminderMinutes = 1439; _ = try boundary.validated()
boundary.habits[0].reminderMinutes = 1440; rejected(boundary)
boundary.habits[0].reminderMinutes = nil; boundary.habits[0].days = ["2026-02-30"]; rejected(boundary)
boundary.habits[0].days = []; boundary.habits[0].checkIns = [dayKey(first): HabitCheckIn(text: "", image: nil, submittedAt: first)]; rejected(boundary)
boundary.habits[0].checkIns = nil; boundary.tasks = [GardenTask(title: "事项", category: " ")]; rejected(boundary)
boundary.tasks = []; boundary.habitProgress = HabitProgress(days: [dayKey(first)], rewardedDays: [dayKey(day(1))]); rejected(boundary)
assert(validDayKey("2024-02-29") && !validDayKey("2025-02-29") && !validDayKey("2026-1-01"))
print("PASS: old-save compatibility, optional categories and due dates, evidence validation, today-only submissions/reviews, cancellation, rejection/resubmission, unique-day rewards, nonconsecutive 7/30/66/90 milestones, usable exclusive seeds/clothes/potion, no legacy back-pay, deletion retention and save validation")

let saveURL = FileManager.default.temporaryDirectory.appendingPathComponent("habit-save-\(UUID().uuidString).json")
defer { try? FileManager.default.removeItem(at: saveURL) }
try SaveFile.write(restored, to: saveURL)
let savedBytes = try Data(contentsOf: saveURL)
var large = AppData()
for _ in 0..<19 {
    let habit = Habit(title: "照片记录")
    large.habits.append(habit)
    assert(large.submitHabitEvidence(habit.id, date: first, text: "", image: Data(repeating: 1, count: 2_097_152), now: first))
}
do { try SaveFile.write(large, to: saveURL); fatalError("Oversized save accepted") } catch DataIssue.tooLarge { }
let bytesAfterOversize = try Data(contentsOf: saveURL)
assert(bytesAfterOversize == savedBytes)
print("PASS: photo-only evidence and oversized save refusal preserve the previous readable file")
