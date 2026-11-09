import Foundation

enum ForgeStation:String,CaseIterable { case furnace="熔炉", sewing="缝纫台" }
struct ForgeMaterial:Identifiable {
    let id:String
    let name:String
    let kind:String
    let gathering:Int
    let scouting:Int
    let guarding:Int
    let value:Int
    var spriteKey:String {
        if Mineral.all.contains(where:{$0.id == id}) {return "mineral_"+id}
        return NatureItemInfo.find(id)?.spriteKey ?? "ranch_"+id
    }
    static let all:[ForgeMaterial]=[
        .init(id:"copper",name:"铜",kind:"金属",gathering:1,scouting:0,guarding:0,value:4),
        .init(id:"iron",name:"铁",kind:"金属",gathering:0,scouting:0,guarding:2,value:6),
        .init(id:"silver",name:"银",kind:"金属",gathering:0,scouting:2,guarding:0,value:10),
        .init(id:"gold",name:"金",kind:"软金属",gathering:0,scouting:2,guarding:0,value:16),
        .init(id:"quartz",name:"石英",kind:"晶石",gathering:0,scouting:1,guarding:0,value:5),
        .init(id:"moonstone",name:"月长石",kind:"晶石",gathering:0,scouting:1,guarding:1,value:12),
        .init(id:"diamond",name:"钻石",kind:"晶石",gathering:1,scouting:1,guarding:1,value:80),
        .init(id:"obsidian",name:"黑曜石",kind:"晶石",gathering:2,scouting:0,guarding:1,value:12),
        .init(id:"starlight_ore",name:"星辉矿",kind:"金属",gathering:1,scouting:2,guarding:0,value:18),
        .init(id:"sheep_wool",name:"羊毛",kind:"纤维",gathering:0,scouting:0,guarding:1,value:5),
        .init(id:"rabbit_fibre",name:"兔绒",kind:"纤维",gathering:1,scouting:0,guarding:0,value:6),
        .init(id:"alpaca_fibre",name:"羊驼绒",kind:"纤维",gathering:0,scouting:1,guarding:1,value:8),
        .init(id:"cloud_fleece",name:"云绒",kind:"纤维",gathering:1,scouting:1,guarding:0,value:10)
    ]
}
struct ForgePart:Identifiable {
    let id:String
    let name:String
    let preferred:[String]
    func compatibility(_ material:ForgeMaterial)->Int {
        if preferred.contains(material.id) {return 2}
        if id == "grip" && material.id == "gold" {return -2}
        if (id == "cloth" || id == "lining") && material.kind != "纤维" {return -2}
        if (id == "blade" || id == "frame") && material.kind == "纤维" {return -2}
        return 0
    }
}
struct ForgeMold:Identifiable {
    let id:String
    let name:String
    let station:ForgeStation
    let slot:GearSlot
    let level:Int
    let parts:[ForgePart]
    let gathering:Int
    let scouting:Int
    let guarding:Int
    var spriteKey:String {"forge_mold_"+id}
    var gearSpriteKey:String {"forge_gear_"+id}
    var description:String {
        switch id {
        case "sword":return "剑刃、剑柄与缠带组成的行路短剑，适合清理挡路的枝条。"
        case "sickle":return "弯刃与握柄组成的采集工具，收割时能避开尚在生长的嫩芽。"
        case "pendant":return "坠心嵌入小巧的镶框，随旅人寻找林间细微的踪迹。"
        default:return "衣身、衬里与衣扣组成的远行外衣，在风里多留一层暖意。"
        }
    }
    static let all:[ForgeMold]=[
        .init(id:"sword",name:"行路剑",station:.furnace,slot:.tool,level:5,parts:[.init(id:"blade",name:"剑刃",preferred:["iron","obsidian"]),.init(id:"grip",name:"剑柄",preferred:["copper","iron"]),.init(id:"wrap",name:"缠带",preferred:["sheep_wool","alpaca_fibre"])],gathering:1,scouting:0,guarding:1),
        .init(id:"sickle",name:"采集镰",station:.furnace,slot:.tool,level:5,parts:[.init(id:"blade",name:"镰刃",preferred:["copper","obsidian"]),.init(id:"grip",name:"握柄",preferred:["iron","copper"])],gathering:2,scouting:0,guarding:0),
        .init(id:"pendant",name:"寻踪坠",station:.furnace,slot:.charm,level:5,parts:[.init(id:"gem",name:"坠心",preferred:["quartz","moonstone","diamond"]),.init(id:"frame",name:"镶框",preferred:["silver","gold"])],gathering:0,scouting:2,guarding:0),
        .init(id:"coat",name:"护行外衣",station:.sewing,slot:.coat,level:5,parts:[.init(id:"cloth",name:"衣身",preferred:["sheep_wool","cloud_fleece"]),.init(id:"lining",name:"衬里",preferred:["rabbit_fibre","alpaca_fibre"]),.init(id:"buckle",name:"衣扣",preferred:["copper","moonstone"])],gathering:0,scouting:0,guarding:2)
    ]
}
extension CraftedGear {
    var description:String? {ForgeMold.all.first{$0.gearSpriteKey == spriteKey}?.description ?? ItemLore.text(for:"gear:"+id)}
}
struct ForgeResult:Codable,Equatable,Identifiable {
    var id=UUID()
    var moldID:String
    var materialIDs:[String]
    var roll:CraftRoll
    var gearID:String?
    var name:String
    var expectedGearID:String {"forged_"+moldID+"_"+materialIDs.joined(separator:"_")+"_q"+String(roll.quality)}
}
struct ForgeState:Codable,Equatable {
    var lastResult:ForgeResult?
    func isValid(in expedition:ExpeditionState)->Bool {
        guard let result=lastResult else{return true}
        guard let mold=ForgeMold.all.first(where:{$0.id == result.moldID}),
              result.materialIDs.count == mold.parts.count,
              result.materialIDs.allSatisfy({id in ForgeMaterial.all.contains{$0.id == id}}),
              result.roll.isValid,
              result.roll.modifier == max(-6,min(6,zip(mold.parts,result.materialIDs).reduce(0){total,pair in total+pair.0.compatibility(ForgeMaterial.all.first{$0.id == pair.1}!)})),
              !result.name.isEmpty,result.name.count<=60 else{return false}
        if result.roll.criticalFailure {return result.gearID == nil}
        return result.gearID == result.expectedGearID && result.gearID.flatMap{expedition.resolveGear($0)}?.name == result.name
    }
}

extension ExpeditionState {
    func resolveGear(_ id:String)->CraftedGear? {generatedGear?[id] ?? CraftedGear.all.first{$0.id == id}}
    var ownedGear:[CraftedGear] {gear.keys.sorted().compactMap{gear[$0,default:0]>0 ? resolveGear($0):nil}}
    func wornCount(_ id:String)->Int {equipment.values.reduce(0){$0+$1.values.filter{$0 == id}.count}}
}
extension AppData {
    var forgeState:ForgeState {garden.economy.forge ?? ForgeState()}
    func forgeMaterialCount(_ id:String)->Int {
        Mineral.all.contains{$0.id == id} ? miningState.inventory[id,default:0]:garden.economy.finds[id,default:0]
    }
    func forgeModifier(mold:ForgeMold,materialIDs:[String])->Int {
        guard materialIDs.count == mold.parts.count else{return 0}
        return max(-6,min(6,zip(mold.parts,materialIDs).reduce(0){total,pair in
            total+(ForgeMaterial.all.first{$0.id == pair.1}.map{pair.0.compatibility($0)} ?? 0)
        }))
    }
    func canForge(mold:ForgeMold,materialIDs:[String])->Bool {
        guard levelProgress.level>=mold.level,materialIDs.count == mold.parts.count,
              materialIDs.allSatisfy({id in ForgeMaterial.all.contains{$0.id == id}}),expeditionState.gear.count<4096 else{return false}
        let counts=Dictionary(materialIDs.map{($0,1)},uniquingKeysWith:+)
        return counts.allSatisfy{forgeMaterialCount($0.key)>=$0.value}
    }
    mutating func forgeGear(moldID:String,materialIDs:[String],natural:Int?=nil)->Bool {
        guard let mold=ForgeMold.all.first(where:{$0.id == moldID}),canForge(mold:mold,materialIDs:materialIDs),
              natural.map({(1...20).contains($0)}) ?? true else{return false}
        let roll=CraftRoll(natural:natural ?? Int.random(in:1...20),modifier:forgeModifier(mold:mold,materialIDs:materialIDs))
        var result=ForgeResult(moldID:mold.id,materialIDs:materialIDs,roll:roll,name:roll.criticalFailure ? "锻造失败":mold.name)
        guard roll.criticalFailure || expeditionState.gear[result.expectedGearID,default:0]<1_000_000_000 else{return false}
        var mining=miningState
        for id in materialIDs {
            if Mineral.all.contains(where:{$0.id == id}) {mining.inventory[id,default:0]-=1}
            else {garden.economy.finds[id,default:0]-=1}
        }
        garden.economy.mining=mining
        if !roll.criticalFailure {
            let materials=materialIDs.compactMap{id in ForgeMaterial.all.first{$0.id == id}}
            let special:String? = mold.id == "sword" && materialIDs == ["iron","copper","sheep_wool"] ? "牧途守望剑":mold.id == "coat" && materialIDs == ["cloud_fleece","alpaca_fibre","moonstone"] ? "月云护行衣":nil
            let name=(special ?? (materials.first?.name ?? "")+mold.name)+" · "+roll.tierTitle
            let scale=max(1,roll.quality/20)
            let id=result.expectedGearID
            let item=CraftedGear(id:id,name:name,slot:mold.slot,level:mold.level,minerals:[:],price:0,
                gathering:max(0,(mold.gathering+materials.reduce(0){$0+$1.gathering})*scale/2+(special == nil ? 0:1)),
                scouting:max(0,(mold.scouting+materials.reduce(0){$0+$1.scouting})*scale/2+(special == nil ? 0:1)),
                guarding:max(0,(mold.guarding+materials.reduce(0){$0+$1.guarding})*scale/2+(special == nil ? 0:1)),
                forgeSprite:mold.gearSpriteKey,saleValue:max(1,materials.reduce(0){$0+$1.value}*(20+roll.quality)/50))
            var expedition=expeditionState
            expedition.generatedGear=expedition.generatedGear ?? [:]
            expedition.generatedGear?[id]=item
            expedition.gear[id,default:0]+=1
            garden.economy.expedition=expedition
            result.gearID=id;result.name=name
        }
        garden.economy.forge=ForgeState(lastResult:result)
        return true
    }
}
