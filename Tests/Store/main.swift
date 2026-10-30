import Foundation
import UserNotifications

@main
enum HabitStoreChecks {
    @MainActor
    static func main() async throws {
        let reviewClock = ReviewClock()
        let store = GardenStore(preview: true, reviewClock: { reviewClock.date })
        store.data = AppData()
        store.data.preferences.sound = false
        defer { store.storageLocked = true; try? FileManager.default.removeItem(at: store.file.deletingLastPathComponent()) }
        let habit = Habit(title: "阅读", reminderMinutes: 0, encouragement: "读一点")
        assert(store.upsert(habit) && store.saveStatus == "已保存")
        assert(store.submitHabitEvidence(habit.id, date: Date(), text: "读了三页", image: nil))
        let originalHabits = store.data.habits
        let originalProgress = store.data.habitProgress
        let disk = try Data(contentsOf: store.file)
        let backup = store.file.deletingLastPathComponent().appendingPathComponent("readable.json")
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        assert(!store.save() && store.error.hasPrefix("保存失败") && store.saveStatus == "保存失败")
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
        assert(requests.count >= 25*29+45 && Set(requests.map(\.identifier)).count == requests.count)
        assert(requests.filter { UUID(uuidString: $0.identifier) != nil }.count == 45)
        let last = requests.first { $0.identifier.hasPrefix("habit-\(store.data.habits[24].id.uuidString)-") }!
        assert(last.content.body == "鼓励24" && (last.trigger as? UNCalendarNotificationTrigger)?.dateComponents.minute == 24 && last.trigger?.repeats == false)
        print("PASS: rolling one-shot reminder planning includes every one of 25 habits and 45 future events with stable unique request identifiers")

        store.data = AppData()
        let calendar = store.calendar
        func date(_ day: Int) -> Date { calendar.date(from: DateComponents(year: 2030, month: 1, day: day, hour: 12))! }
        store.now = date(4)
        let revision = ScheduleRevision(effectiveFrom: "2030-01-01", anchor: "2030-01-01", rule: RepeatRule(), firstWeekday: calendar.firstWeekday)
        let repeating = GardenTask(title: "阅读", scheduleRevisions: [revision])
        store.data.tasks = [repeating]
        assert(store.save())
        let oldOccurrence = store.taskOccurrences(from: date(1), through: date(1))[0]
        let todayOccurrence = store.todayTaskOccurrences[0]
        assert(todayOccurrence.scheduledDay == "2030-01-04" && store.allTaskOccurrences.count == 4)
        assert(store.toggleTaskOccurrence(oldOccurrence))
        assert(store.taskCompletionRecords.count == 1 && store.taskCompletionRecords[0].scheduledDay == "2030-01-01" && store.taskCompletionRecords[0].completedAt == date(4))
        assert(store.todayTaskOccurrences.count == 1 && store.todayTaskOccurrences[0].id == todayOccurrence.id)
        assert(store.toggleTaskOccurrence(todayOccurrence) && store.todayTaskOccurrences.isEmpty)
        assert(store.taskCompletionRecords.count == 2)
        let roundtrip = try SaveFile.read(store.file)
        assert(roundtrip.taskCompletionRecords == store.taskCompletionRecords)
        var rewrite = store.data.tasks[0]; rewrite.scheduleRevisions![0].rule!.every = 2
        assert(!store.upsert(rewrite))
        rewrite = store.data.tasks[0]
        rewrite.scheduleRevisions = Recurrence.revised(rewrite.scheduleRevisions, rule: RepeatRule(every: 2), anchor: date(5), effective: date(5), calendar: calendar)
        assert(store.upsert(rewrite))
        assert(store.taskOccurrences(from: date(1), through: date(4)).count == 4)
        let savedRecords = store.taskCompletionRecords
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        assert(!store.toggleTaskOccurrence(todayOccurrence) && store.taskCompletionRecords == savedRecords && store.saveStatus == "保存失败")
        assert(!store.removeTask(repeating.id) && store.data.tasks.count == 1)
        try FileManager.default.removeItem(at: store.file)
        try FileManager.default.moveItem(at: backup, to: store.file)
        assert(store.removeTask(repeating.id) && store.taskCompletionRecords == savedRecords)
        print("PASS: Store current versus missed recurring tasks, actual completion timestamps, restart persistence, historical schedule protection, completion/delete rollback and retained deleted-series history")
        try await HabitReviewChecks.run(store, clock: reviewClock)
    }
}

private final class ReviewClock {
    var date = Date()
}

private final class ReviewSecrets: AISecretStorage {
    var values: [UUID: String] = [:]
    var reads = 0
    func read(_ id: UUID) throws -> String? { reads += 1; return values[id] }
    func contains(_ id: UUID) throws -> Bool { values[id] != nil }
    func write(_ secret: String?, for id: UUID) throws { values[id] = secret }
}

private final class ReviewProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var received = 0, cancelled = 0
    private static var held: [ReviewProtocol] = []
    private static var waiting = false, approved = true, status = 200
    private var ended = false
    static func prepare(waiting: Bool = false, approved: Bool = true, status: Int = 200) {
        lock.lock(); defer { lock.unlock() }
        received = 0; cancelled = 0; held = []; self.waiting = waiting; self.approved = approved; self.status = status
    }
    static var count: Int { lock.lock(); defer { lock.unlock() }; return received }
    static var stops: Int { lock.lock(); defer { lock.unlock() }; return cancelled }
    static func completeLatest(approved: Bool = true) {
        lock.lock(); let pending = held.last; lock.unlock()
        pending?.complete(approved: approved, status: 200)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.received += 1
        let waiting = Self.waiting, approved = Self.approved, status = Self.status
        if waiting { Self.held.append(self) }
        Self.lock.unlock()
        if !waiting { complete(approved: approved, status: status) }
    }
    private func complete(approved: Bool, status: Int) {
        Self.lock.lock(); guard !ended else { Self.lock.unlock(); return }; ended = true; Self.lock.unlock()
        let text = String(data: try! JSONSerialization.data(withJSONObject: ["approved": approved, "feedback": approved ? "材料与习惯相关。" : "请补充具体的相关记录。"]), encoding: .utf8)!
        let body: [String: Any] = ["status": "completed", "error": NSNull(), "output": [["type": "message", "status": "completed", "content": [["type": "output_text", "text": text]]]]]
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: body))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {
        Self.lock.lock(); ended = true; Self.cancelled += 1; Self.lock.unlock()
    }
}

@MainActor
private enum HabitReviewChecks {
    private static var checks = 0
    private static func check(_ value: Bool, _ name: String) {
        guard value else { fatalError("FAIL: \(name)") }; checks += 1
    }
    private static func waitForRequest(_ count: Int = 1) async throws {
        for _ in 0..<200 {
            if ReviewProtocol.count >= count { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        fatalError("Mock review did not start")
    }
    private static func waitForStop() async throws {
        for _ in 0..<200 {
            if ReviewProtocol.stops > 0 { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        fatalError("Mock review transport did not cancel")
    }
    static func run(_ store: GardenStore, clock: ReviewClock) async throws {
        let baseline = Date()
        clock.date = baseline; store.now = baseline
        var profile = AIProfile(); profile.name = "审核"; profile.baseURL = "https://review.invalid/v1"; profile.model = "review-model"
        let settings = AISettings(profiles: [profile], assignments: [AIFeature.habitReview.rawValue: profile.id])
        let secrets = ReviewSecrets(); secrets.values[profile.id] = "mock-review-key"
        let client = AIClient(secrets: secrets, protocolClasses: [ReviewProtocol.self])
        let day = dayKey(baseline)
        func reset() {
            clock.date = baseline; store.now = baseline; store.data = AppData(); store.data.ai = settings
            store.error = ""; store.message = ""
            ReviewProtocol.prepare()
        }
        func pending(_ title: String = "阅读", image: Data? = nil) -> Habit {
            let habit = Habit(title: title)
            check(store.upsert(habit), "create review habit")
            check(store.submitHabitEvidence(habit.id, date: clock.date, text: image == nil ? "读了三页并记下内容" : "", image: image), "persist pending evidence")
            return habit
        }
        func start(_ habit: Habit) -> Task<Bool, Never> {
            Task { await store.reviewHabit(habit.id, date: clock.date, client: client) }
        }
        reset()
        let first = pending()
        let submittedAt = store.data.habits[0].checkIns![day]!.submittedAt
        let coins = store.data.garden.coins
        check(await store.reviewHabit(first.id, date: baseline, client: client), "approved review saved")
        check(store.data.habits[0].checkIns?[day]?.status == .approved && store.data.garden.coins == coins + 1, "approval grants one daily coin")
        check(store.data.habits[0].checkIns?[day]?.submittedAt == submittedAt && store.message == "已打卡。", "review preserves submission timestamp")
        check(!(await store.reviewHabit(first.id, date: baseline, client: client)) && ReviewProtocol.count == 1, "approved review never repeats")
        let imageURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("AI/Fixtures/sample.png")
        let second = pending("看窗外的植物", image: try Data(contentsOf: imageURL))
        check(await store.reviewHabit(second.id, date: baseline, client: client), "photo-only review saved")
        check(store.data.garden.coins == coins + 1 && store.data.habitProgress?.rewardedDays == [day], "multiple habits share one daily reward")
        let saved = try SaveFile.read(store.file)
        check(saved.habits == store.data.habits && saved.habitProgress == store.data.habitProgress && saved.garden.coins == store.data.garden.coins, "approved evidence and rewards survive reload")

        reset()
        let rejected = pending()
        ReviewProtocol.prepare(approved: false)
        let beforeRejectCoins = store.data.garden.coins
        check(await store.reviewHabit(rejected.id, date: baseline, client: client), "rejection saved")
        check(store.data.habits[0].checkIns?[day]?.status == .rejected && store.data.garden.coins == beforeRejectCoins && store.message == "需要补充。", "rejection has feedback and no reward")
        check(!(await store.reviewHabit(rejected.id, date: baseline, client: client)) && ReviewProtocol.count == 1, "rejected material requires resubmission")
        check(store.submitHabitEvidence(rejected.id, date: baseline, text: "补充了阅读摘记", image: nil), "replace rejected evidence")
        ReviewProtocol.prepare()
        check(await store.reviewHabit(rejected.id, date: baseline, client: client), "resubmitted evidence can pass")

        reset()
        let missing = pending()
        store.data.ai = nil
        let reads = secrets.reads
        check(!(await store.reviewHabit(missing.id, date: baseline, client: client)) && ReviewProtocol.count == 0 && secrets.reads == reads, "unassigned review uses no credential or request")
        check(store.reviewErrors[missing.id] != nil && store.data.habits[0].checkIns?[day]?.status == .pending, "unassigned review retains pending evidence")
        store.data.ai = settings; secrets.values = [:]
        check(!(await store.reviewHabit(missing.id, date: baseline, client: client)) && ReviewProtocol.count == 0 && store.reviewErrors[missing.id]?.contains("密钥") == true, "missing credential keeps pending without network")
        secrets.values[profile.id] = "mock-review-key"
        for offset in [-1, 1] {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: baseline)!
            let readCount = secrets.reads
            check(!(await store.reviewHabit(missing.id, date: date, client: client)) && ReviewProtocol.count == 0 && secrets.reads == readCount, "past and future review never requests")
        }
        ReviewProtocol.prepare(status: 503)
        check(!(await store.reviewHabit(missing.id, date: baseline, client: client)), "network error stays pending")
        check(store.data.habits[0].checkIns?[day]?.status == .pending && store.reviewErrors[missing.id] != nil && store.reviewingHabits.isEmpty, "network failure exposes retryable error")
        let preservedSubmission = store.data.habits[0].checkIns![day]!.submittedAt
        ReviewProtocol.prepare()
        check(await store.reviewHabit(missing.id, date: baseline, client: client), "retry same saved evidence")
        check(store.data.habits[0].checkIns![day]!.submittedAt == preservedSubmission, "retry keeps original submission timestamp")

        reset()
        let concurrent = pending()
        ReviewProtocol.prepare(waiting: true)
        let running = start(concurrent)
        try await waitForRequest()
        check(store.reviewingHabits == [concurrent.id], "running review publishes state")
        check(!(await store.reviewHabit(concurrent.id, date: baseline, client: client)) && ReviewProtocol.count == 1, "double click creates one request")
        store.data.keys[day] = 2345
        ReviewProtocol.completeLatest()
        check(await running.value && store.reviewingHabits.isEmpty, "running review finishes once")
        check(store.data.keys[day] == 2345, "review commit preserves unrelated concurrent changes")

        reset()
        let transaction = pending()
        let previousDays = Set((1...6).map { dayKey(Calendar.current.date(byAdding: .day, value: -$0, to: baseline)!) })
        store.data.habitProgress = HabitProgress(days: previousDays, rewardedDays: previousDays)
        check(store.save(), "save six previous days")
        let previous = store.data
        ReviewProtocol.prepare(waiting: true)
        let failedSave = start(transaction)
        try await waitForRequest()
        let backup = store.file.deletingLastPathComponent().appendingPathComponent("review-backup.json")
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        ReviewProtocol.completeLatest()
        check(!(await failedSave.value), "failed result save returns false")
        check(store.data.habits == previous.habits && store.data.habitProgress == previous.habitProgress && store.data.garden.coins == previous.garden.coins && store.data.garden.cropSeeds == previous.garden.cropSeeds, "failed result save rolls back approval coins and milestone seeds")
        check(store.saveStatus == "保存失败" && store.reviewErrors[transaction.id]?.hasPrefix("保存失败") == true, "transaction save failure remains visible")
        let disk = try SaveFile.read(backup)
        check(disk.habits == previous.habits && disk.habitProgress == previous.habitProgress, "disk retains pending evidence on transaction failure")
        let countBeforeRetry = ReviewProtocol.count
        check(!(await store.reviewHabit(transaction.id, date: baseline, client: client)) && ReviewProtocol.count == countBeforeRetry, "unwritable save prevents new paid request")
        try FileManager.default.removeItem(at: store.file)
        try FileManager.default.moveItem(at: backup, to: store.file)
        ReviewProtocol.prepare()
        check(await store.reviewHabit(transaction.id, date: baseline, client: client), "retry approval after write recovery")
        check(store.data.habitProgress?.milestones == [7] && store.data.garden.cropSeeds[Crop.starlightCarrot.rawValue, default: 0] == previous.garden.cropSeeds[Crop.starlightCarrot.rawValue, default: 0] + 3 && store.data.garden.coins == previous.garden.coins + 1, "seventh day reward committed exactly once")

        reset()
        let cancel = pending()
        ReviewProtocol.prepare(waiting: true)
        let cancelled = start(cancel)
        try await waitForRequest()
        store.cancelHabitReview(cancel.id)
        check(!(await cancelled.value), "explicit cancellation returns false")
        try await waitForStop()
        check(store.reviewingHabits.isEmpty && store.data.habits[0].checkIns?[day]?.status == .pending && ReviewProtocol.stops > 0, "cancellation stops transport and keeps evidence")
        ReviewProtocol.prepare()
        check(await store.reviewHabit(cancel.id, date: baseline, client: client), "manual retry after cancellation")

        reset()
        let outerCancel = pending()
        ReviewProtocol.prepare(waiting: true)
        let cancelledCaller = start(outerCancel)
        try await waitForRequest()
        cancelledCaller.cancel()
        check(!(await cancelledCaller.value), "caller cancellation returns false")
        try await waitForStop()
        check(store.reviewingHabits.isEmpty && store.data.habits[0].checkIns?[day]?.status == .pending, "caller cancellation stops transport and preserves pending")

        for change in ["resubmit", "sameEvidence", "withdraw", "delete", "rename", "profile", "assignment", "midnight"] {
            reset()
            let habit = pending()
            let oldCoins = store.data.garden.coins
            ReviewProtocol.prepare(waiting: true)
            let old = start(habit)
            try await waitForRequest()
            switch change {
            case "resubmit": check(store.submitHabitEvidence(habit.id, date: baseline, text: "重新提交的阅读摘记", image: nil), "resubmit during review")
            case "sameEvidence": check(store.submitHabitEvidence(habit.id, date: baseline, text: "读了三页并记下内容", image: nil), "identical evidence resubmission invalidates old request")
            case "withdraw": check(store.cancelHabitSubmission(habit.id, date: baseline), "withdraw during review")
            case "delete": check(store.removeHabit(habit.id), "delete during review")
            case "rename": var renamed = store.data.habits[0]; renamed.title = "新名称"; check(store.upsert(renamed), "rename during review")
            case "profile": store.data.ai!.profiles[0].model = "changed-model"; store.data.ai = settings
            case "assignment": store.data.ai!.assignments[AIFeature.habitReview.rawValue] = nil
            default: clock.date = Calendar.current.date(byAdding: .day, value: 1, to: baseline)!; store.tick(clock.date)
            }
            if change == "resubmit" {
                let replacement = start(habit)
                try await waitForRequest(2)
                check(!(await old.value) && store.reviewingHabits == [habit.id], "old completion cannot clear replacement review")
                ReviewProtocol.completeLatest()
                check(await replacement.value, "replacement review commits")
                check(store.data.habits[0].checkIns?[day]?.text == "重新提交的阅读摘记" && store.data.garden.coins == oldCoins + 1, "replacement evidence alone determines reward")
            } else {
                let result = await old.value
                try await waitForStop()
                check(!result && store.reviewingHabits.isEmpty && store.data.garden.coins == oldCoins && ReviewProtocol.stops > 0, "changed context cancels review without reward: \(change)")
            }
        }
        reset()
        let pendingReload = pending()
        let restored = try SaveFile.read(store.file)
        check(restored.habits[0].checkIns?[day]?.status == .pending && ReviewProtocol.count == 0 && store.reviewingHabits.isEmpty, "saved pending evidence has no automatic request")
        check(store.cancelHabitSubmission(pendingReload.id, date: baseline) && store.reviewErrors[pendingReload.id] == nil, "withdraw clears runtime review error")
        print("PASS: \(checks) Store habit-review checks cover text/photo approval, daily and milestone rewards, duplicate requests, rejection/resubmission, missing configuration, network retry, save rollback, cancellation, replacement, deletion, rename, preset changes and midnight")
    }
}
