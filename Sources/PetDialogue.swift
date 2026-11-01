import Foundation

enum PetDialogueEvent: String, Codable, CaseIterable, Identifiable {
    case click, dragEnd, focusStart, focusEnd, restStart, restEnd, harvest, craft
    var id: String { rawValue }
    var title: String {
        switch self {
        case .click: return "点击桌宠"
        case .dragEnd: return "拖动后落地"
        case .focusStart: return "开始专注"
        case .focusEnd: return "结束专注"
        case .restStart: return "开始休息"
        case .restEnd: return "结束休息"
        case .harvest: return "收获作物"
        case .craft: return "完成制作"
        }
    }
}

enum PetExpression: Int, Codable, CaseIterable, Identifiable {
    case calm = 0, sideways = 1, eyesClosed = 2, smile = 3
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .calm: return "平视"
        case .sideways: return "侧目"
        case .eyesClosed: return "闭眼蹙眉"
        case .smile: return "微笑"
        }
    }
}

struct PetDialogueLine: Codable, Equatable, Identifiable {
    var id = UUID()
    var event: PetDialogueEvent
    var expression: PetExpression
    var text: String
    static let maximumLength = 160
    var isValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= Self.maximumLength &&
        !text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }
}

struct PetDialogueSettings: Codable, Equatable {
    var enabled = true
    var lines: [PetDialogueLine] = Self.defaultLines
    var aiProfileID: UUID? = nil
    var writingPresetID: UUID? = nil
    var generationTemplate: String? = nil
    static let defaultGenerationTemplate = """
    为桌宠写{{数量}}条可直接说出口的短句，触发场景与表情：{{事项}}
    每条长度：{{长度}}。每条最多160字，优先用一两句简短自然的话。
    人物设定：{{人物设定}}
    用户设定：{{用户设定}}
    附加要求：{{附加要求}}
    话语应回应这个场景，并与指定表情相符。人物设定为空时使用自然、中性的口吻，不预设姓名、身份或亲密关系。不必把每句话都写成鼓励或建议，不编造用户的经历、身体状况和心理状态。没有指定语言时使用中文。
    """
    static let maximumLines = 1000
    var isValid: Bool { lines.count <= Self.maximumLines && Set(lines.map(\.id)).count == lines.count && lines.allSatisfy(\.isValid) && (generationTemplate.map { AIPromptPurpose.encouragement.problem(in: $0) == nil } ?? true) }
    static let defaultLines: [PetDialogueLine] = [
        .init(event: .click, expression: .calm, text: "我在。有什么事？"),
        .init(event: .click, expression: .sideways, text: "嗯？这次又发现了什么？"),
        .init(event: .dragEnd, expression: .sideways, text: "好了，这个位置就可以。"),
        .init(event: .dragEnd, expression: .eyesClosed, text: "站稳了。下次慢一些。"),
        .init(event: .focusStart, expression: .calm, text: "从眼前这一件开始吧。"),
        .init(event: .focusStart, expression: .smile, text: "开始了。我在这里陪你。"),
        .init(event: .focusEnd, expression: .smile, text: "这一段已经记下了。"),
        .init(event: .focusEnd, expression: .calm, text: "先舒展一下，再想下一步。"),
        .init(event: .restStart, expression: .calm, text: "休息一会儿，松松肩膀。"),
        .init(event: .restStart, expression: .calm, text: "这几分钟，留给自己。"),
        .init(event: .restEnd, expression: .calm, text: "休息结束了。接下来由你决定。"),
        .init(event: .restEnd, expression: .smile, text: "回来了。慢慢来。"),
        .init(event: .harvest, expression: .smile, text: "长得不错。收起来吧。"),
        .init(event: .harvest, expression: .calm, text: "又多了一份收成。"),
        .init(event: .craft, expression: .smile, text: "做成了，看看这次的成果。"),
        .init(event: .craft, expression: .calm, text: "完成了，已经放好了。")
    ]
    mutating func append(_ incoming: [PetDialogueLine]) throws -> Int {
        guard incoming.allSatisfy(\.isValid) else { throw PetDialogueIssue.invalid }
        var next = lines
        for line in incoming where !next.contains(where: { $0.event == line.event && $0.expression == line.expression && $0.text == line.text }) {
            var value = line
            if next.contains(where: { $0.id == value.id }) { value.id = UUID() }
            next.append(value)
        }
        guard next.count <= Self.maximumLines else { throw PetDialogueIssue.tooMany }
        let added = next.count - lines.count
        lines = next
        return added
    }
}

struct PetSpeech: Equatable, Identifiable {
    var id = UUID()
    var line: PetDialogueLine
    var beganAt: Date
    var duration: TimeInterval { min(14, max(3.5, Double(line.text.count) / 8 + 2)) }
}

struct PetDialoguePicker {
    private var lastIDs: [PetDialogueEvent: UUID] = [:]
    private var lastTimes: [PetDialogueEvent: Date] = [:]
    mutating func choose(event: PetDialogueEvent, settings: PetDialogueSettings, at date: Date) -> PetDialogueLine? {
        guard settings.enabled, settings.isValid,
              lastTimes[event].map({ date.timeIntervalSince($0) >= 3 }) ?? true else { return nil }
        let choices = settings.lines.filter { $0.event == event }
        let alternatives = choices.filter { $0.id != lastIDs[event] }
        guard let line = (alternatives.isEmpty ? choices : alternatives).randomElement() else { return nil }
        lastIDs[event] = line.id; lastTimes[event] = date
        return line
    }
}

enum PetDialogueIssue: LocalizedError {
    case invalid, tooMany, fileTooLarge, empty, encoding
    var errorDescription: String? {
        switch self {
        case .invalid: return "每条台词需要内容，最多160字；请检查文件中的场景和表情。"
        case .tooMany: return "台词总数最多1000条。"
        case .fileTooLarge: return "台词文件超过1 MB，请分成较小的文件再导入。"
        case .empty: return "文件中没有可导入的台词。"
        case .encoding: return "无法读取文字，请将文件另存为UTF-8纯文本后重试。"
        }
    }
}

enum PetDialogueFile {
    static let maximumBytes = 1_000_000
    static func read(_ url: URL, event: PetDialogueEvent, expression: PetExpression) throws -> [PetDialogueLine] {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw PetDialogueIssue.fileTooLarge }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= maximumBytes else { throw PetDialogueIssue.fileTooLarge }
        return try decode(bytes, structured: url.pathExtension.lowercased() == "json", event: event, expression: expression)
    }
    static func decode(_ bytes: Data, structured: Bool, event: PetDialogueEvent, expression: PetExpression) throws -> [PetDialogueLine] {
        guard bytes.count <= maximumBytes else { throw PetDialogueIssue.fileTooLarge }
        let lines: [PetDialogueLine]
        if structured {
            do { lines = try JSONDecoder().decode([PetDialogueLine].self, from: bytes) }
            catch { throw PetDialogueIssue.invalid }
        }
        else {
            guard let text = String(data: bytes, encoding: .utf8) else { throw PetDialogueIssue.encoding }
            lines = text.trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}")).components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.map { PetDialogueLine(event: event, expression: expression, text: $0) }
        }
        guard !lines.isEmpty else { throw PetDialogueIssue.empty }
        guard lines.count <= PetDialogueSettings.maximumLines else { throw PetDialogueIssue.tooMany }
        guard lines.allSatisfy(\.isValid), Set(lines.map(\.id)).count == lines.count else { throw PetDialogueIssue.invalid }
        return lines
    }
    static func encode(_ lines: [PetDialogueLine], structured: Bool) throws -> Data {
        guard lines.count <= PetDialogueSettings.maximumLines, lines.allSatisfy(\.isValid), Set(lines.map(\.id)).count == lines.count else { throw PetDialogueIssue.invalid }
        if structured {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(lines)
            guard bytes.count <= maximumBytes else { throw PetDialogueIssue.fileTooLarge }
            return bytes
        }
        let bytes = Data(lines.map(\.text).joined(separator: "\n").utf8)
        guard bytes.count <= maximumBytes else { throw PetDialogueIssue.fileTooLarge }
        return bytes
    }
}
