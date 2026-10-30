import Foundation

struct FocusInterval: Codable, Equatable {
    var beganAt: Date
    var endedAt: Date
    var seconds: TimeInterval { max(0, endedAt.timeIntervalSince(beganAt)) }
    var isValid: Bool { Self.validDate(beganAt) && Self.validDate(endedAt) && endedAt >= beganAt }
    static func validDate(_ date: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && (Date.distantPast...Date.distantFuture).contains(date)
    }
    func seconds(in interval: DateInterval) -> TimeInterval {
        max(0, min(endedAt, interval.end).timeIntervalSince(max(beganAt, interval.start)))
    }
    static func ordered(_ entries: [FocusInterval]) -> Bool {
        entries.allSatisfy(\.isValid) && zip(entries, entries.dropFirst()).allSatisfy { $0.endedAt <= $1.beganAt }
    }
    static func disjoint(_ first: [FocusInterval], _ second: [FocusInterval]) -> Bool {
        var a = 0, b = 0
        while a < first.count && b < second.count {
            if first[a].beganAt < second[b].endedAt && first[a].endedAt > second[b].beganAt { return false }
            if first[a].endedAt <= second[b].endedAt { a += 1 } else { b += 1 }
        }
        return true
    }
}

extension TimerRun {
    mutating func closeActiveSegment(at date: Date) {
        guard let resumedAt else { return }
        let amount = max(0, elapsed(at: date) - accumulated)
        let end = resumedAt.addingTimeInterval(amount)
        if amount > 0 { segments?.append(FocusInterval(beganAt: resumedAt, endedAt: end)) }
        accumulated += amount
        self.resumedAt = nil
    }
    mutating func resume(at date: Date) {
        guard resumedAt == nil else { return }
        let date = max(date, pausedAt ?? startedAt, segments?.last?.endedAt ?? startedAt)
        if let pausedAt, kind != .rest { pauseIntervals?.append(FocusInterval(beganAt: pausedAt, endedAt: date)) }
        pausedAt = nil
        resumedAt = date
    }
    func record(endingAt date: Date) -> FocusSession {
        var run = self
        run.closeActiveSegment(at: date)
        let complete = kind != .stopwatch && run.accumulated >= target
        let deadline = resumedAt.map { $0.addingTimeInterval(max(0, target - accumulated)) }
        let latest = max(startedAt, date, pausedAt ?? startedAt, resumedAt ?? startedAt, run.segments?.last?.endedAt ?? startedAt, run.pauseIntervals?.last?.endedAt ?? startedAt)
        let end = complete ? (run.segments?.last?.endedAt ?? deadline ?? pausedAt ?? latest) : latest
        if let pausedAt, kind != .rest, !complete { run.pauseIntervals?.append(FocusInterval(beganAt: pausedAt, endedAt: end)) }
        return FocusSession(id: id, taskID: taskID, title: taskTitle, kind: kind, date: end, seconds: run.accumulated,
                            occurrenceID: occurrenceID, beganAt: startedAt, endedAt: end, segments: run.segments,
                            pauseIntervals: kind == .rest ? [] : run.pauseIntervals)
    }
    var historyIsValid: Bool {
        guard pausedAt.map(FocusInterval.validDate) ?? true,
              pausedAt.map({ $0 >= startedAt && resumedAt == nil }) ?? true else { return false }
        for entries in [segments, pauseIntervals].compactMap({ $0 }) {
            guard FocusInterval.ordered(entries), entries.allSatisfy({ $0.beganAt >= startedAt }) else { return false }
        }
        if let segments {
            guard abs(segments.reduce(0) { $0 + $1.seconds } - accumulated) < 0.01,
                  resumedAt.map({ $0 >= (segments.last?.endedAt ?? startedAt) }) ?? true else { return false }
        }
        if let segments, let pauses = pauseIntervals {
            guard FocusInterval.disjoint(segments, pauses) else { return false }
            let latest = max(resumedAt ?? startedAt, pausedAt ?? startedAt, segments.last?.endedAt ?? startedAt)
            guard pauses.allSatisfy({ $0.endedAt <= latest }) else { return false }
        }
        return kind != .rest || (pauseIntervals?.isEmpty ?? true)
    }
}

extension FocusSession {
    var pauseCount: Int? { kind == .rest ? 0 : pauseIntervals?.count }
    var pausedSeconds: TimeInterval? { kind == .rest ? 0 : pauseIntervals?.reduce(0) { $0 + $1.seconds } }
    var wallSeconds: TimeInterval? { beganAt.flatMap { begin in endedAt.map { max(0, $0.timeIntervalSince(begin)) } } }
    var aiFeedbackIsEarlierVersion: Bool { lastEditedAt.map { $0 > (aiReviewedAt ?? .distantPast) } ?? false }
    func focusSeconds(in interval: DateInterval) -> TimeInterval {
        kind == .rest ? 0 : recordedSeconds(in: interval)
    }
    func recordedSeconds(in interval: DateInterval) -> TimeInterval {
        if let segments { return segments.reduce(0) { $0 + $1.seconds(in: interval) } }
        return date >= interval.start && date < interval.end ? seconds : 0
    }
    var isValid: Bool {
        guard seconds.isFinite, seconds > 0, seconds < 1_000_000_000_000,
              FocusInterval.validDate(date), [beganAt, endedAt, aiReviewedAt, lastEditedAt].compactMap({ $0 }).allSatisfy(FocusInterval.validDate),
              (notes?.count ?? 0) <= 20_000, (mood?.count ?? 0) <= 40,
              (moodSymbol?.count ?? 0) <= 80, (moodImage?.count ?? 0) <= 262_144,
              (aiFeedback?.count ?? 0) <= 4000 else { return false }
        if beganAt != nil || endedAt != nil { guard let beganAt, let endedAt, endedAt >= beganAt, endedAt == date else { return false } }
        for entries in [segments, pauseIntervals].compactMap({ $0 }) {
            guard let beganAt, let endedAt, FocusInterval.ordered(entries), entries.allSatisfy({ $0.beganAt >= beganAt && $0.endedAt <= endedAt }) else { return false }
        }
        if let segments {
            guard abs(segments.reduce(0) { $0 + $1.seconds } - seconds) < 0.01 else { return false }
            if let pauses = pauseIntervals {
                guard FocusInterval.disjoint(segments, pauses) else { return false }
            }
        }
        return kind != .rest || (pauseIntervals?.isEmpty ?? true)
    }
}

enum FocusTaskAction: String, CaseIterable, Identifiable {
    case none = "保持当前状态", complete = "完成", keepIncomplete = "保持未完成", reschedule = "改期"
    var id: String { rawValue }
}

struct TaskOccurrenceReschedule: Codable, Equatable, Identifiable {
    var id: String
    var taskID: UUID
    var scheduledDay: String
    var rescheduledDay: String
    var updatedAt: Date
    var isValid: Bool {
        validDayKey(rescheduledDay) && FocusInterval.validDate(updatedAt) &&
        TaskCompletionRecord(id: id, taskID: taskID, title: "task", scheduledDay: scheduledDay, completedAt: updatedAt).isValid
    }
}

extension AppData {
    func focusSeconds(in interval: DateInterval) -> TimeInterval { sessions.reduce(0) { $0 + $1.focusSeconds(in: interval) } }
    func focusTaskOccurrence(for session: FocusSession, calendar: Calendar) -> TaskOccurrence? {
        guard let taskID = session.taskID, let task = tasks.first(where: { $0.id == taskID }) else { return nil }
        guard task.scheduleRevisions != nil else { return TaskOccurrence(task: task, completedAt: task.completedAt) }
        guard let id = session.occurrenceID, let day = id.split(separator: "/").last.map(String.init),
              let date = Recurrence.date(day, calendar: calendar),
              let revision = Recurrence.revision(task.scheduleRevisions, on: date, calendar: calendar), revision.occurs(on: date, calendar: calendar) else { return nil }
        let reschedule = taskOccurrenceReschedules?.first { $0.id == id }
        let occurrence = TaskOccurrence(task: task, scheduledDay: day, revisionID: revision.id,
                                        completedAt: recurringTaskCompletions?.first { $0.id == id }?.completedAt,
                                        rescheduledDay: reschedule?.rescheduledDay)
        return occurrence.id == id ? occurrence : nil
    }
    mutating func editFocusSession(_ id: UUID, title: String, notes: String, mood: String?, moodSymbol: String?, moodImage: Data?, taskAction: FocusTaskAction = .none, rescheduleDate: Date? = nil, at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return false }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 1000 else { return false }
        var updated = self
        if taskAction != .none {
            guard sessions[index].kind != .rest, let occurrence = focusTaskOccurrence(for: sessions[index], calendar: calendar),
                  let taskIndex = tasks.firstIndex(where: { $0.id == occurrence.task.id }) else { return false }
            if let day = occurrence.scheduledDay {
                if updated.recurringTaskCompletions == nil { updated.recurringTaskCompletions = [] }
                if taskAction == .complete {
                    if !updated.recurringTaskCompletions!.contains(where: { $0.id == occurrence.id }) {
                        updated.recurringTaskCompletions!.append(TaskCompletionRecord(id: occurrence.id, taskID: occurrence.task.id, title: occurrence.task.title, scheduledDay: day, completedAt: date))
                    }
                } else {
                    updated.recurringTaskCompletions!.removeAll { $0.id == occurrence.id }
                    if taskAction == .reschedule {
                        guard let rescheduleDate, FocusInterval.validDate(rescheduleDate) else { return false }
                        let entry = TaskOccurrenceReschedule(id: occurrence.id, taskID: occurrence.task.id, scheduledDay: day,
                                                             rescheduledDay: CalendarDates.key(rescheduleDate, calendar: calendar), updatedAt: date)
                        if updated.taskOccurrenceReschedules == nil { updated.taskOccurrenceReschedules = [] }
                        updated.taskOccurrenceReschedules!.removeAll { $0.id == occurrence.id }
                        updated.taskOccurrenceReschedules!.append(entry)
                    }
                }
            } else if taskAction == .complete {
                updated.tasks[taskIndex].completedAt = updated.tasks[taskIndex].completedAt ?? date
            } else {
                updated.tasks[taskIndex].completedAt = nil
                if taskAction == .reschedule {
                    guard let rescheduleDate, FocusInterval.validDate(rescheduleDate) else { return false }
                    updated.tasks[taskIndex].due = rescheduleDate
                }
            }
        }
        let original = updated.sessions[index]
        updated.sessions[index].title = title
        updated.sessions[index].notes = notes.isEmpty ? nil : notes
        updated.sessions[index].mood = mood?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updated.sessions[index].moodSymbol = moodSymbol
        updated.sessions[index].moodImage = moodImage
        if original.title != title || original.notes != updated.sessions[index].notes || original.mood != updated.sessions[index].mood || original.moodSymbol != moodSymbol || original.moodImage != moodImage {
            updated.sessions[index].lastEditedAt = date
        }
        guard updated.sessions[index].isValid else { return false }
        self = updated
        return true
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
