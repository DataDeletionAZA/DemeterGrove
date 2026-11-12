import Foundation

@main enum MiningChecks {
    static func check(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, file: file, line: line) }
    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }
    static func fixture(focus: Double = 1_000_000) -> AppData {
        var data = AppData(); data.preferences.sound = false; data.garden.coins = 10000
        data.sessions = [FocusSession(id: UUID(), title: "阅读", kind: .stopwatch, date: Date(), seconds: focus)]
        return data
    }
    static func reject(_ data: AppData) -> Bool { do { _ = try data.validated(); return false } catch { return true } }
    static func focusForLevel(_ level: Int) -> Double {
        Double((1..<level).reduce(0) { $0 + LevelProgress.requirement($1) } * 60)
    }
    static func allLayers(at focus: Double, selected: String? = nil) -> MiningState {
        MiningState(layers: Dictionary(uniqueKeysWithValues: MineLayer.all.map { ($0.id, MineProgress(lastFocus: focus)) }), selectedLayer: selected)
    }
    @MainActor static func main() throws {
        let now = Date()
        check(MineLayer.areas.count == 7 && MineLayer.all.count == 19)
        check(Set(MineLayer.all.map(\.artworkName)).count == MineLayer.all.count)
        for area in MineLayer.areas {
            let layers = MineLayer.layers(in: area)
            check(!layers.isEmpty)
            check(MineLayer.visible(in: area, highlighted: nil, selected: nil).id == layers.first!.id)
            check(layers.first!.adjacent(-1) == nil && layers.last!.adjacent(1) == nil)
            for (index, layer) in layers.enumerated() {
                check(layer.depth == index + 1)
                check(MineLayer.visible(in: area, highlighted: layer.id, selected: layers.first!.id).id == layer.id)
                check(MineLayer.visible(in: area, highlighted: "invalid", selected: layer.id).id == layer.id)
                check(layer.adjacent(-1)?.id == (index > 0 ? layers[index - 1].id : nil))
                check(layer.adjacent(1)?.id == (index + 1 < layers.count ? layers[index + 1].id : nil))
                if let below = layer.adjacent(1) { check(below.adjacent(-1)?.id == layer.id) }
            }
        }
        check(MineLayer.visible(in: "旧矿场", highlighted: "polar_starlight", selected: "mountain_gold").id == "quarry_coal")
        check(MineLayer.visible(in: "invalid", highlighted: nil, selected: nil).id == "quarry_coal")
        for viewport in [CGSize(width: 560, height: 420), CGSize(width: 1000, height: 680), CGSize(width: 1500, height: 900)] {
            let width = SceneSizing.canvasWidth(viewportWidth: viewport.width)
            let height = SceneSizing.height(width: width, viewportHeight: viewport.height)
            let stage = SceneSizing.fitted(in: CGSize(width: width - SceneSizing.sidebar(width: width) - SceneSizing.gap, height: height))
            check(stage.width > 52 && stage.height > 78)
            check(stage.width * 0.64 - stage.width * 0.07 > 43)
            check(stage.width * 0.64 + stage.width * 0.07 < stage.width - 9)
            check(stage.height * 0.56 + stage.width * 0.07 < stage.height - 39)
        }
        var fresh = fixture()
        let baseline = fresh.totalFocus
        check(!fresh.advanceMining(to: baseline) && fresh.garden.economy.mining == nil)
        check(fresh.openMine("quarry_coal", at: now))
        check(!fresh.openMine("mountain_quartz", at: now))
        check(!fresh.advanceMining(to: baseline + 599))
        check(fresh.advanceMining(to: baseline + 600))
        check(fresh.miningState.layers["quarry_coal"]?.lastFocus == baseline + 600 && fresh.miningState.inventory["coal", default: 0] == 0)
        check(fresh.advanceMining(to: baseline + 1200) && fresh.miningState.inventory["coal"] == 1)
        let after = try encoded(fresh)
        check(!fresh.advanceMining(to: baseline + 1200) && !fresh.advanceMining(to: baseline + 1000))
        check(!fresh.advanceMining(to: -1) && !fresh.advanceMining(to: .nan) && !fresh.advanceMining(to: .infinity) && !fresh.advanceMining(to: 1e308))
        check(try encoded(fresh) == after)

        for layer in MineLayer.all {
            var locked = fixture(focus: 0)
            check(!locked.openMine(layer.id, at: now))
            var path = fixture()
            if layer.prerequisite != nil { check(!path.openMine(layer.id, at: now)) }
            var prepared = allLayers(at: path.totalFocus)
            prepared.layers.removeValue(forKey: layer.id)
            path.garden.economy.mining = prepared
            check(path.openMine(layer.id, at: now))
            check(path.miningState.opening?.layerID == layer.id)
            check(path.advanceMining(to: path.totalFocus + Double(layer.unlockMinutes * 60)))
            check(path.miningState.layers[layer.id] != nil && path.miningState.opening == nil)
        }
        for area in ["潮汐矿窟", "高地矿洞", "遗迹矿井"] {
            var path = fixture(focus: 0)
            for layer in MineLayer.layers(in: area) {
                path.sessions[0].seconds = focusForLevel(layer.level) - 1
                check(!path.openMine(layer.id, at: now))
                path.sessions[0].seconds += 1
                check(path.openMine(layer.id, at: now))
                let ready = path.totalFocus + Double(layer.unlockMinutes * 60)
                _ = path.advanceMining(to: ready - 1)
                check(path.miningState.layers[layer.id] == nil)
                path.sessions[0].seconds = ready
                check(path.advanceMining(to: ready) && path.miningState.layers[layer.id] != nil)
                check(path.miningState.layers[layer.id]?.work == 0)
            }
            _ = try path.validated(at: now)
        }
        var delayed = fixture()
        check(delayed.openMine("quarry_coal", at: now))
        check(delayed.advanceMining(to: baseline + 1800))
        check(delayed.miningState.inventory["coal"] == 2)

        var passive = fixture(focus: 0)
        passive.garden.economy.mining = allLayers(at: 0)
        check(!passive.advanceMining(to: 0))
        check(passive.advanceMining(to: 3600))
        let expected = Dictionary(MineLayer.all.map { ($0.mineralID, 3600 / ($0.cycleMinutes * 60)) }, uniquingKeysWith: +)
        for (id, quantity) in expected { check(passive.miningState.inventory[id, default: 0] == quantity) }
        var resident = fixture(focus: 0)
        resident.garden.economy.mining = allLayers(at: 0, selected: "quarry_copper")
        check(resident.advanceMining(to: 3600))
        check(resident.miningState.inventory["copper"] == 12 && resident.miningState.inventory["coal"] == 6 && resident.miningState.inventory["iron"] == 3)

        var switched = fixture(focus: 0)
        switched.garden.economy.mining = allLayers(at: 0, selected: "quarry_coal")
        switched.sessions[0].seconds = 600
        check(switched.selectMine("quarry_copper", at: now))
        check(switched.miningState.inventory["coal"] == 3 && switched.miningState.layers["quarry_copper"]?.work == 600)
        check(switched.advanceMining(to: 1200))
        check(switched.miningState.inventory["coal"] == 4 && switched.miningState.inventory["copper"] == 2 && switched.miningState.layers["quarry_copper"]?.work == 600)
        switched.sessions[0].seconds = 1200
        check(switched.selectMine(nil, at: now) && switched.miningState.selectedLayer == nil)
        check(!switched.selectMine("invalid", at: now))
        check(switched.advanceMining(to: 1500) && switched.miningState.inventory["copper"] == 3)

        var toolUpgrade = fixture(focus: focusForLevel(8) - 1)
        let toolBaseline = toolUpgrade.totalFocus
        toolUpgrade.garden.economy.mining = allLayers(at: toolBaseline, selected: "quarry_copper")
        let oldToolBytes = try encoded(toolUpgrade)
        let oldToolSave = try JSONDecoder().decode(AppData.self, from: oldToolBytes)
        check(oldToolSave.miningState.toolRank == nil && oldToolSave.miningState.tool.id == "tool_pickaxe")
        check(!toolUpgrade.upgradeMiningTool(at: now))
        check(try encoded(toolUpgrade) == oldToolBytes)
        toolUpgrade.sessions[0].seconds += 240
        toolUpgrade.garden.coins = MiningTool.all[1].price - 1
        let insufficient = try encoded(toolUpgrade)
        check(!toolUpgrade.upgradeMiningTool(at: now))
        check(try encoded(toolUpgrade) == insufficient)
        toolUpgrade.garden.coins += 1
        check(toolUpgrade.upgradeMiningTool(at: now) && toolUpgrade.garden.coins == 0)
        check(toolUpgrade.miningState.tool.id == "pickaxe_steel")
        check(toolUpgrade.miningState.inventory["copper", default: 0] == 0)
        check(toolUpgrade.miningState.layers["quarry_copper"]?.work == 720)
        check(toolUpgrade.miningState.layers["quarry_coal"]?.work == 240)
        toolUpgrade.sessions[0].seconds += 45
        check(toolUpgrade.advanceMining(to: toolUpgrade.totalFocus))
        check(toolUpgrade.miningState.inventory["copper"] == 1 && toolUpgrade.miningState.layers["quarry_copper"]?.work == 0)
        check(toolUpgrade.miningState.layers["quarry_coal"]?.work == 285)
        for rank in 2...3 {
            let next = MiningTool.all[rank]
            toolUpgrade.garden.coins = next.price
            toolUpgrade.sessions[0].seconds = focusForLevel(next.level) - 1
            check(!toolUpgrade.upgradeMiningTool(at: now))
            toolUpgrade.sessions[0].seconds += 1
            check(toolUpgrade.upgradeMiningTool(at: now) && toolUpgrade.garden.coins == 0)
            check(toolUpgrade.miningState.tool.id == next.id && toolUpgrade.miningState.toolRank == rank)
        }
        check(toolUpgrade.miningState.nextTool == nil && !toolUpgrade.upgradeMiningTool(at: now))
        let restoredTool = try JSONDecoder().decode(AppData.self, from: encoded(toolUpgrade)).validated(at: now)
        check(restoredTool.miningState == toolUpgrade.miningState)

        var jump = fixture(focus: 0), steps = jump
        jump.garden.economy.mining = allLayers(at: 0, selected: "polar_starlight")
        jump.garden.economy.mining?.toolRank = 3
        steps.garden.economy.mining = jump.garden.economy.mining
        check(jump.advanceMining(to: 86400))
        for seconds in stride(from: 17, through: 86394, by: 17) { _ = steps.advanceMining(to: Double(seconds)) }
        check(steps.advanceMining(to: 86400))
        check(jump.miningState == steps.miningState)
        check(jump.miningState.isValid(focus: 86400))

        var timer = fixture()
        timer.garden.economy.mining = allLayers(at: timer.totalFocus, selected: "quarry_coal")
        timer.garden.economy.mining?.toolRank = 3
        timer.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: now)
        let paused = now.addingTimeInterval(200)
        timer.timer?.pause(at: paused)
        check(timer.advanceMining(to: timer.gameFocus(at: paused)))
        check(timer.miningState.inventory["coal"] == 2)
        check(!timer.advanceMining(to: timer.gameFocus(at: paused.addingTimeInterval(999))))
        _ = timer.finishTimer(at: paused)
        timer.timer = TimerRun(kind: .rest, target: 300, taskTitle: "休息", startedAt: paused, resumedAt: paused)
        check(!timer.advanceMining(to: timer.gameFocus(at: paused.addingTimeInterval(300))))
        _ = try timer.validated(at: paused.addingTimeInterval(300))

        var combine = fixture()
        combine.garden.economy.mining = MiningState(inventory: ["diamond_shard": 19])
        check(combine.combineDiamond() && combine.miningState.inventory["diamond_shard"] == 9 && combine.miningState.inventory["diamond"] == 1)
        let nine = try encoded(combine)
        check(!combine.combineDiamond()); check(try encoded(combine) == nine)
        combine.garden.economy.mining?.inventory["diamond_shard"] = 10
        combine.garden.economy.mining?.inventory["diamond"] = 1_000_000_000
        let capped = try encoded(combine)
        check(!combine.combineDiamond()); check(try encoded(combine) == capped)

        let valid = fixture()
        let invalidStates: [MiningState] = [
            MiningState(layers: ["invalid": MineProgress(lastFocus: 0)]),
            MiningState(layers: ["quarry_copper": MineProgress(lastFocus: 0)]),
            MiningState(layers: ["quarry_coal": MineProgress(lastFocus: .infinity)]),
            MiningState(layers: ["quarry_coal": MineProgress(lastFocus: 0, work: .nan)]),
            MiningState(layers: ["quarry_coal": MineProgress(lastFocus: 0, work: 600)]),
            MiningState(layers: ["quarry_coal": MineProgress(lastFocus: valid.totalFocus + 1)]),
            MiningState(opening: MineOpening(layerID: "quarry_copper", startedFocus: 0)),
            MiningState(selectedLayer: "quarry_coal"), MiningState(inventory: ["coal": -1]),
            MiningState(inventory: ["invalid": 1]), MiningState(lifetime: ["coal": 1_000_000_001]),
            MiningState(toolRank: -1), MiningState(toolRank: MiningTool.all.count), MiningState(toolRank: Int.max)
        ]
        for state in invalidStates { var data = valid; data.garden.economy.mining = state; check(reject(data)) }

        let store = GardenStore(preview: true)
        let manager = FileManager.default, folder = store.file.deletingLastPathComponent()
        defer { store.storageLocked = true; try? manager.removeItem(at: folder) }
        store.data = fixture()
        check(store.commitGameChange { $0.openMine("quarry_coal", at: now) })
        check(try SaveFile.read(store.file).miningState == store.data.miningState)
        store.data.sessions[0].seconds += 600
        check(store.save())
        let disk = try Data(contentsOf: store.file), prior = try encoded(store.data)
        let backup = folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at: store.file, to: backup); try manager.createDirectory(at: store.file, withIntermediateDirectories: false)
        try Data([1]).write(to: store.file.appendingPathComponent("blocked"))
        check(!store.commitGameChange { $0.advanceMining(to: $0.totalFocus) })
        check(try encoded(store.data) == prior && Data(contentsOf: backup) == disk)
        check(!store.commitGameChange { $0.upgradeMiningTool(at: now) })
        check(try encoded(store.data) == prior && Data(contentsOf: backup) == disk)
        try manager.removeItem(at: store.file); try manager.moveItem(at: backup, to: store.file)
        let coins = store.data.garden.coins
        check(store.commitGameChange { $0.upgradeMiningTool(at: now) })
        let saved = try SaveFile.read(store.file)
        check(saved.miningState.toolRank == 1 && saved.garden.coins == coins - MiningTool.all[1].price)
        print("PASS: seven mine areas and nineteen layers, unlock chains and clocks, passive production, pickaxe upgrades and partial work, pause/rest, long-step equivalence, 10:1 diamonds, legacy saves, invalid ranks, and failed-save rollback")
    }
}
