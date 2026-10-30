import AppKit
import Combine
import Carbon
import UserNotifications
import UniformTypeIdentifiers

final class GardenStore: ObservableObject {
    @Published var data: AppData { didSet { scheduleSave() } }
    @Published var now = Date()
    @Published var message = ""
    @Published var error = ""
    @Published private(set) var saveStatus = "已保存"
    @Published var storageLocked = false
    @Published var selectedPage = "首页"
    @Published var journalDate = Date()
    @Published var activeTool = "任务"
    @Published var focusDraftMinutes = 25
    @Published var tapPhase = 0
    @Published var petLookDirection:Int?=nil
    @Published var petFacingRight = false
    @Published var petDocked = false
    @Published var inputStatus = "计数未开启"
    @Published var petAnimationBegan=Date()
    @Published var petExpression = 0
    @Published var petDragImpulse: CGFloat = 0
    @Published var petDragUpdated = Date()
    @Published var notificationStatus = "尚未开启"
    let file: URL
    private var saveWork: DispatchWorkItem?
    private var clock: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var lastCheckpoint = Date()
    private var lastReminderRefresh = Date.distantPast
    private var reminderGeneration = 0
    private var reminderRefreshActive = false
    private var reminderRefreshNeeded = false
    @Published private(set) var reminderScheduledThrough: Date? = nil
    private var tapReset: DispatchWorkItem?
    var counter: KeyCounter?
    var pet: PetController?
    var openMain: (() -> Void)?
    let preview: Bool

    init(preview: Bool = false) {
        self.preview = preview
        let manager = FileManager.default
        let folder = preview ? manager.temporaryDirectory.appendingPathComponent("Daygarden-Preview-\(ProcessInfo.processInfo.processIdentifier)") :
            manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Daygarden")
        file = folder.appendingPathComponent("garden.json")
        data = AppData()
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            if manager.fileExists(atPath: file.path) {
                do {
                    data = try SaveFile.read(file)
                } catch {
                    let originalError = error
                    do {
                        let recovered = try SaveFile.read(folder.appendingPathComponent("previous.json"))
                        try manager.copyItem(at: file, to: folder.appendingPathComponent("damaged-\(UUID().uuidString).json"))
                        data = recovered
                        message = "已从上次启动时的备份恢复。原存档已保留在存档文件夹。"
                    } catch {
                        self.error = "存档读取失败，已暂停写入。可以在设置中导入备份。\(originalError.localizedDescription)"
                        storageLocked = true
                    }
                }
                if !storageLocked {
                    do { try SaveFile.write(data, to: folder.appendingPathComponent("previous.json")) }
                    catch { self.error = "无法刷新启动备份：\(error.localizedDescription)" }
                }
            }
            if data.timer != nil {
                data.timer?.pause(at: data.savedAt)
                message = "上次的计时已暂停，保留至最近一次保存的进度。"
            }
        } catch {
            self.error = "无法打开存档文件夹：\(error.localizedDescription)"
            storageLocked = true
        }
        data.migrateRecurrences(at: now, calendar: calendar)
        focusDraftMinutes = data.preferences.focusMinutes
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.tick(date) }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.data.timer?.resumedAt != nil else { return }
                self.pauseTimer()
                self.message = "屏幕休眠或会话离开，计时已暂停。回来后可以继续。"
            })
        }
        for name in [Notification.Name.NSSystemTimeZoneDidChange, Notification.Name.NSCalendarDayChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.now = Date()
                if self.data.preferences.notifications { self.refreshReminders() }
            })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.now = Date()
            if self.data.preferences.notifications { self.refreshReminders() }
        })
    }

    func scheduleSave() {
        guard !storageLocked else { return }
        saveStatus = "保存中"
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    @discardableResult
    func save() -> Bool {
        guard !storageLocked else { saveStatus = "保存失败"; return false }
        saveWork?.cancel()
        var snapshot = data
        snapshot.savedAt = Date()
        do {
            try SaveFile.write(snapshot, to: file)
            saveStatus = "已保存"
            if error.hasPrefix("保存失败") { error = "" }
            return true
        } catch {
            saveStatus = "保存失败"
            self.error = "保存失败，当前内容仍保留在窗口中。\(error.localizedDescription)"
            return false
        }
    }

    func tick(_ date: Date) {
        now = date
        guard !storageLocked else { return }
        if let run = data.timer, run.resumedAt != nil, run.kind != .stopwatch, run.elapsed(at: date) >= run.target {
            finishTimer()
        }
        if !preview, data.preferences.notifications, date.timeIntervalSince(lastReminderRefresh) >= 6*3600 { refreshReminders() }
        if date.timeIntervalSince(lastCheckpoint) >= 20 {
            lastCheckpoint = date
            if data.timer != nil || counter != nil { save() }
            if data.preferences.typingEnabled, counter == nil, CGPreflightListenEventAccess() {
                setTyping(true, requestPermission: false)
            }
        }
    }

    var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = data.preferences.weekStartsOn ?? 2
        return value
    }

    var todaySessions: [FocusSession] { data.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: now) } }
    var todayMinutes: Int { Int(todaySessions.reduce(0) { $0 + $1.seconds } / 60) }
    var todayKeys: Int { data.keys[dayKey(now), default: 0] }
    var todayClicks: Int { data.mouseClicks?[dayKey(now)] ?? 0 }
    var todayActions: Int { todayKeys + todayClicks }
    func openJournal(date: Date) {
        journalDate = date
        selectedPage = "日记"
        pet?.openTool("日记")
    }
    var idlePose: Int {
        get { data.preferences.idlePose ?? 0 }
        set { data.preferences.idlePose = newValue == 1 ? 1 : 0 }
    }
    var canStartBreak: Bool { data.timer == nil && data.pomodoroBreakReady == true }
    var petBasePhase:Int {
        guard let timer=data.timer else{return 0}
        return timer.resumedAt == nil || timer.kind == .rest ? 31:30
    }
    var petPhase:Int { tapPhase != 0 && tapPhase != 31 ? tapPhase : petBasePhase }
    var todayTaskOccurrences: [TaskOccurrence] {
        taskOccurrences(from: now, through: now).filter { occurrence in
            occurrence.completedAt == nil && (occurrence.scheduledDay != nil || (occurrence.task.due.map { calendar.startOfDay(for: $0) <= calendar.startOfDay(for: now) } ?? true))
        }
    }
    var todayTasks: [GardenTask] { todayTaskOccurrences.map(\.task) }
    var taskCompletionRecords: [TaskCompletionRecord] { data.taskCompletionRecords }
    func taskOccurrences(from start: Date, through end: Date) -> [TaskOccurrence] {
        data.taskOccurrences(from: start, through: end, calendar: calendar).sorted {
            if $0.task.quadrant != $1.task.quadrant { return $0.task.quadrant < $1.task.quadrant }
            return ($0.scheduledDay ?? "") > ($1.scheduledDay ?? "")
        }
    }
    var allTaskOccurrences: [TaskOccurrence] {
        let first = data.tasks.compactMap { $0.scheduleRevisions?.map(\.effectiveFrom).min() }.min().flatMap { Recurrence.date($0, calendar: calendar) } ?? now
        return taskOccurrences(from: min(first, now), through: now)
    }
    var reminderCoverageText: String {
        reminderScheduledThrough.map { "预排至 " + $0.formatted(.dateTime.year().month().day()) + "；应用运行时自动续排，退出后仅保留已排提醒。" } ?? "应用运行时滚动预排未来 30 天提醒；系统实际排入结果会单独核对。"
    }
    private func scheduleChangeIsValid(old: [ScheduleRevision]?, new: [ScheduleRevision]?) -> Bool {
        guard Recurrence.valid(new) else { return false }
        let today = CalendarDates.key(now, calendar: calendar)
        let past = (old ?? []).filter { $0.effectiveFrom <= today }
        return past.allSatisfy { new?.contains($0) == true } && (new ?? []).allSatisfy { $0.effectiveFrom >= today || past.contains($0) }
    }

    @discardableResult
    func upsert(_ task: GardenTask) -> Bool {
        var task = task
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.category = task.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        var library = task.messageLibrary ?? ReminderTextLibrary(); library.normalize(); task.messageLibrary = library
        let old = data.tasks.first { $0.id == task.id }
        if let current = old?.messageLibrary {
            library.used = current.used.intersection(Set(library.phrases.map(\.id)))
            library.lastID = current.lastID.flatMap { id in library.phrases.contains { $0.id == id } ? id : nil }
            task.messageLibrary = library
        }
        guard !storageLocked, !task.title.isEmpty, !task.categoryName.isEmpty, task.categoryName.count <= 40,
              scheduleChangeIsValid(old: old?.scheduleRevisions, new: task.scheduleRevisions),
              task.reminderMinutes.map({ (0..<1440).contains($0) }) ?? true else { return false }
        let previous = data
        if let i = data.tasks.firstIndex(where: { $0.id == task.id }) { data.tasks[i] = task }
        else { data.tasks.append(task) }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    @discardableResult
    func toggleTask(_ id: UUID) -> Bool {
        guard let occurrence = taskOccurrences(from: now, through: now).first(where: { $0.task.id == id }) else { return false }
        return toggleTaskOccurrence(occurrence)
    }
    @discardableResult
    func toggleTaskOccurrence(_ occurrence: TaskOccurrence) -> Bool {
        guard !storageLocked, let i = data.tasks.firstIndex(where: { $0.id == occurrence.task.id }) else { return false }
        let previous = data
        if let day = occurrence.scheduledDay {
            guard day <= CalendarDates.key(now, calendar: calendar), let date = Recurrence.date(day, calendar: calendar),
                  data.taskOccurrences(from: date, through: date, calendar: calendar).contains(where: { $0.id == occurrence.id }) else { return false }
            if data.recurringTaskCompletions == nil { data.recurringTaskCompletions = [] }
            if data.recurringTaskCompletions!.contains(where: { $0.id == occurrence.id }) { data.recurringTaskCompletions!.removeAll { $0.id == occurrence.id } }
            else { data.recurringTaskCompletions!.append(TaskCompletionRecord(id: occurrence.id, taskID: occurrence.task.id, title: data.tasks[i].title, scheduledDay: day, completedAt: now)) }
        } else {
            guard data.tasks[i].scheduleRevisions == nil else { return false }
            data.tasks[i].completedAt = data.tasks[i].completedAt == nil ? now : nil
        }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    @discardableResult
    func removeTask(_ id: UUID) -> Bool {
        guard !storageLocked else { return false }
        let previous = data
        data.tasks.removeAll { $0.id == id }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    @discardableResult
    func upsert(_ event: Appointment) -> Bool {
        guard !storageLocked, !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, event.end >= event.start else { return false }
        let previous = data
        if let i = data.events.firstIndex(where: { $0.id == event.id }) { data.events[i] = event }
        else { data.events.append(event) }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    @discardableResult
    func upsert(_ habit: Habit) -> Bool {
        var habit = habit
        habit.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.encouragement = habit.encouragement?.trimmingCharacters(in: .whitespacesAndNewlines)
        var library = habit.messageLibrary ?? ReminderTextLibrary(texts: [habit.encouragement ?? ""]); library.normalize(); habit.messageLibrary = library
        let old = data.habits.first { $0.id == habit.id }
        if let current = old?.messageLibrary {
            library.used = current.used.intersection(Set(library.phrases.map(\.id)))
            library.lastID = current.lastID.flatMap { id in library.phrases.contains { $0.id == id } ? id : nil }
            habit.messageLibrary = library
        }
        if habit.scheduleRevisions == nil {
            let day = CalendarDates.key(now, calendar: calendar)
            habit.scheduleRevisions = [ScheduleRevision(effectiveFrom: day, anchor: day, rule: RepeatRule(), firstWeekday: calendar.firstWeekday)]
        }
        guard !storageLocked, habit.isValid, scheduleChangeIsValid(old: old?.scheduleRevisions, new: habit.scheduleRevisions) else { return false }
        let previous = data
        if let i = data.habits.firstIndex(where: { $0.id == habit.id }) { data.habits[i] = habit }
        else { data.habits.append(habit) }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    @discardableResult
    func removeHabit(_ id: UUID) -> Bool {
        guard !storageLocked, data.habits.contains(where: { $0.id == id }) else { return false }
        let previous = data
        data.removeHabit(id)
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    func cancelHabitSubmission(_ id: UUID, date: Date) -> Bool {
        guard !storageLocked else { return false }
        if message == "已提交，待审核。" { message = "" }
        let previous = data
        guard data.cancelHabitSubmission(id, date: date) else { return false }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        refreshReminders()
        return true
    }
    func submitHabitEvidence(_ id: UUID, date: Date, text: String, image: Data?) -> Bool {
        guard !storageLocked else { return false }
        if message == "已提交，待审核。" { message = "" }
        let previous = data
        guard data.submitHabitEvidence(id, date: date, text: text, image: image) else { return false }
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; return false }
        message = "已提交，待审核。"
        return true
    }

    func startTimer(kind: TimerKind, minutes: Int, task: GardenTask?, title: String? = nil, occurrenceID: String? = nil) {
        guard data.timer == nil else { message = "先结束或继续当前计时，再开始下一段。"; return }
        guard kind != .rest || canStartBreak else { message = "完成一段番茄钟后，可以开始休息。"; return }
        let date = Date()
        data.pomodoroBreakReady = false
        data.timer = TimerRun(kind: kind, target: Double(max(1, minutes)) * 60,
                              taskID: task?.id, taskTitle: kind == .rest ? "休息" : (task?.title ?? title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "自由专注"),
                              startedAt: date, resumedAt: date, occurrenceID: occurrenceID)
        now = date
        save()
        refreshTimerReminder()
    }
    func pauseTimer() {
        data.timer?.pause(at: Date())
        save()
        refreshTimerReminder()
    }
    func resumeTimer() {
        guard data.timer != nil, data.timer?.resumedAt == nil else { return }
        data.timer?.resumedAt = Date()
        save()
        refreshTimerReminder()
    }
    func finishTimer() {
        let previousLevel=data.levelProgress.level
        let kind = data.timer?.kind
        guard let result = data.finishTimer(at: Date()) else { return }
        message = result.rest ? "休息结束，可以开始下一段了。" :
            "已记录 \(Int(result.seconds / 60)) 分 \(Int(result.seconds) % 60) 秒专注，获得 \(result.water) 滴露水。"
        animatePet(PetMotion.jumping.rawValue,seconds:PetMotion.jumping.duration)
        if data.preferences.sound { NSSound(named: "Glass")?.play() }
        if kind == .pomodoro && canStartBreak { message += " 可以开始 \(data.preferences.breakMinutes) 分钟休息。" }
        if data.levelProgress.level>previousLevel {message += " 升到 \(data.levelProgress.level) 级了。"}
        save()
        refreshTimerReminder()
    }

    func setTyping(_ enabled: Bool, requestPermission: Bool = true) {
        if !enabled {
            counter?.stop()
            counter = nil
            data.preferences.typingEnabled = false
            inputStatus = "计数已暂停"
            return
        }
        data.preferences.typingEnabled = true
        guard CGPreflightListenEventAccess() || (requestPermission && CGRequestListenEventAccess()) else {
            inputStatus = "等待输入监控权限"
            message = "请在系统设置 → 隐私与安全性 → 输入监控中允许「暮色小院」。"
            return
        }
        counter?.stop()
        counter = nil
        let newCounter = KeyCounter { [weak self] kind in
            self?.recordInput(kind)
        }
        do {
            try newCounter.start()
            counter = newCounter
            inputStatus = "正在计数"
            if message == "操作计数已开启。" { message = "" }
        } catch {
            inputStatus = "计数连接失败"
            self.error = error.localizedDescription
        }
    }

    func recordInput(_ kind: KeyCounter.Input, at date: Date = Date()) {
        guard !storageLocked else { return }
        let key = dayKey(date)
        if kind == .keyboard { data.keys[key, default: 0] = min(1_000_000_000, data.keys[key, default: 0]+1) }
        else {
            if data.mouseClicks == nil { data.mouseClicks = [:] }
            data.mouseClicks?[key] = min(1_000_000_000, (data.mouseClicks?[key] ?? 0)+1)
        }
        animateTyping()
    }

    func setPet(_ visible: Bool) {
        data.preferences.petVisible = visible
        if visible { pet?.show() } else { pet?.hide() }
    }

    func animateTyping() {
        guard [0,1,2].contains(tapPhase) else{return}
        animatePet(todayActions % 2 + 1, seconds: 0.16)
    }

    func clickPet() {
        petExpression = (petExpression + 1) % 4
        animatePet(20, seconds: 0.65)
    }

    func dragPet(_ velocity:CGFloat) {
        tapReset?.cancel();tapReset=nil
        petDragUpdated = Date()
        petDragImpulse = velocity.isFinite ? min(1200, max(-1200, velocity)) : 0
        let next = petDragImpulse == 0 && [10,11].contains(tapPhase) ? tapPhase :
            (petDragImpulse >= 0 ? PetMotion.dragRight.rawValue : PetMotion.dragLeft.rawValue)
        if ![10,11].contains(tapPhase) {petAnimationBegan=Date()}
        tapPhase=next
    }

    func dropPet() {animatePet(21,seconds:0.55)}

    func updatePetLook(point:CGPoint?,size:CGSize) {
        let direction=point.flatMap{PetLook.direction(point:$0,size:size)}
        if direction != petLookDirection {petLookDirection=direction}
    }

    func previewMotion(_ motion:PetMotion) {
        pet?.closeMenu()
        animatePet(motion.rawValue,seconds:motion.duration)
    }

    func animatePet(_ phase: Int, seconds: Double) {
        guard phase != PetMotion.resting.rawValue else { return }
        guard ![10,11].contains(tapPhase) || phase == PetMotion.landing.rawValue else { return }
        tapReset?.cancel()
        petAnimationBegan=Date()
        tapPhase = phase
        let duration=[20,22,23].contains(phase) ? max(seconds,PetMotion(rawValue:phase)?.duration ?? seconds):seconds
        let reset = DispatchWorkItem { [weak self] in self?.tapPhase = 0 }
        tapReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: reset)
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.data.preferences.notifications = granted
                self.notificationStatus = granted ? "已开启" : "尚未获得系统允许"
                if let error { self.error = "提醒权限：\(error.localizedDescription)" }
                self.refreshReminders()
            }
        }
    }
    func refreshTimerReminder() {
        guard !preview else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["focus-timer"])
        guard data.preferences.notifications, let run = data.timer,
              run.resumedAt != nil, run.kind != .stopwatch else { return }
        let content = UNMutableNotificationContent()
        content.title = run.kind == .rest ? "休息结束" : "这一段专注完成了"
        content.body = run.kind == .rest ? "回到小院，选择接下来的事情。" : "回到小院查看收成，或开始休息。"
        if data.preferences.sound { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, run.display(at: Date())), repeats: false)
        center.add(UNNotificationRequest(identifier: "focus-timer", content: content, trigger: trigger)) { [weak self] error in
            if let error { DispatchQueue.main.async { self?.error = "计时提醒未设置成功：\(error.localizedDescription)" } }
        }
    }
    private func requests(for assignments: [ReminderAssignment], at date: Date) -> [UNNotificationRequest] {
        var requests = assignments.map { item -> UNNotificationRequest in
            let content = UNMutableNotificationContent()
            content.title = item.title; content.body = item.text
            if data.preferences.sound { content.sound = .default }
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireAt)
            components.calendar = calendar; components.timeZone = calendar.timeZone
            return UNNotificationRequest(identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        }
        for event in data.events.filter({ $0.remind && $0.start > date }).sorted(by: { $0.start < $1.start }) {
            let content = UNMutableNotificationContent()
            content.title = "日程开始：\(event.title)"
            content.body = event.notes.isEmpty ? "打开暮色小院查看今天的安排。" : event.notes
            if data.preferences.sound { content.sound = .default }
            requests.append(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, event.start.timeIntervalSince(date)), repeats: false)))
        }
        return requests
    }
    func reminderRequests(at date: Date = Date()) -> [UNNotificationRequest] {
        var snapshot = data
        return requests(for: snapshot.planReminders(at: date, calendar: calendar), at: date)
    }
    func refreshReminders() {
        guard !preview, !storageLocked else { return }
        if reminderRefreshActive { reminderRefreshNeeded = true; return }
        reminderRefreshActive = true
        lastReminderRefresh = now
        reminderGeneration += 1
        let generation = reminderGeneration
        let center = UNUserNotificationCenter.current()
        guard data.preferences.notifications else {
            center.removeAllPendingNotificationRequests(); reminderScheduledThrough = nil; finishReminderRefresh(); return
        }
        let previous = data
        let assignments = data.planReminders(at: now, calendar: calendar)
        guard save() else { data = previous; saveWork?.cancel(); saveStatus = "保存失败"; finishReminderRefresh(); return }
        let requests = requests(for: assignments, at: now)
        let expected = Set(requests.map(\.identifier))
        reminderScheduledThrough = calendar.date(byAdding: .day, value: 29, to: now)
        refreshTimerReminder()
        center.getPendingNotificationRequests { [weak self] pending in
            DispatchQueue.main.async {
                guard let self, generation == self.reminderGeneration else { return }
                center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0 != "focus-timer" && !expected.contains($0) })
                let group = DispatchGroup()
                for request in requests {
                    group.enter()
                    center.add(request) { [weak self] error in
                        if let error { DispatchQueue.main.async { if generation == self?.reminderGeneration { self?.error = "提醒未设置成功：\(error.localizedDescription)" } } }
                        group.leave()
                    }
                }
                group.notify(queue: .main) { [weak self] in
                    center.getPendingNotificationRequests { pending in
                        DispatchQueue.main.async {
                            guard let self, generation == self.reminderGeneration else { return }
                            let actual = Set(pending.map(\.identifier)), missing = expected.subtracting(actual)
                            for i in self.data.reminderAssignments?.indices ?? 0..<0 { self.data.reminderAssignments?[i].registered = actual.contains(self.data.reminderAssignments![i].id) }
                            let saved = self.save()
                            self.notificationStatus = missing.isEmpty && saved ? "已开启" : "部分提醒未能排入系统"
                            if !missing.isEmpty { self.error = "有 \(missing.count) 条提醒未能排入系统。实际排入 \(expected.count-missing.count) 条；应用运行时会继续核对和续排。" }
                            self.finishReminderRefresh()
                        }
                    }
                }
            }
        }
    }

    private func finishReminderRefresh() {
        reminderRefreshActive = false
        if reminderRefreshNeeded { reminderRefreshNeeded = false; refreshReminders() }
    }

    func exportData() {
        save()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "暮色小院-\(dayKey()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var snapshot = data
        snapshot.savedAt = Date()
        snapshot.timer?.pause(at: snapshot.savedAt)
        do { try SaveFile.write(snapshot, to: url); message = "备份已导出。" }
        catch { self.error = "导出失败：\(error.localizedDescription)" }
    }

    func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var incoming = try SaveFile.read(url)
            let alert = NSAlert()
            alert.messageText = "用这份备份恢复小院？"
            alert.informativeText = "当前存档会先保留为一份备份，然后替换成所选文件中的任务、日记与游戏进度。"
            alert.addButton(withTitle: "恢复备份")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            if FileManager.default.fileExists(atPath: file.path) {
                let backup = file.deletingLastPathComponent().appendingPathComponent("before-restore-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: file, to: backup)
            }
            incoming.timer?.pause(at: incoming.savedAt)
            incoming.preferences.typingEnabled = false
            incoming.preferences.notifications = false
            try SaveFile.write(incoming, to: file)
            counter?.stop()
            counter = nil
            storageLocked = false
            error = ""
            data = incoming
            setPet(incoming.preferences.petVisible)
            refreshReminders()
            message = "已恢复备份。按键计数和通知可在这里重新开启。"
        } catch { self.error = "无法恢复，当前存档保持原样。\(error.localizedDescription)" }
    }

    func shutdown() {
        data.timer?.pause(at: Date())
        save()
        counter?.stop()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-timer"])
    }

    func seedPreview() {
        data.tasks = [GardenTask(title: "读完这一章", important: true, urgent: false, due: Date()),
                      GardenTask(title: "整理明天的安排", important: true, urgent: true, due: Date()),
                      GardenTask(title: "给窗台的植物浇水", important: false, urgent: false)]
        data.habits = [Habit(title: "读书二十分钟"), Habit(title: "出门走一走", days: [dayKey()]), Habit(title: "写一小段日记")]
        data.events = [Appointment(title: "留给自己的阅读时间", start: Date().addingTimeInterval(3600), end: Date().addingTimeInterval(7200))]
        data.sessions = [FocusSession(id: UUID(), title: "阅读", kind: .pomodoro, date: Date(), seconds: 1500)]
        data.keys[dayKey()] = 1286
        data.garden.plots[0].crop = .carrot
        data.garden.plots[1].crop = .tomato
        data.garden.plots[1].plantedAt = 900
    }
}

final class KeyCounter {
    enum Input { case keyboard, mouse }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    let onInput: (Input) -> Void
    init(onInput: @escaping (Input) -> Void) { self.onInput = onInput }
    static func input(type: CGEventType, repeated: Bool = false, secure: Bool = false, modifierDown: Bool = false, capsLockChanged: Bool = false) -> Input? {
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: return .mouse
        case .keyDown: return !repeated && !secure ? .keyboard : nil
        case .flagsChanged: return (modifierDown || capsLockChanged) && !secure ? .keyboard : nil
        default: return nil
        }
    }
    func start() throws {
        stop()
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<KeyCounter>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else {
                let modifierDown = type == .flagsChanged && CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)))
                if let input = KeyCounter.input(type: type, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                                          secure: IsSecureEventInputEnabled(), modifierDown: modifierDown,
                                          capsLockChanged: type == .flagsChanged && event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_CapsLock)) {
                    owner.onInput(input)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        let events: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = events.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                         eventsOfInterest: mask,
                                         callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw NSError(domain: "Daygarden", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法开始计数。请检查输入监控权限，必要时退出并重新打开小院。"])
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }
    deinit { stop() }
}

private extension String { var nilIfBlank: String? { isEmpty ? nil : self } }
