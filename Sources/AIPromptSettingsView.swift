import SwiftUI
import AppKit

struct AIWritingPresetPicker: View {
    @ObservedObject var store: GardenStore
    var feature: AIFeature
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("表达预设").font(.callout)
                PixelSelect(selection: Binding(get: { feature == .petDialogue ? store.data.ai?.writingPresets?.first(where:{$0.id == store.data.petDialogue?.writingPresetID})?.id:store.data.ai?.writingAssignments?[feature.rawValue] }, set: { id in
                    if feature == .petDialogue {
                        error = store.setPetDialogueAIPresets(profileID:store.data.petDialogue?.aiProfileID,writingPresetID:id) ? "":"预设选择未能保存。"
                        return
                    }
                    let previous = store.data.ai
                    var next = previous ?? AISettings()
                    if next.writingAssignments == nil { next.writingAssignments = [:] }
                    next.writingAssignments?[feature.rawValue] = id
                    store.data.ai = next
                    if store.save() { error = "" } else { store.data.ai = previous; error = "预设选择未能保存。" }
                }), items: [(nil as UUID?, "默认表达")] + (store.data.ai?.writingPresets ?? []).map { (Optional($0.id), $0.name) })
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
        }
    }
}

struct AIPromptSettingsView: View {
    @ObservedObject var store: GardenStore
    @State private var draft = AIWritingPreset()
    @State private var purpose = AIPromptPurpose.encouragement
    @State private var error = ""
    @State private var preview = false
    private var presets: [AIWritingPreset] { store.data.ai?.writingPresets ?? [] }
    private var saved: Bool { presets.contains { $0.id == draft.id } }
    private var template: Binding<String> {
        Binding(get: { draft.template(for: purpose) }, set: { draft.templates[purpose.rawValue] = $0 })
    }
    var body: some View {
        Card(title: "表达与提示词", icon: "text.bubble") {
            HStack {
                PixelSelect(selection: Binding(get: { saved ? Optional(draft.id) : nil }, set: { id in
                    draft = presets.first { $0.id == id } ?? AIWritingPreset(); error = ""
                }), items: [(nil as UUID?, "新预设")] + presets.map { (Optional($0.id), $0.name) })
                Button("新建") { draft = AIWritingPreset(); error = "" }
            }
            TextField("预设名称", text: $draft.name)
            textArea("人物设定（可选）", text: $draft.character, height: 85)
            textArea("用户设定（可选）", text: $draft.userProfile, height: 70)
            textArea("附加要求（可选）", text: $draft.additionalRequirements, height: 85)
            PixelSelect(selection: $purpose, items: AIPromptPurpose.allCases.map { ($0, $0.title) })
            textArea("提示词", text: template, height: 230)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], alignment: .leading, spacing: 6) {
                ForEach(purpose.tokens, id: \.self) { name in
                    Button("插入" + name) { insert("{{" + name + "}}") }.font(.caption)
                }
            }
            if draft.character.count > 4000 || draft.userProfile.count > 4000 || draft.additionalRequirements.count > 4000 { Text("人物设定、用户设定和附加要求各最多4000字。").font(.caption).foregroundStyle(Palette.clay) }
            if let problem = purpose.problem(in: template.wrappedValue) { Text(problem).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("恢复这页默认") { draft.templates[purpose.rawValue] = nil }
                Button(preview ? "收起预览" : "预览") { preview.toggle() }
                Spacer()
                Button("保存预设") { save() }.buttonStyle(PixelButtonStyle(primary: true)).disabled(!draft.isValid || store.storageLocked)
                if saved { Button("删除") { remove() } }
            }
            if preview {
                Text(draft.rendered(for: purpose, values: ["事项": "阅读", "数量": "5", "长度": AITextLength.medium.instruction, "材料": "阅读后写下的简短笔记", "专注记录": "阅读，专注25分钟，暂停0次。感想：整理出了重点。"], additional: ""))
                    .font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12).magicSurface(Palette.card)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            Divider()
            ForEach(AIFeature.allCases) { feature in
                VStack(alignment: .leading, spacing: 5) {
                    Text(feature.title).font(.callout).foregroundStyle(Palette.goldLight)
                    AIWritingPresetPicker(store: store, feature: feature)
                }
            }
        }.textFieldStyle(PixelTextFieldStyle()).buttonStyle(PixelButtonStyle())
            .onAppear { draft = presets.first ?? AIWritingPreset() }
    }
    private func textArea(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.callout)
            TextEditor(text: text).scrollContentBackground(.hidden).padding(7).frame(height: height).magicSurface(Palette.card).accessibilityLabel(title)
        }
    }
    private func insert(_ value: String) {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.string == template.wrappedValue {
            editor.insertText(value, replacementRange: editor.selectedRange())
        } else { template.wrappedValue += value }
    }
    private func save() {
        let previous = store.data.ai
        var next = previous ?? AISettings()
        var values = next.writingPresets ?? []
        if let index = values.firstIndex(where: { $0.id == draft.id }) { values[index] = draft } else { values.append(draft) }
        next.writingPresets = values
        guard next.isValid else { error = "请检查预设名称、提示词与占位符。"; return }
        store.data.ai = next
        if store.save() { error = ""; store.message = "表达预设已保存" }
        else { store.data.ai = previous; error = "表达预设未能保存。" }
    }
    private func remove() {
        let previous = store.data.ai
        var next = previous ?? AISettings()
        next.writingPresets?.removeAll { $0.id == draft.id }
        next.writingAssignments = next.writingAssignments?.filter { $0.value != draft.id }
        store.data.ai = next
        if store.save() { draft = next.writingPresets?.first ?? AIWritingPreset(); error = "" }
        else { store.data.ai = previous; error = "预设未能删除。" }
    }
}
