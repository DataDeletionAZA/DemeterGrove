import Foundation

enum AIFeature: String, Codable, CaseIterable, Identifiable {
    case taskEncouragement, habitEncouragement, habitReview, focusReview, petDialogue
    var id: String { rawValue }
    var title: String {
        switch self { case .taskEncouragement:return "任务激励语";case .habitEncouragement:return "习惯激励语";case .habitReview:return "习惯审核";case .focusReview:return "专注评价";case .petDialogue:return "桌宠台词" }
    }
}

enum AIReasoningEffort:String,Codable,CaseIterable,Identifiable {
    case none,low,medium,high,xhigh,max
    var id:String {rawValue}
    var title:String {
        switch self {case .none:return "无（none）";case .low:return "低（low）";case .medium:return "中（medium）";case .high:return "高（high）";case .xhigh:return "更高（xhigh）";case .max:return "最高（max）"}
    }
}

struct AIHabitReviewResult:Codable,Equatable {
    var approved:Bool
    var feedback:String
}

enum AIFormat: String, Codable, CaseIterable {
    case responses = "Responses", chatCompletions = "Chat Completions"
}

struct AIProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var baseURL = "https://api.openai.com/v1"
    var model = ""
    var format: AIFormat = .responses
    var reasoningEffort: AIReasoningEffort? = nil
    var isValid: Bool {
        !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && name.count<=80 &&
        !model.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && model.count<=200 &&
        Self.secureURL(baseURL) != nil
    }
    static func secureURL(_ value:String)->URL? {
        guard value.count<=2048,!value.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}),
              var parts=URLComponents(string:value.trimmingCharacters(in:.whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https",parts.host?.isEmpty == false,
              parts.user == nil,parts.password == nil,parts.query == nil,parts.fragment == nil,
              parts.port.map({(1...65535).contains($0)}) ?? true else{return nil}
        parts.scheme="https"
        return parts.url
    }
    func endpoint(_ resource:String)->URL? {
        guard ["models","responses","chat/completions"].contains(resource),let base=Self.secureURL(baseURL) else{return nil}
        return base.appendingPathComponent(resource)
    }
    var normalized:AIProfile {
        var value=self
        value.name=name.trimmingCharacters(in:.whitespacesAndNewlines)
        value.model=model.trimmingCharacters(in:.whitespacesAndNewlines)
        value.baseURL=baseURL.trimmingCharacters(in:.whitespacesAndNewlines)
        return value
    }
}

struct AISettings: Codable, Equatable {
    var profiles: [AIProfile] = []
    var assignments: [String:UUID] = [:]
    var writingPresets: [AIWritingPreset]? = nil
    var writingAssignments: [String:UUID]? = nil
    var isValid: Bool {
        let ids = Set(profiles.map(\.id))
        let writing = writingPresets ?? []
        let writingIDs = Set(writing.map(\.id))
        return profiles.count<=100 && ids.count == profiles.count && profiles.allSatisfy(\.isValid) &&
            assignments.allSatisfy { AIFeature(rawValue:$0.key) != nil && ids.contains($0.value) } &&
            writing.count<=100 && writingIDs.count == writing.count && writing.allSatisfy(\.isValid) &&
            (writingAssignments ?? [:]).allSatisfy { AIFeature(rawValue:$0.key) != nil && writingIDs.contains($0.value) }
    }
    func profile(for feature:AIFeature) -> AIProfile? {
        profiles.first { $0.id == assignments[feature.rawValue] }
    }
    func writing(for feature: AIFeature) -> AIWritingPreset {
        (writingPresets ?? []).first { $0.id == writingAssignments?[feature.rawValue] } ?? .standard
    }
}
