import Foundation

@main enum PetDialogueChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: @autoclosure () -> Bool) { assert(value()); count += 1 }
        func rejected(_ body: () throws -> Void) { do { try body(); assertionFailure("Expected rejection") } catch { count += 1 } }
        let now = Date()
        let defaults = PetDialogueSettings()
        check(defaults.isValid)
        check(Set(defaults.lines.map(\.event)) == Set(PetDialogueEvent.allCases))
        check(Set(defaults.lines.map(\.expression)) == Set(PetExpression.allCases))
        check(AIPromptPurpose.encouragement.problem(in: PetDialogueSettings.defaultGenerationTemplate) == nil)
        check(!PetDialogueLine(event: .click, expression: .calm, text: " ").isValid)
        check(!PetDialogueLine(event: .click, expression: .calm, text: String(repeating: "字", count: 161)).isValid)
        check(!PetDialogueLine(event: .click, expression: .calm, text: "\u{0}").isValid)
        var badTemplate = defaults; badTemplate.generationTemplate = "{{未知}}"
        check(!badTemplate.isValid)
        let text = Data("\u{feff} 第一句 \r\n\r\n第二句\n".utf8)
        let textLines = try PetDialogueFile.decode(text, structured: false, event: .harvest, expression: .smile)
        check(textLines.map(\.text) == ["第一句", "第二句"])
        check(textLines.allSatisfy { $0.event == .harvest && $0.expression == .smile })
        let encoded = try PetDialogueFile.encode(textLines, structured: true)
        let decoded = try PetDialogueFile.decode(encoded, structured: true, event: .click, expression: .calm)
        check(decoded == textLines)
        rejected { _ = try PetDialogueFile.decode(Data([0xff]), structured: false, event: .click, expression: .calm) }
        rejected { _ = try PetDialogueFile.decode(Data(" \n".utf8), structured: false, event: .click, expression: .calm) }
        rejected { _ = try PetDialogueFile.decode(Data(repeating: 65, count: 1_000_001), structured: false, event: .click, expression: .calm) }
        rejected { _ = try PetDialogueFile.decode(Data("[{}]".utf8), structured: true, event: .click, expression: .calm) }
        rejected { _ = try PetDialogueFile.decode(Data(String(repeating: "字", count: 161).utf8), structured: false, event: .click, expression: .calm) }
        rejected { _ = try PetDialogueFile.decode(Data(Array(repeating: "句子", count: 1001).joined(separator: "\n").utf8), structured: false, event: .click, expression: .calm) }
        var appended = defaults
        check(try! appended.append(textLines) == 2)
        check(try! appended.append(textLines) == 0)
        let afterAppend = appended
        rejected { _ = try appended.append([PetDialogueLine(event: .click, expression: .calm, text: "")]) }
        check(appended == afterAppend)
        var sameID = textLines[0]; sameID.text = "相同编号的新句子"
        check(try! appended.append([sameID]) == 1)
        check(Set(appended.lines.map(\.id)).count == appended.lines.count)
        var picker = PetDialoguePicker()
        let first = picker.choose(event: .click, settings: defaults, at: now)!
        check(picker.choose(event: .click, settings: defaults, at: now) == nil)
        let second = picker.choose(event: .click, settings: defaults, at: now.addingTimeInterval(3))!
        check(first.id != second.id)
        check(picker.choose(event: .harvest, settings: defaults, at: now) != nil)
        var disabled = defaults; disabled.enabled = false
        check(picker.choose(event: .restStart, settings: disabled, at: now) == nil)
        var noLines = defaults; noLines.lines = []
        check(picker.choose(event: .restEnd, settings: noLines, at: now) == nil)
        let noModule = try JSONEncoder().encode(AppData())
        check(try! JSONDecoder().decode(AppData.self, from: noModule).petDialogue == nil)
        var legacyObject = try JSONSerialization.jsonObject(with: noModule) as! [String: Any]
        legacyObject.removeValue(forKey: "petDialogue")
        let legacy = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: legacyObject)).validated()
        check(legacy.petDialogue == nil && legacy.version == 4)

        let store = GardenStore(preview: true)
        store.data = AppData(); store.data.preferences.sound = false
        defer { store.storageLocked = true; try? FileManager.default.removeItem(at: store.file.deletingLastPathComponent()) }
        check(store.updatePetDialogue(appended))
        let persisted = try SaveFile.read(store.file)
        check(persisted.petDialogue == appended)
        let api = AIProfile(name: "离线测试预设", model: "offline-test")
        let writing = AIWritingPreset(name: "测试表达", character: "句子简短", userProfile: "", additionalRequirements: "使用中文")
        store.data.ai = AISettings(profiles: [api], assignments: [AIFeature.taskEncouragement.rawValue: api.id], writingPresets: [writing], writingAssignments: [AIFeature.focusReview.rawValue: writing.id])
        let oldAI = store.data.ai
        check(store.setPetDialogueAIPresets(profileID: api.id, writingPresetID: writing.id))
        check(store.data.ai == oldAI)
        check(store.aiProfile(for: .petDialogue) == api)
        check(store.aiProfile(for: .taskEncouragement) == api)
        check(store.aiWriting(for: .petDialogue).character == writing.character)
        check(store.aiWriting(for: .petDialogue).template(for: .encouragement) == PetDialogueSettings.defaultGenerationTemplate)
        check(store.aiWriting(for: .focusReview) == writing)
        check(store.data.ai?.assignments[AIFeature.petDialogue.rawValue] == nil && store.data.ai?.writingAssignments?[AIFeature.petDialogue.rawValue] == nil)
        check(!store.setPetDialogueAIPresets(profileID: UUID(), writingPresetID: nil))
        var customTemplate = store.petDialogueSettings
        customTemplate.generationTemplate = PetDialogueSettings.defaultGenerationTemplate + "\n语气平静。"
        check(store.updatePetDialogue(customTemplate))
        check(store.aiWriting(for: .petDialogue).template(for: .encouragement) == customTemplate.generationTemplate)
        check(store.data.ai == oldAI)
        let beforeFailure = store.data.petDialogue
        let originalBytes = try Data(contentsOf: store.file)
        let backup = store.file.deletingLastPathComponent().appendingPathComponent("readable-dialogue.json")
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        var failEdit = store.petDialogueSettings; failEdit.lines[0].text = "不能写入的编辑"
        check(!store.updatePetDialogue(failEdit))
        store.dismissPetSpeech()
        check(!store.startTimer(kind: .stopwatch, minutes: 1, task: nil, at: now))
        check(store.petSpeech == nil && store.data.timer == nil)
        check(store.data.petDialogue == beforeFailure && store.data.ai == oldAI)
        check(try! Data(contentsOf: backup) == originalBytes)
        try FileManager.default.removeItem(at: store.file); try FileManager.default.moveItem(at: backup, to: store.file)
        check(store.updatePetDialogue(beforeFailure!))
        store.triggerPetDialogue(.click, at: now)
        let speech = store.petSpeech!
        check(store.petExpression == speech.line.expression.rawValue)
        store.triggerPetDialogue(.click, at: now.addingTimeInterval(1))
        check(store.petSpeech?.id == speech.id)
        store.triggerPetDialogue(.click, at: now.addingTimeInterval(4))
        let replacement = store.petSpeech!
        check(replacement.id != speech.id && replacement.line.id != speech.line.id)
        store.dismissPetSpeech(id: speech.id)
        check(store.petSpeech?.id == replacement.id)
        store.setPetSpeechHovered(true, at: now.addingTimeInterval(5))
        store.advancePetSpeech(at: now.addingTimeInterval(1000))
        check(store.petSpeech?.id == replacement.id)
        store.setPetSpeechHovered(false, at: now.addingTimeInterval(1000))
        store.advancePetSpeech(at: now.addingTimeInterval(1020))
        check(store.petSpeech == nil && store.petExpression == 0)
        disabled = store.petDialogueSettings; disabled.enabled = false
        check(store.updatePetDialogue(disabled))
        store.triggerPetDialogue(.craft, at: now)
        check(store.petSpeech == nil)
        store.previewPetDialogue(first, at: now)
        check(store.petSpeech != nil)
        check(store.updatePetDialogue(disabled))
        check(store.petSpeech == nil)
        var enabled = disabled; enabled.enabled = true
        check(store.updatePetDialogue(enabled))
        store.previewPetDialogue(first, at: now)
        store.dragPet(300)
        check(store.petSpeech == nil)
        store.dropPet()
        let landingSpeech = store.petSpeech
        check(landingSpeech?.line.event == .dragEnd)
        store.dropPet()
        check(store.petSpeech?.id == landingSpeech?.id)
        store.dismissPetSpeech()
        check(store.startTimer(kind: .stopwatch, minutes: 1, task: nil, at: now))
        check(store.petSpeech?.line.event == .focusStart)
        let startID = store.petSpeech?.id
        check(!store.startTimer(kind: .stopwatch, minutes: 1, task: nil, at: now))
        check(store.petSpeech?.id == startID)
        let focusCoins = store.data.garden.coins
        check(store.finishTimer(at: now.addingTimeInterval(60)))
        check(store.data.garden.coins == focusCoins + 2)
        check(store.petSpeech?.line.event == .focusEnd)
        let finishID = store.petSpeech?.id
        check(!store.finishTimer(at: now.addingTimeInterval(60)))
        check(store.petSpeech?.id == finishID)
        check(store.data.garden.coins == focusCoins + 2)
        store.data.pomodoroBreakReady = true
        check(store.startTimer(kind: .rest, minutes: 1, task: nil, at: now.addingTimeInterval(120)))
        check(store.petSpeech?.line.event == .restStart)
        check(store.finishTimer(at: now.addingTimeInterval(180)))
        check(store.petSpeech?.line.event == .restEnd)
        let noNewAssignments = try SaveFile.read(store.file)
        check(noNewAssignments.ai == oldAI && noNewAssignments.petDialogue?.aiProfileID == api.id)

        store.data.timer = nil
        store.data.garden.coins = 1000
        check(store.save())
        let shirt = Cosmetic.all.first { $0.id == "shirt" }!
        let previousCoins = store.data.garden.coins
        let previousSeeds = store.data.garden.cropSeeds
        let previousOwned = store.data.garden.economy.owned
        let previousEquipped = store.data.garden.economy.equipped
        let gameDisk = try Data(contentsOf: store.file)
        try FileManager.default.moveItem(at: store.file, to: backup)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        check(!store.commitGameChange { $0.buyCosmetic(shirt, at: now) && $0.wear(shirt.id, slot: shirt.slot) })
        check(!store.commitGameChange { $0.buySeeds(.carrot) })
        check(store.data.garden.coins == previousCoins && store.data.garden.cropSeeds == previousSeeds && store.data.garden.economy.owned == previousOwned && store.data.garden.economy.equipped == previousEquipped)
        try FileManager.default.removeItem(at: store.file)
        try FileManager.default.moveItem(at: backup, to: store.file)
        try await Task.sleep(nanoseconds: 750_000_000)
        check(try! Data(contentsOf: store.file) == gameDisk)
        check(store.saveStatus == "保存失败")
        check(!store.commitGameChange { $0.buyCosmetic(shirt, at: now) && $0.wear(shirt.id, slot: .head) })
        check(store.data.garden.coins == previousCoins && store.data.garden.economy.owned == previousOwned)
        check(store.commitGameChange { $0.buyCosmetic(shirt, at: now) && $0.wear(shirt.id, slot: shirt.slot) })
        check(!store.commitGameChange { $0.buyCosmetic(shirt, at: now) && $0.wear(shirt.id, slot: shirt.slot) })
        check(store.data.garden.coins == previousCoins - shirt.price && store.data.garden.economy.worn(shirt.slot) == shirt.id)
        check(store.commitGameChange { $0.buySeeds(.carrot) })
        let gameRoundtrip = try SaveFile.read(store.file)
        check(gameRoundtrip.garden.coins == previousCoins - shirt.price - EconomyBalance.seedPacketPrice(.carrot) && gameRoundtrip.garden.cropSeeds[Crop.carrot.rawValue, default: 0] == previousSeeds[Crop.carrot.rawValue, default: 0] + 1)

        var badModule = store.petDialogueSettings
        badModule.generationTemplate = "{{事项}} {{数量}} {{长度}}"
        check(!store.updatePetDialogue(badModule))
        check(store.petDialogueSettings.generationTemplate == customTemplate.generationTemplate)
        var deletedPresets = store.data.ai!
        deletedPresets.profiles.removeAll { $0.id == api.id }
        deletedPresets.assignments = deletedPresets.assignments.filter { $0.value != api.id }
        deletedPresets.writingPresets?.removeAll { $0.id == writing.id }
        deletedPresets.writingAssignments = deletedPresets.writingAssignments?.filter { $0.value != writing.id }
        store.data.ai = deletedPresets
        check(store.save())
        check(store.aiProfile(for: .petDialogue) == nil)
        check(store.aiWriting(for: .petDialogue).character == AIWritingPreset.standard.character && store.aiWriting(for: .petDialogue).template(for: .encouragement) == customTemplate.generationTemplate)
        let afterDeletion = try SaveFile.read(store.file)
        check(afterDeletion.petDialogue?.aiProfileID == api.id && afterDeletion.petDialogue?.writingPresetID == writing.id && afterDeletion.ai?.isValid == true)
        let replacementAPI = AIProfile(name: "新的离线预设", model: "offline-replacement")
        let replacementWriting = AIWritingPreset(name: "新的表达")
        var replacements = deletedPresets
        replacements.profiles = [replacementAPI]; replacements.writingPresets = [replacementWriting]
        store.data.ai = replacements
        check(store.setPetDialogueAIPresets(profileID: replacementAPI.id, writingPresetID: writing.id))
        check(store.petDialogueSettings.aiProfileID == replacementAPI.id && store.petDialogueSettings.writingPresetID == nil)
        check(store.updatePetDialogue(afterDeletion.petDialogue!))
        check(store.setPetDialogueAIPresets(profileID: api.id, writingPresetID: replacementWriting.id))
        check(store.petDialogueSettings.aiProfileID == nil && store.petDialogueSettings.writingPresetID == replacementWriting.id)
        check(!store.setPetDialogueAIPresets(profileID: UUID(), writingPresetID: replacementWriting.id) && store.data.ai == replacements)
        print("PASS: \(count) pet-dialogue checks cover local defaults, event/expression binding, import/export/limits, duplicate suppression, old saves, API/template isolation, deleted-preset fallback, game transaction rollback without delayed rewrites, speech replacement/hover/expiry and focus/rest/drag event settlement")
    }
}
