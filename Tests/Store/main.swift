import Foundation
import UserNotifications

@main
enum HabitStoreChecks {
    static func main() throws {
        let store = GardenStore(preview: true)
        store.data = AppData()
        store.data.preferences.sound = false
        defer { store.storageLocked = true; try? FileManager.default.removeItem(at: store.file.deletingLastPathComponent()) }
        let habit = Habit(title: "阅读", reminderMinutes: 0, encouragement: "读一点")
        assert(store.upsert(habit))
        assert(store.submitHabitEvidence(habit.id, date: Date(), text: "读了三页", image: nil))
        let originalHabits = store.data.habits
        let originalProgress = store.data.habitProgress
        let disk = try Data(contentsOf: store.file)
        let backup = store.file.deletingLastPathComponent().appendingPathComponent("readable.json")
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        assert(!store.save() && store.error.hasPrefix("保存失败"))
        assert(!store.submitHabitEvidence(habit.id, date: Date(), text: "更新但无法写入", image: nil))
        assert(store.data.habits == originalHabits && store.message.isEmpty)
        assert(!store.cancelHabitSubmission(habit.id, date: Date()) && store.data.habits == originalHabits)
        assert(!store.upsert(Habit(title: "不能新建")) && store.data.habits == originalHabits)
        var edited = habit; edited.title = "不能改名"; edited.encouragement = "改写"
        assert(!store.upsert(edited) && store.data.habits == originalHabits)
        assert(!store.removeHabit(habit.id) && store.data.habits == originalHabits && store.data.habitProgress == originalProgress)
        assert(!store.upsert(GardenTask(title: "不能新建事项", category: "待办")) && store.data.tasks.isEmpty)
        assert(!store.upsert(Appointment(title: "不能新建日程")) && store.data.events.isEmpty)
        let stillReadable = try Data(contentsOf: backup)
        assert(stillReadable == disk)
        try FileManager.default.removeItem(at: store.file)
        try FileManager.default.moveItem(at: backup, to: store.file)
        assert(store.submitHabitEvidence(habit.id, date: Date(), text: "恢复可写后重试", image: nil) && store.error.isEmpty)
        let retried = try SaveFile.read(store.file)
        assert(retried.habits[0].checkIns?[dayKey()]?.text == "恢复可写后重试")
        print("PASS: Store disk failures return false, roll back create/edit/delete/evidence/update/cancel, keep readable disk data, and allow successful retry")

        store.data = AppData()
        for index in 0..<18 { store.data.habits.append(Habit(title: "照片\(index)")) }
        let photo = Data(repeating: 1, count: 2_097_152)
        for habit in store.data.habits.prefix(17) { assert(store.data.submitHabitEvidence(habit.id, date: Date(), text: "", image: photo)) }
        assert(store.save())
        let beforeOversize = try Data(contentsOf: store.file)
        let beforeHabits = store.data.habits
        assert(!store.submitHabitEvidence(store.data.habits[17].id, date: Date(), text: "", image: photo))
        assert(store.data.habits == beforeHabits && store.error.contains("50 MB") && store.message.isEmpty)
        let afterOversize = try Data(contentsOf: store.file)
        assert(beforeOversize == afterOversize)
        print("PASS: Store photo-size overflow refuses submission and preserves both previous memory state and readable save")

        store.data = AppData()
        for index in 0..<25 { store.data.habits.append(Habit(title: "提醒\(index)", reminderMinutes: index, encouragement: "鼓励\(index)")) }
        for index in 0..<45 { store.data.events.append(Appointment(title: "日程\(index)", start: Date().addingTimeInterval(Double(3600 + index)), end: Date().addingTimeInterval(Double(7200 + index)))) }
        let requests = store.reminderRequests()
        assert(requests.count == 70 && Set(requests.map(\.identifier)).count == 70)
        let last = requests.first { $0.identifier == "habit-\(store.data.habits[24].id.uuidString)" }!
        assert(last.content.body == "鼓励24" && (last.trigger as? UNCalendarNotificationTrigger)?.dateComponents.minute == 24)
        print("PASS: reminder planning includes every one of 25 habits and 45 future events without arbitrary truncation")
    }
}
