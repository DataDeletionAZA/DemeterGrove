import Foundation

enum RepeatUnit: String, Codable, CaseIterable {
    case day = "天", week = "周", month = "月", cycle = "自由循环"
}

struct RepeatRule: Codable, Equatable {
    var unit: RepeatUnit = .day
    var every = 1
    var weekdays: Set<Int> = [2]
    var cycleLength = 4
    var activeDays: Set<Int> = [0, 1, 2]
    var isValid: Bool {
        (1...1_000_000).contains(every) && (1...10_000).contains(cycleLength) &&
        (unit != .week || !weekdays.isEmpty) && weekdays.allSatisfy { (1...7).contains($0) } &&
        (unit != .cycle || !activeDays.isEmpty) && activeDays.allSatisfy { (0..<cycleLength).contains($0) }
    }
    static func workRest(active: Int, rest: Int) -> RepeatRule {
        RepeatRule(unit: .cycle, cycleLength: active + rest, activeDays: Set(0..<max(0, active)))
    }
    var continuousActiveDays: Int? {
        let count = activeDays.count
        return count > 0 && activeDays == Set(0..<count) ? count : nil
    }
    var summary: String {
        if unit == .cycle {
            if let active = continuousActiveDays { return "连续执行 \(active) 天，再休息 \(cycleLength-active) 天 · 共 \(cycleLength) 天循环" }
            return "每 \(cycleLength) 天循环 · 第 " + activeDays.sorted().map { String($0 + 1) }.joined(separator: "、") + " 天执行，其余休息"
        }
        return "每 \(every) \(unit.rawValue)" + (unit == .week ? " · " + weekdays.sorted().map { ["日", "一", "二", "三", "四", "五", "六"][$0-1] }.joined(separator: "、") : "")
    }
}

struct ScheduleRevision: Codable, Equatable, Identifiable {
    var id = UUID()
    var effectiveFrom: String
    var anchor: String
    var rule: RepeatRule?
    var firstWeekday = 2
    var isValid: Bool { validDayKey(effectiveFrom) && validDayKey(anchor) && (rule?.isValid ?? true) && (1...7).contains(firstWeekday) }
    func occurs(on date: Date, calendar: Calendar) -> Bool {
        guard let rule, let start = Recurrence.date(anchor, calendar: calendar), date >= start else { return false }
        let day = calendar.startOfDay(for: date)
        let distance = calendar.dateComponents([.day], from: start, to: day).day!
        switch rule.unit {
        case .day: return distance % rule.every == 0
        case .cycle: return rule.activeDays.contains(distance % rule.cycleLength)
        case .week:
            let offset = (calendar.component(.weekday, from: start) - firstWeekday + 7) % 7
            return ((distance + offset) / 7) % rule.every == 0 && rule.weekdays.contains(calendar.component(.weekday, from: day))
        case .month:
            let a = calendar.dateComponents([.year, .month, .day], from: start)
            let b = calendar.dateComponents([.year, .month, .day], from: day)
            let months = (b.year!-a.year!)*12 + b.month!-a.month!
            return months >= 0 && months % rule.every == 0 && b.day == min(a.day!, calendar.range(of: .day, in: .month, for: day)!.count)
        }
    }
}

enum Recurrence {
    static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])), CalendarDates.key(date, calendar: calendar) == key else { return nil }
        return date
    }
    static func revision(_ revisions: [ScheduleRevision]?, on date: Date, calendar: Calendar) -> ScheduleRevision? {
        let key = CalendarDates.key(date, calendar: calendar)
        return revisions?.filter { $0.effectiveFrom <= key }.max { $0.effectiveFrom < $1.effectiveFrom }
    }
    static func valid(_ revisions: [ScheduleRevision]?) -> Bool {
        guard let revisions else { return true }
        return !revisions.isEmpty && Set(revisions.map(\.id)).count == revisions.count && Set(revisions.map(\.effectiveFrom)).count == revisions.count && revisions.allSatisfy(\.isValid)
    }
    static func revised(_ old: [ScheduleRevision]?, rule: RepeatRule?, anchor: Date, effective: Date, calendar: Calendar) -> [ScheduleRevision] {
        let key = CalendarDates.key(effective, calendar: calendar)
        var result = (old ?? []).filter { $0.effectiveFrom < key }
        result.append(ScheduleRevision(effectiveFrom: key, anchor: CalendarDates.key(anchor, calendar: calendar), rule: rule, firstWeekday: calendar.firstWeekday))
        return result
    }
    static func days(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: start), end = calendar.startOfDay(for: end)
        guard start <= end, let count = calendar.dateComponents([.day], from: start, to: end).day, count <= 1_000_000 else { return [] }
        return (0...count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

struct TaskCompletionRecord: Codable, Equatable, Identifiable {
    var id: String
    var taskID: UUID
    var title: String
    var scheduledDay: String?
    var completedAt: Date
    var isValid: Bool {
        guard !title.isEmpty, completedAt.timeIntervalSince1970.isFinite else { return false }
        if let scheduledDay {
            let pieces = id.split(separator: "/").map(String.init)
            return validDayKey(scheduledDay) && pieces.count == 3 && pieces[0] == taskID.uuidString && UUID(uuidString: pieces[1]) != nil && pieces[2] == scheduledDay
        }
        return id == taskID.uuidString
    }
}

struct TaskOccurrence: Identifiable, Equatable {
    var task: GardenTask
    var scheduledDay: String?
    var revisionID: UUID?
    var completedAt: Date?
    var rescheduledDay: String? = nil
    var displayDay: String? { rescheduledDay ?? scheduledDay }
    var id: String { revisionID.map { task.id.uuidString + "/" + $0.uuidString + "/" + scheduledDay! } ?? task.id.uuidString }
}

extension AppData {
    var taskCompletionRecords: [TaskCompletionRecord] {
        tasks.compactMap { task in task.completedAt.map { TaskCompletionRecord(id: task.id.uuidString, taskID: task.id, title: task.title, scheduledDay: nil, completedAt: $0) } } + (recurringTaskCompletions ?? [])
    }
    func taskOccurrences(from start: Date, through end: Date, calendar: Calendar) -> [TaskOccurrence] {
        let completed = Dictionary(uniqueKeysWithValues: (recurringTaskCompletions ?? []).map { ($0.id, $0.completedAt) })
        let reschedules = Dictionary(uniqueKeysWithValues: (taskOccurrenceReschedules ?? []).map { ($0.id, $0) })
        let days = Recurrence.days(from: start, through: end, calendar: calendar)
        let first = CalendarDates.key(start, calendar: calendar), last = CalendarDates.key(end, calendar: calendar)
        return tasks.flatMap { task -> [TaskOccurrence] in
            guard task.scheduleRevisions != nil else { return [TaskOccurrence(task: task, completedAt: task.completedAt)] }
            var originalDays = Set(days.map { CalendarDates.key($0, calendar: calendar) })
            for overlay in reschedules.values where overlay.taskID == task.id && overlay.rescheduledDay >= first && overlay.rescheduledDay <= last { originalDays.insert(overlay.scheduledDay) }
            return originalDays.sorted().compactMap { key in
                guard let day = Recurrence.date(key, calendar: calendar),
                      let revision = Recurrence.revision(task.scheduleRevisions, on: day, calendar: calendar), revision.occurs(on: day, calendar: calendar) else { return nil }
                var occurrence = TaskOccurrence(task: task, scheduledDay: key, revisionID: revision.id)
                if let overlay = reschedules[occurrence.id] { occurrence.rescheduledDay = overlay.rescheduledDay }
                guard let displayDay = occurrence.displayDay, displayDay >= first && displayDay <= last else { return nil }
                occurrence.completedAt = completed[occurrence.id]
                return occurrence
            }
        }
    }

    mutating func migrateRecurrences(at date: Date, calendar: Calendar) {
        let key = CalendarDates.key(date, calendar: calendar)
        for i in habits.indices {
            if habits[i].scheduleRevisions == nil { habits[i].scheduleRevisions = [ScheduleRevision(effectiveFrom: key, anchor: key, rule: RepeatRule(), firstWeekday: calendar.firstWeekday)] }
            if habits[i].messageLibrary == nil { habits[i].messageLibrary = ReminderTextLibrary(texts: [habits[i].encouragement ?? ""]) }
        }
        for i in tasks.indices where tasks[i].messageLibrary == nil { tasks[i].messageLibrary = ReminderTextLibrary() }
        version = max(version, 4)
    }
}

extension Habit {
    func isScheduled(on date: Date, calendar: Calendar) -> Bool {
        if let archivedAt, calendar.startOfDay(for: date) > calendar.startOfDay(for: archivedAt) { return false }
        guard scheduleRevisions != nil else { return true }
        return Recurrence.revision(scheduleRevisions, on: date, calendar: calendar)?.occurs(on: date, calendar: calendar) ?? false
    }
}
