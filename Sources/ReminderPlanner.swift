import Foundation

struct ReminderPhrase: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
}

struct ReminderTextLibrary: Codable, Equatable {
    static let maximumTextLength = 4000
    var phrases: [ReminderPhrase] = []
    var used: Set<UUID> = []
    var lastID: UUID?
    init(texts: [String] = []) { phrases = texts.map { ReminderPhrase(text: $0) }; normalize() }
    mutating func normalize() {
        var texts: Set<String> = []
        phrases = phrases.compactMap { value in
            var value = value
            value.text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.text.isEmpty && texts.insert(value.text).inserted ? value : nil
        }
        let ids = Set(phrases.map(\.id))
        used.formIntersection(ids)
        if let lastID, !ids.contains(lastID) { self.lastID = nil }
    }
    var isValid: Bool {
        Set(phrases.map(\.id)).count == phrases.count && Set(phrases.map(\.text)).count == phrases.count &&
        phrases.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= Self.maximumTextLength } && used.isSubset(of: Set(phrases.map(\.id))) && (lastID.map { id in phrases.contains { $0.id == id } } ?? true)
    }
    mutating func reserve(_ id: UUID) -> Bool {
        guard phrases.contains(where: { $0.id == id }) else { return false }
        if used.count == phrases.count { used.removeAll() }
        guard !used.contains(id), !(used.isEmpty && phrases.count > 1 && lastID == id) else { return false }
        used.insert(id); lastID = id
        return true
    }
    mutating func draw() -> ReminderPhrase? {
        guard !phrases.isEmpty else { return nil }
        if used.count == phrases.count { used.removeAll() }
        let candidates = phrases.filter { !used.contains($0.id) && !(used.isEmpty && phrases.count > 1 && lastID == $0.id) }
        guard let next = candidates.randomElement() else { return nil }
        used.insert(next.id); lastID = next.id
        return next
    }
}

struct ReminderAssignment: Codable, Equatable, Identifiable {
    var id: String
    var ownerID: UUID
    var isHabit: Bool
    var fireAt: Date
    var title: String
    var text: String
    var phraseID: UUID?
    var registered = false
    var isValid: Bool { !id.isEmpty && fireAt.timeIntervalSince1970.isFinite && !title.isEmpty }
    var ownerKey: String { (isHabit ? "habit-" : "task-") + ownerID.uuidString }
}

extension AppData {
    mutating func planReminders(at now: Date, calendar: Calendar, horizonDays: Int = 30) -> [ReminderAssignment] {
        migrateRecurrences(at: now, calendar: calendar)
        let old = reminderAssignments ?? []
        for item in old.filter({ $0.fireAt <= now && $0.registered }).sorted(by: { $0.fireAt < $1.fireAt }) {
            guard let phraseID = item.phraseID else { continue }
            if item.isHabit, let i = habits.firstIndex(where: { $0.id == item.ownerID }) { _ = habits[i].messageLibrary?.reserve(phraseID) }
            if !item.isHabit, let i = tasks.firstIndex(where: { $0.id == item.ownerID }) { _ = tasks[i].messageLibrary?.reserve(phraseID) }
        }
        let last = calendar.date(byAdding: .day, value: max(1, horizonDays)-1, to: now)!
        let days = Recurrence.days(from: now, through: last, calendar: calendar)
        var events: [ReminderAssignment] = []
        func event(id: String, ownerID: UUID, habit: Bool, day: Date, minutes: Int, title: String) -> ReminderAssignment? {
            guard let fire = calendar.date(bySettingHour: minutes/60, minute: minutes%60, second: 0, of: day), fire > now else { return nil }
            return ReminderAssignment(id: id, ownerID: ownerID, isHabit: habit, fireAt: fire, title: title, text: "")
        }
        for habit in habits where habit.archivedAt == nil {
            guard let minutes = habit.reminderMinutes else { continue }
            for day in days where habit.isScheduled(on: day, calendar: calendar) && !habit.days.contains(CalendarDates.key(day, calendar: calendar)) && habit.checkIns?[CalendarDates.key(day, calendar: calendar)]?.status != .pending {
                if let value = event(id: "habit-"+habit.id.uuidString+"-"+CalendarDates.key(day, calendar: calendar), ownerID: habit.id, habit: true, day: day, minutes: minutes, title: "习惯提醒："+habit.title) { events.append(value) }
            }
        }
        for occurrence in taskOccurrences(from: now, through: last, calendar: calendar) where occurrence.completedAt == nil {
            guard let minutes = occurrence.task.reminderMinutes else { continue }
            let day = occurrence.displayDay.flatMap { Recurrence.date($0, calendar: calendar) } ?? occurrence.task.due
            guard let day, calendar.startOfDay(for: day) >= calendar.startOfDay(for: now), calendar.startOfDay(for: day) <= calendar.startOfDay(for: last) else { continue }
            if let value = event(id: "task-"+occurrence.id, ownerID: occurrence.task.id, habit: false, day: day, minutes: minutes, title: "任务提醒："+occurrence.task.title) { events.append(value) }
        }
        let previous = Dictionary(uniqueKeysWithValues: old.filter { $0.fireAt > now }.map { ($0.id, $0) })
        var libraries: [String: ReminderTextLibrary] = [:]
        for habit in habits { libraries["habit-" + habit.id.uuidString] = habit.messageLibrary ?? ReminderTextLibrary(texts: [habit.encouragement ?? ""]) }
        for task in tasks { libraries["task-" + task.id.uuidString] = task.messageLibrary ?? ReminderTextLibrary() }
        events.sort { $0.fireAt == $1.fireAt ? $0.id < $1.id : $0.fireAt < $1.fireAt }
        for i in events.indices {
            var library = libraries[events[i].ownerKey]!
            if let prior = previous[events[i].id], prior.fireAt == events[i].fireAt, let phraseID = prior.phraseID, library.reserve(phraseID), let phrase = library.phrases.first(where: { $0.id == phraseID }) {
                events[i].phraseID = phraseID; events[i].text = phrase.text
                events[i].registered = prior.registered && prior.text == phrase.text && prior.title == events[i].title
            } else if let phrase = library.draw() { events[i].phraseID = phrase.id; events[i].text = phrase.text }
            else { events[i].text = events[i].isHabit ? "打开小院，查看今天的习惯。" : "打开小院，查看这次的任务。" }
            libraries[events[i].ownerKey] = library
        }
        reminderAssignments = events
        return events
    }
}
