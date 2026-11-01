import Foundation

enum AITextLength: String, Codable, CaseIterable {
    case short = "短", medium = "中", long = "长"
    var instruction: String {
        switch self {
        case .short: return "一句话；双语时译文另附。"
        case .medium: return "二至四句，中文约50至100字，其他语言约40至70词；译文不计入原文长度。"
        case .long: return "一小段话，中文约150至250字，其他语言约100至150词；译文不计入原文长度。"
        }
    }
    var batchSize: Int { self == .short ? 20 : self == .medium ? 10 : 5 }
    func outputLimit(count: Int) -> Int { min(16000, 400 + count * (self == .short ? 300 : self == .medium ? 750 : 2000)) }
}

enum AIPromptPurpose: String, CaseIterable, Codable {
    case encouragement, habitReview, focusReview
    var title: String {
        switch self { case .encouragement: return "激励语"; case .habitReview: return "习惯审核"; case .focusReview: return "专注评价" }
    }
    init(feature: AIFeature) {
        switch feature { case .taskEncouragement, .habitEncouragement, .petDialogue: self = .encouragement; case .habitReview: self = .habitReview; case .focusReview: self = .focusReview }
    }
    var tokens: [String] {
        let common = ["人物设定", "用户设定", "附加要求"]
        switch self { case .encouragement: return ["事项", "数量", "长度"] + common; case .habitReview: return ["事项", "材料"] + common; case .focusReview: return ["专注记录"] + common }
    }
    var requiredTokens: [String] {
        switch self { case .encouragement: return ["事项", "数量", "长度", "附加要求"]; case .habitReview: return ["事项", "材料", "附加要求"]; case .focusReview: return ["专注记录", "附加要求"] }
    }
    var defaultTemplate: String {
        switch self {
        case .encouragement: return """
        为以下事项写{{数量}}条日常激励语：{{事项}}
        每条长度：{{长度}}
        人物设定：{{人物设定}}
        用户设定：{{用户设定}}
        附加要求：{{附加要求}}
        语言与格式遵循附加要求；没有指定语言时使用中文。表达自然、有具体内容，避免重复、空泛口号和说教。尊重用户状态，不制造欠债感。
        """
        case .habitReview: return """
        审核这项习惯的当日材料：{{事项}}
        材料：{{材料}}
        人物设定：{{人物设定}}
        用户设定：{{用户设定}}
        附加要求：{{附加要求}}
        采用宽松、合理的标准。相关照片或具体文字叙述均可作为完成记录，不因没有照片拒绝具体文字。不要要求时长真实性证明，不要求证明每个动作。无关材料、只有“完成了”等空泛文字需要补充。不要作医学剂量或用药安全判断。
        根据材料决定是否通过，并给出回应本次行为的简短评语；不足时温和说明可补充什么。评语可采用人物口吻，人物口吻不改变判断依据。
        """
        case .focusReview: return """
        根据这份专注记录给出具体、适度的反馈：{{专注记录}}
        人物设定：{{人物设定}}
        用户设定：{{用户设定}}
        附加要求：{{附加要求}}
        优先回应用户感想、所做事项和实际时长。暂停与休息不自动等于懈怠，不编造没有记录的原因或进展。信息标为未知时保留不确定性。可给出一个轻量建议，不作强制要求。没有指定语言时使用中文。
        """
        }
    }
    func problem(in template: String) -> String? {
        guard !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.count <= 12000 else { return "提示词不能为空，最多12000字。" }
        let regex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        let names = matches.compactMap { Range($0.range(at: 1), in: template).map { String(template[$0]) } }
        if let unknown = names.first(where: { !tokens.contains($0) }) { return "无法识别占位符：" + unknown }
        if let missing = requiredTokens.first(where: { !names.contains($0) }) { return "未插入占位符：" + missing }
        return nil
    }
}

struct AIWritingPreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = "默认表达"
    var character = ""
    var userProfile = ""
    var additionalRequirements = ""
    var templates: [String: String] = [:]
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        character.count <= 4000 && userProfile.count <= 4000 && additionalRequirements.count <= 4000 &&
        templates.allSatisfy { key, value in AIPromptPurpose(rawValue: key).map { $0.problem(in: value) == nil } ?? false }
    }
    func template(for purpose: AIPromptPurpose) -> String { templates[purpose.rawValue] ?? purpose.defaultTemplate }
    func rendered(for purpose: AIPromptPurpose, values: [String: String], additional: String = "") -> String {
        var replacements = values
        replacements["人物设定"] = character
        replacements["用户设定"] = userProfile
        replacements["附加要求"] = [additionalRequirements, additional].filter { !$0.isEmpty }.joined(separator: "\n")
        let template = template(for: purpose)
        let regex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
        var result = template
        for match in regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed() {
            guard let tokenRange = Range(match.range(at: 1), in: template), let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: replacements[String(template[tokenRange])] ?? "")
        }
        return result
    }
    static var standard: AIWritingPreset { AIWritingPreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!) }
}
