import Foundation

struct Mineral: Identifiable {
    let id: String
    let name: String
    let price: Int
    var spriteKey: String { "mineral_" + id }
    static let all: [Mineral] = [
        .init(id:"coal",name:"煤",price:2), .init(id:"copper",name:"铜矿石",price:4),
        .init(id:"iron",name:"铁矿石",price:6), .init(id:"silver",name:"银矿石",price:10),
        .init(id:"gold",name:"金矿石",price:16), .init(id:"quartz",name:"石英",price:5),
        .init(id:"moonstone",name:"月长石",price:12), .init(id:"diamond_shard",name:"钻石碎片",price:8),
        .init(id:"diamond",name:"钻石",price:80), .init(id:"obsidian",name:"黑曜石",price:12),
        .init(id:"starlight_ore",name:"星辉矿",price:18),
        .init(id:"tin",name:"锡石",price:9), .init(id:"zinc",name:"闪锌矿",price:11),
        .init(id:"fluorite",name:"萤石",price:14), .init(id:"platinum",name:"铂矿石",price:28),
        .init(id:"meteor_iron",name:"陨铁",price:36), .init(id:"sunstone",name:"日光石",price:20)
    ]
}

struct MiningTool: Identifiable {
    let id: String
    let name: String
    let level: Int
    let price: Int
    let bonus: Int
    static let all: [MiningTool] = [
        .init(id:"tool_pickaxe",name:"铁镐",level:1,price:0,bonus:0),
        .init(id:"pickaxe_steel",name:"钢镐",level:8,price:180,bonus:1),
        .init(id:"pickaxe_alloy",name:"合金镐",level:24,price:580,bonus:2),
        .init(id:"pickaxe_meteor",name:"陨铁镐",level:38,price:1400,bonus:3)
    ]
}

struct MineLayer: Identifiable {
    let id: String
    let area: String
    let name: String
    let depth: Int
    let level: Int
    let mineralID: String
    let unlockMinutes: Int
    let cycleMinutes: Int
    let residentYield: Int
    let prerequisite: String?
    var mineral: Mineral { Mineral.all.first { $0.id == mineralID }! }
    var artworkName: String { "Mine_" + id }
    static let areas = ["旧矿场", "群山矿洞", "火山矿洞", "极地矿洞", "潮汐矿窟", "高地矿洞", "遗迹矿井"]
    static func layers(in area: String) -> [MineLayer] { all.filter { $0.area == area } }
    static func visible(in area: String, highlighted: String?, selected: String?) -> MineLayer {
        let layers = layers(in: area)
        return layers.first { $0.id == highlighted } ?? layers.first { $0.id == selected } ?? layers.first ?? all[0]
    }
    func adjacent(_ offset: Int) -> MineLayer? {
        MineLayer.layers(in: area).first { $0.depth == depth + offset }
    }
    static let all: [MineLayer] = [
        .init(id:"quarry_coal",area:"旧矿场",name:"露头煤层",depth:1,level:3,mineralID:"coal",unlockMinutes:10,cycleMinutes:10,residentYield:3,prerequisite:nil),
        .init(id:"quarry_copper",area:"旧矿场",name:"赤铜矿脉",depth:2,level:5,mineralID:"copper",unlockMinutes:20,cycleMinutes:15,residentYield:3,prerequisite:"quarry_coal"),
        .init(id:"quarry_iron",area:"旧矿场",name:"深部铁层",depth:3,level:8,mineralID:"iron",unlockMinutes:30,cycleMinutes:20,residentYield:3,prerequisite:"quarry_copper"),
        .init(id:"mountain_quartz",area:"群山矿洞",name:"石英岩壁",depth:1,level:12,mineralID:"quartz",unlockMinutes:30,cycleMinutes:15,residentYield:3,prerequisite:nil),
        .init(id:"mountain_silver",area:"群山矿洞",name:"银色矿脉",depth:2,level:14,mineralID:"silver",unlockMinutes:45,cycleMinutes:30,residentYield:4,prerequisite:"mountain_quartz"),
        .init(id:"mountain_gold",area:"群山矿洞",name:"含金石脉",depth:3,level:18,mineralID:"gold",unlockMinutes:60,cycleMinutes:40,residentYield:4,prerequisite:"mountain_silver"),
        .init(id:"volcanic_obsidian",area:"火山矿洞",name:"黑曜岩台",depth:1,level:20,mineralID:"obsidian",unlockMinutes:60,cycleMinutes:30,residentYield:4,prerequisite:nil),
        .init(id:"volcanic_diamond",area:"火山矿洞",name:"古老金伯利岩层",depth:2,level:26,mineralID:"diamond_shard",unlockMinutes:120,cycleMinutes:60,residentYield:5,prerequisite:"volcanic_obsidian"),
        .init(id:"polar_moonstone",area:"极地矿洞",name:"冰下长石层",depth:1,level:25,mineralID:"moonstone",unlockMinutes:90,cycleMinutes:45,residentYield:4,prerequisite:nil),
        .init(id:"polar_starlight",area:"极地矿洞",name:"星辉结晶洞",depth:2,level:30,mineralID:"starlight_ore",unlockMinutes:150,cycleMinutes:60,residentYield:4,prerequisite:"polar_moonstone"),
        .init(id:"reef_tin",area:"潮汐矿窟",name:"潮口砂锡层",depth:1,level:28,mineralID:"tin",unlockMinutes:90,cycleMinutes:40,residentYield:4,prerequisite:nil),
        .init(id:"reef_fluorite",area:"潮汐矿窟",name:"蓝萤晶廊",depth:2,level:31,mineralID:"fluorite",unlockMinutes:120,cycleMinutes:55,residentYield:4,prerequisite:"reef_tin"),
        .init(id:"reef_platinum",area:"潮汐矿窟",name:"沉潮铂脉",depth:3,level:35,mineralID:"platinum",unlockMinutes:165,cycleMinutes:90,residentYield:5,prerequisite:"reef_fluorite"),
        .init(id:"highland_zinc",area:"高地矿洞",name:"雾口锌脉",depth:1,level:29,mineralID:"zinc",unlockMinutes:100,cycleMinutes:45,residentYield:4,prerequisite:nil),
        .init(id:"highland_fluorite",area:"高地矿洞",name:"翠萤晶穴",depth:2,level:33,mineralID:"fluorite",unlockMinutes:135,cycleMinutes:65,residentYield:4,prerequisite:"highland_zinc"),
        .init(id:"highland_sunstone",area:"高地矿洞",name:"金辉长石穹窟",depth:3,level:37,mineralID:"sunstone",unlockMinutes:170,cycleMinutes:85,residentYield:5,prerequisite:"highland_fluorite"),
        .init(id:"ruins_tin",area:"遗迹矿井",name:"旧井锡层",depth:1,level:32,mineralID:"tin",unlockMinutes:105,cycleMinutes:55,residentYield:4,prerequisite:nil),
        .init(id:"ruins_meteor_iron",area:"遗迹矿井",name:"藏陨砖廊",depth:2,level:39,mineralID:"meteor_iron",unlockMinutes:180,cycleMinutes:120,residentYield:5,prerequisite:"ruins_tin"),
        .init(id:"ruins_platinum",area:"遗迹矿井",name:"封井铂库",depth:3,level:45,mineralID:"platinum",unlockMinutes:210,cycleMinutes:80,residentYield:5,prerequisite:"ruins_meteor_iron")
    ]
}

struct MineOpening: Codable, Equatable {
    var layerID: String
    var startedFocus: Double
}
struct MineProgress: Codable, Equatable {
    var lastFocus: Double
    var work: Double = 0
}
struct MiningState: Codable, Equatable {
    var layers: [String:MineProgress] = [:]
    var opening: MineOpening?
    var selectedLayer: String?
    var inventory: [String:Int] = [:]
    var lifetime: [String:Int] = [:]
    var toolRank: Int?
    var tool: MiningTool {
        let rank = toolRank ?? 0
        return MiningTool.all.indices.contains(rank) ? MiningTool.all[rank] : MiningTool.all[0]
    }
    var nextTool: MiningTool? {
        let rank = toolRank ?? 0
        guard MiningTool.all.indices.contains(rank) else { return nil }
        return MiningTool.all.dropFirst(rank + 1).first
    }
    func residentRate(_ layer: MineLayer) -> Int { layer.residentYield + tool.bonus }
    func isValid(focus: Double) -> Bool {
        guard MiningTool.all.indices.contains(toolRank ?? 0),
              selectedLayer.map({layers[$0] != nil}) ?? true,
              inventory.values.allSatisfy({(0...1_000_000_000).contains($0)}),
              Set(inventory.keys).isSubset(of:Set(Mineral.all.map(\.id))),
              lifetime.allSatisfy({(0...1_000_000_000).contains($0.value)}),
              Set(lifetime.keys).isSubset(of:Set(Mineral.all.map(\.id))) else {return false}
        for (id,progress) in layers {
            guard let layer=MineLayer.all.first(where:{$0.id == id}),
                  layer.prerequisite.map({layers[$0] != nil}) ?? true,
                  progress.lastFocus.isFinite,progress.lastFocus>=0,progress.lastFocus<=focus,
                  progress.work.isFinite,progress.work>=0,progress.work<Double(layer.cycleMinutes*60) else {return false}
        }
        if let opening {
            guard let layer=MineLayer.all.first(where:{$0.id == opening.layerID}), layers[layer.id] == nil,
                  opening.startedFocus.isFinite,opening.startedFocus>=0,opening.startedFocus<=focus,
                  layer.prerequisite.map({layers[$0] != nil}) ?? true else {return false}
        }
        return true
    }
}

extension AppData {
    var miningState: MiningState {garden.economy.mining ?? MiningState()}
    @discardableResult
    mutating func advanceMining(to focus: Double) -> Bool {
        guard var state=garden.economy.mining,focus.isFinite,focus>=0,focus<1_000_000_000_000 else {return false}
        let before=state
        if let opening=state.opening,let layer=MineLayer.all.first(where:{$0.id == opening.layerID}) {
            let completed=opening.startedFocus+Double(layer.unlockMinutes*60)
            if focus>=completed {
                state.layers[layer.id]=MineProgress(lastFocus:completed)
                state.opening=nil
            }
        }
        for id in state.layers.keys.sorted() {
            guard let layer=MineLayer.all.first(where:{$0.id == id}),var progress=state.layers[id],focus>progress.lastFocus else {continue}
            let rate=state.selectedLayer == id ? Double(state.residentRate(layer)):1
            let duration=Double(layer.cycleMinutes*60)
            let work=progress.work+(focus-progress.lastFocus)*rate
            let earned=min(1_000_000_000,Int(min(1_000_000_000,floor(work/duration))))
            state.inventory[layer.mineralID]=min(1_000_000_000,state.inventory[layer.mineralID,default:0]+earned)
            state.lifetime[layer.mineralID]=min(1_000_000_000,state.lifetime[layer.mineralID,default:0]+earned)
            progress.work=work.truncatingRemainder(dividingBy:duration)
            progress.lastFocus=focus
            state.layers[id]=progress
        }
        guard state != before else {return false}
        garden.economy.mining=state
        return true
    }
    mutating func openMine(_ id:String,at date:Date=Date())->Bool {
        let focus=gameFocus(at:date)
        advanceMining(to:focus)
        var state=miningState
        guard let layer=MineLayer.all.first(where:{$0.id == id}),levelProgress.level>=layer.level,
              state.opening == nil,state.layers[id] == nil,
              layer.prerequisite.map({state.layers[$0] != nil}) ?? true else {return false}
        state.opening=MineOpening(layerID:id,startedFocus:focus)
        garden.economy.mining=state
        return true
    }
    mutating func selectMine(_ id:String?,at date:Date=Date())->Bool {
        advanceMining(to:gameFocus(at:date))
        var state=miningState
        guard id.map({state.layers[$0] != nil}) ?? true else {return false}
        state.selectedLayer=id;garden.economy.mining=state
        return true
    }
    mutating func upgradeMiningTool(at date: Date = Date()) -> Bool {
        guard let next = miningState.nextTool, levelProgress.level >= next.level, garden.coins >= next.price else { return false }
        advanceMining(to: gameFocus(at: date))
        var state = miningState
        state.toolRank = (state.toolRank ?? 0) + 1
        garden.economy.mining = state
        garden.coins -= next.price
        return true
    }
    mutating func combineDiamond()->Bool {
        var state=miningState
        guard state.inventory["diamond_shard",default:0]>=10,state.inventory["diamond",default:0]<1_000_000_000 else {return false}
        state.inventory["diamond_shard",default:0]-=10
        state.inventory["diamond",default:0]+=1
        garden.economy.mining=state;return true
    }
}
