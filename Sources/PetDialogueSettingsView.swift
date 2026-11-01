import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PetDialogueSettingsView: View {
    @ObservedObject var store: GardenStore
    @State private var event = PetDialogueEvent.click
    @State private var expression = PetExpression.calm
    @State private var search = ""
    @State private var editing: PetDialogueLine?
    @State private var imported: [PetDialogueLine] = []
    @State private var showingImport = false
    @State private var showingAI = false
    @State private var showingTemplate = false
    @State private var restoring = false
    @State private var error = ""
    private var settings: PetDialogueSettings { store.petDialogueSettings }
    private var lines: [PetDialogueLine] { settings.lines.filter { $0.event == event && (search.isEmpty || $0.text.localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        Card(title: "台词与表情", icon: "text.bubble") {
            Toggle("互动时显示台词", isOn: Binding(get: { settings.enabled }, set: { value in var next = settings; next.enabled = value; persist(next) }))
            Text("点击、专注、休息和收成时，从对应场景中选一句。每句与一个表情绑定，默认台词无需联网。").font(.caption).foregroundStyle(Palette.muted)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { eventPicker; expressionPicker }
                VStack(alignment: .leading, spacing: 10) { eventPicker; expressionPicker }
            }
            HStack(alignment: .center, spacing: 16) {
                PetDialogueExpressionPreview(expression: expression, skin: store.data.preferences.selectedPetSkin).frame(width: 62, height: 76)
                Text("新台词和纯文字导入使用以上场景、表情。完整台词文件会保留每句自己的设置。").font(.caption).foregroundStyle(Palette.muted)
            }
            TextField("搜索这个场景的台词", text: $search).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("搜索桌宠台词")
            PixelScrollView {
                LazyVStack(alignment: .leading, spacing: 9) {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(line.text).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 10) {
                                Text(line.expression.title).font(.caption).foregroundStyle(Palette.muted)
                                Spacer()
                                Button("预览") { store.previewPetDialogue(line) }.accessibilityLabel("预览台词：" + line.text)
                                Button("编辑") { editing = line }.accessibilityLabel("编辑台词：" + line.text)
                                Button("删除") { var next = settings; next.lines.removeAll { $0.id == line.id }; persist(next) }.accessibilityLabel("删除台词：" + line.text)
                            }.font(.caption)
                        }.padding(10).magicSurface(Palette.paper)
                    }
                    if lines.isEmpty { Text(search.isEmpty ? "这个场景还没有台词。" : "没有找到相符的台词。").font(.caption).foregroundStyle(Palette.muted) }
                }.padding(.trailing, 18)
            }.frame(minHeight: 100, maxHeight: 270)
            if let speech = store.petSpeech {
                HStack(alignment: .top, spacing: 12) {
                    PetDialogueExpressionPreview(expression: speech.line.expression, skin: store.data.preferences.selectedPetSkin).frame(width: 50, height: 62)
                    Text(speech.line.text).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                    Button("收起") { store.dismissPetSpeech(id: speech.id) }
                }.padding(10).magicSurface(Palette.paper)
            }
            ViewThatFits(in: .horizontal) {
                HStack { addButton; importButton; exportButton; Spacer(); Text("共 \(settings.lines.count) 条").font(.caption).foregroundStyle(Palette.muted) }
                VStack(alignment: .leading, spacing: 8) { HStack { addButton; importButton }; HStack { exportButton; Text("共 \(settings.lines.count) 条").font(.caption).foregroundStyle(Palette.muted) } }
            }
            Divider()
            Text("AI 候选（可选）").font(.headline)
            Text("只在点「生成候选」后联网；选中的句子才会加入台词。预设可在「AI 服务」和「表达与提示词」中统一选择。").font(.caption).foregroundStyle(Palette.muted)
            Text("API：" + (store.aiProfile(for: .petDialogue)?.name ?? "未分配") + " · 表达：" + (store.data.ai?.writingPresets?.first { $0.id == settings.writingPresetID }?.name ?? "默认表达")).font(.caption).foregroundStyle(Palette.muted)
            ViewThatFits(in: .horizontal) {
                HStack { aiButton; templateButton; Spacer(); restoreButton }
                VStack(alignment: .leading, spacing: 8) { HStack { aiButton; templateButton }; restoreButton }
            }
            if !error.isEmpty { Text(error).font(.callout).foregroundStyle(Palette.clay) }
        }
        .sheet(item: $editing) { line in PetDialogueLineEditor(store: store, line: line, onSave: saveLine) }
        .sheet(isPresented: $showingImport) { importPreview }
        .sheet(isPresented: $showingAI) {
            AIEncouragementView(store: store, feature: .petDialogue, subject: "触发场景：" + event.title + "；指定表情：" + expression.title, onAdd: { _ in }, onAddAccepted: { values in
                var next = settings
                do {
                    _ = try next.append(values.map { PetDialogueLine(event: event, expression: expression, text: $0) })
                    guard store.updatePetDialogue(next) else { error = store.error.isEmpty ? "台词未能保存，请重试。" : store.error; return false }
                    error = ""; return true
                } catch { self.error = error.localizedDescription; return false }
            })
        }
        .sheet(isPresented: $showingTemplate) { PetDialogueTemplateEditor(store: store) }
        .alert("恢复内置台词？", isPresented: $restoring) {
            Button("取消", role: .cancel) { }
            Button("恢复", role: .destructive) { var next = settings; next.lines = PetDialogueSettings.defaultLines; persist(next) }
        } message: { Text("当前台词会被替换。可先导出台词文件留存。") }
    }
    private var eventPicker: some View { PixelSelect(selection: $event, items: PetDialogueEvent.allCases.map { ($0, $0.title) }).frame(maxWidth: 240).accessibilityLabel("台词触发场景") }
    private var expressionPicker: some View { PixelSelect(selection: $expression, items: PetExpression.allCases.map { ($0, $0.title) }).frame(maxWidth: 180).accessibilityLabel("新台词表情") }
    private var addButton: some View { Button("添加台词") { editing = PetDialogueLine(event: event, expression: expression, text: "") }.buttonStyle(PixelButtonStyle(primary: true)) }
    private var importButton: some View { Button("导入台词") { importFile() }.buttonStyle(PixelButtonStyle()) }
    private var exportButton: some View { Button("导出台词") { exportFile() }.buttonStyle(PixelButtonStyle()) }
    private var aiButton: some View { Button("生成候选") { showingAI = true }.buttonStyle(PixelButtonStyle()) }
    private var templateButton: some View { Button("台词提示词") { showingTemplate = true }.buttonStyle(PixelButtonStyle()) }
    private var restoreButton: some View { Button("恢复内置台词") { restoring = true }.buttonStyle(PixelButtonStyle()) }
    private func persist(_ value: PetDialogueSettings) {
        error = store.updatePetDialogue(value) ? "" : (store.error.isEmpty ? "台词设置未能保存，请重试。" : store.error)
    }
    private func saveLine(_ line: PetDialogueLine) -> Bool {
        var next = settings
        if let index = next.lines.firstIndex(where: { $0.id == line.id }) { next.lines[index] = line }
        else { do { _ = try next.append([line]) } catch { self.error = error.localizedDescription; return false } }
        guard store.updatePetDialogue(next) else { error = store.error.isEmpty ? "台词未能保存，请重试。" : store.error; return false }
        error = ""; return true
    }
    private func importFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, .json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { imported = try PetDialogueFile.read(url, event: event, expression: expression); showingImport = true; error = "" }
        catch { self.error = error.localizedDescription }
    }
    private func exportFile() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "桌宠台词.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try PetDialogueFile.encode(settings.lines, structured: true).write(to: url, options: .atomic); error = ""; store.message = "台词已导出。" }
        catch { self.error = "导出失败：" + error.localizedDescription }
    }
    private var importPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入预览 · \(imported.count) 条").font(.title2)
            Text("将追加到现有台词；内容、场景和表情完全相同的句子会自动跳过。").font(.caption).foregroundStyle(Palette.muted)
            PixelScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(imported) { line in VStack(alignment: .leading, spacing: 4) { Text(line.event.title + " · " + line.expression.title).font(.caption).foregroundStyle(Palette.muted); Text(line.text).font(.callout) }.padding(8) }
                }.padding(.trailing, 18)
            }.frame(height: 300)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { showingImport = false }
                Spacer()
                Button("追加台词") {
                    var next = settings
                    do {
                        let count = try next.append(imported)
                        guard store.updatePetDialogue(next) else { error = store.error.isEmpty ? "导入未能保存，请重试。" : store.error; return }
                        error = ""; showingImport = false; store.message = "已加入 \(count) 条台词。"
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(PixelButtonStyle(primary: true))
            }
        }.padding(24).frame(width: 440).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

struct PetDialogueExpressionPreview: View {
    var expression: PetExpression
    var skin: PetSkin
    var body: some View {
        let pose = ChibiPose(phase: 0, time: 0, elapsed: 2, expression: expression.rawValue, expressionActive: true)
        let source = skin == .casual ? ChibiSkins.frame(for: pose) : ChibiImages.images[pose.imageName]
        if let image = source {
            GeometryReader { geometry in
                Image(nsImage: image).resizable().interpolation(.none)
                    .frame(width: geometry.size.width, height: geometry.size.width * image.size.height / image.size.width)
                    .frame(width: geometry.size.width, height: geometry.size.width * 0.86, alignment: .top).clipped()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }.accessibilityLabel("表情预览：" + expression.title)
        } else { Text(expression.title).font(.caption).foregroundStyle(Palette.muted) }
    }
}

private struct PetDialogueLineEditor: View {
    @ObservedObject var store: GardenStore
    @State var line: PetDialogueLine
    var onSave: (PetDialogueLine) -> Bool
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑台词").font(.title2)
            PixelSelect(selection: $line.event, items: PetDialogueEvent.allCases.map { ($0, $0.title) }).accessibilityLabel("台词场景")
            HStack { PetDialogueExpressionPreview(expression: line.expression, skin: store.data.preferences.selectedPetSkin).frame(width: 90, height: 105); PixelSelect(selection: $line.expression, items: PetExpression.allCases.map { ($0, $0.title) }).accessibilityLabel("台词表情") }
            TextField("写一句这个场景会说的话", text: $line.text, axis: .vertical).lineLimit(3...6).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("台词内容")
            Text("\(line.text.count) / 160 字").font(.caption).foregroundStyle(line.text.count > 160 ? Palette.clay : Palette.muted)
            Button("预览台词与表情") { store.previewPetDialogue(line) }.disabled(!line.isValid)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { dismiss() }; Spacer()
                Button("保存") {
                    line.text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if onSave(line) { dismiss() } else { error = store.error.isEmpty ? "台词未能保存，请重试。" : store.error }
                }.buttonStyle(PixelButtonStyle(primary: true)).disabled(!line.isValid)
            }
        }.padding(24).frame(width: 440).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

private struct PetDialogueTemplateEditor: View {
    @ObservedObject var store: GardenStore
    @State private var template = ""
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("桌宠台词提示词").font(.title2)
            Text("继承已选表达预设的人物、用户与附加要求。场景和表情通过「事项」填入。").font(.caption).foregroundStyle(Palette.muted)
            TextEditor(text: $template).scrollContentBackground(.hidden).padding(8).frame(height: 260).magicSurface(Palette.card).accessibilityLabel("桌宠台词提示词")
            Text("可用占位符：{{事项}}、{{数量}}、{{长度}}、{{人物设定}}、{{用户设定}}、{{附加要求}}").font(.caption).foregroundStyle(Palette.muted)
            if let problem = AIPromptPurpose.encouragement.problem(in: template) { Text(problem).font(.caption).foregroundStyle(Palette.clay) }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("恢复默认") { template = PetDialogueSettings.defaultGenerationTemplate }
                Spacer(); Button("取消") { dismiss() }
                Button("保存") {
                    var next = store.petDialogueSettings; next.generationTemplate = template == PetDialogueSettings.defaultGenerationTemplate ? nil : template
                    if store.updatePetDialogue(next) { dismiss() } else { error = store.error.isEmpty ? "提示词未能保存，请重试。" : store.error }
                }.buttonStyle(PixelButtonStyle(primary: true)).disabled(AIPromptPurpose.encouragement.problem(in: template) != nil)
            }
        }.padding(24).frame(width: 500).magicSurface(Palette.paper, strong: true).magicControls().onAppear { template = store.petDialogueSettings.generationTemplate ?? PetDialogueSettings.defaultGenerationTemplate }
    }
}
