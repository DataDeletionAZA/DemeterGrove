import Foundation

enum HabitReviewStatus: String, Codable {
    case pending, approved, rejected
    var title: String {
        switch self { case .pending: return "待审核"; case .approved: return "已通过"; case .rejected: return "待补充" }
    }
}

struct HabitCheckIn: Codable, Equatable {
    var text: String
    var image: Data?
    var submittedAt: Date
    var status: HabitReviewStatus = .pending
    var reviewedAt: Date? = nil
    var feedback: String? = nil
    var hasEvidence: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil }
    var isValid: Bool {
        hasEvidence && text.count <= 4000 && (image.map { !$0.isEmpty && $0.count <= 2_097_152 } ?? true) &&
        submittedAt.timeIntervalSince1970.isFinite &&
        (reviewedAt.map { $0.timeIntervalSince1970.isFinite && $0 >= submittedAt } ?? (status == .pending)) &&
        (status != .pending || reviewedAt == nil) && (feedback?.count ?? 0) <= 1000
    }
}

struct HabitProgress: Codable, Equatable {
    var days: Set<String> = []
    var rewardedDays: Set<String> = []
    var milestones: Set<Int> = []
    var pastMilestones: Set<Int> = []
    static let dailyCoins = 1
    static let milestones = [7, 30, 66, 90]
    static func rewardName(_ day: Int) -> String {
        switch day { case 7: return "星露胡萝卜种子 ×3"; case 30: return "深绿旅行袍"; case 66: return "繁盛药剂"; case 90: return "紫灰冬日袍"; default: return "" }
    }
    var isValid: Bool {
        days.allSatisfy(validDayKey) && rewardedDays.isSubset(of: days) && milestones.isSubset(of: Set(Self.milestones)) &&
        milestones.allSatisfy { $0 <= days.count } && pastMilestones.isSubset(of: Set(Self.milestones)) &&
        pastMilestones.allSatisfy { $0 <= days.count } && pastMilestones.isDisjoint(with: milestones)
    }
}

func validDayKey(_ key: String) -> Bool {
    guard key.count == 10 else { return false }
    let parts = key.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), year > 0,
          let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
    return dayKey(date) == key
}

extension Habit {
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (reminderMinutes.map { (0..<1440).contains($0) } ?? true) &&
        (encouragement?.count ?? 0) <= 300 && Recurrence.valid(scheduleRevisions) && (messageLibrary?.isValid ?? true) && days.allSatisfy(validDayKey) &&
        (checkIns ?? [:]).allSatisfy { key, entry in
            validDayKey(key) && entry.isValid &&
            (entry.status != .approved || days.contains(key))
        }
    }
}

struct HabitReward: Equatable {
    var coins: Int
    var milestones: [Int]
}

extension AppData {
    var habitDays: Set<String> {
        habits.reduce(into: habitProgress?.days ?? []) { $0.formUnion($1.days) }
    }
    mutating func submitHabitEvidence(_ id: UUID, date: Date, text: String, image: Data?, now: Date = Date()) -> Bool {
        guard Calendar.current.isDate(date, inSameDayAs: now), let i = habits.firstIndex(where: { $0.id == id }) else { return false }
        let key = dayKey(now)
        guard !habits[i].days.contains(key) else { return false }
        let entry = HabitCheckIn(text: text.trimmingCharacters(in: .whitespacesAndNewlines), image: image, submittedAt: now)
        guard entry.isValid else { return false }
        if habits[i].checkIns == nil { habits[i].checkIns = [:] }
        habits[i].checkIns?[key] = entry
        return true
    }
    mutating func cancelHabitSubmission(_ id: UUID, date: Date, now: Date = Date()) -> Bool {
        guard Calendar.current.isDate(date, inSameDayAs: now),
              let i = habits.firstIndex(where: { $0.id == id }),
              habits[i].checkIns?[dayKey(now)]?.status == .pending else { return false }
        habits[i].checkIns?.removeValue(forKey: dayKey(now))
        return true
    }
    mutating func applyHabitReview(_ id: UUID, day: String, approved: Bool, feedback: String, now: Date = Date()) -> HabitReward? {
        guard day == dayKey(now), feedback.count <= 1000,
              let i = habits.firstIndex(where: { $0.id == id }),
              var entry = habits[i].checkIns?[day], entry.isValid,
              entry.status == .pending, Calendar.current.isDate(entry.submittedAt, inSameDayAs: now), now >= entry.submittedAt else { return nil }
        entry.status = approved ? .approved : .rejected
        entry.reviewedAt = now
        entry.feedback = feedback
        habits[i].checkIns?[day] = entry
        guard approved else { return HabitReward(coins: 0, milestones: []) }
        let before = habitDays.count
        var progress = habitProgress ?? HabitProgress(days: habitDays, pastMilestones: Set(HabitProgress.milestones.filter { $0 <= before }))
        progress.days.formUnion(habitDays)
        habits[i].days.insert(day)
        progress.days.insert(day)
        guard !progress.rewardedDays.contains(day), before < progress.days.count else {
            habitProgress = progress
            return HabitReward(coins: 0, milestones: [])
        }
        progress.rewardedDays.insert(day)
        let milestones = HabitProgress.milestones.filter { before < $0 && progress.days.count >= $0 && !progress.milestones.contains($0) && !progress.pastMilestones.contains($0) }
        progress.milestones.formUnion(milestones)
        for milestone in milestones {
            switch milestone {
            case 7: garden.cropSeeds[Crop.starlightCarrot.rawValue, default: 0] += 3
            case 30: garden.economy.owned.insert("travel")
            case 66: garden.economy.finds["bloom", default: 0] += 1
            case 90: garden.economy.owned.insert("winter")
            default: break
            }
        }
        let coins = HabitProgress.dailyCoins
        garden.coins += coins
        habitProgress = progress
        return HabitReward(coins: coins, milestones: milestones)
    }
    mutating func removeHabit(_ id: UUID) {
        var progress = habitProgress ?? HabitProgress(days: habitDays, pastMilestones: Set(HabitProgress.milestones.filter { $0 <= habitDays.count }))
        progress.days.formUnion(habitDays)
        habitProgress = progress
        habits.removeAll { $0.id == id }
    }
}
