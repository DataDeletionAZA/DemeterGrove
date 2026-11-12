import Foundation

enum ForgeStation:String,CaseIterable { case furnace="熔炉", sewing="缝纫台" }
struct ForgeMaterial:Identifiable {
    let id:String
    let name:String
    let kind:String
    let gathering:Int
    let scouting:Int
    let guarding:Int
    var value:Int {
        if let mineral=Mineral.all.first(where:{$0.id == id}) {return mineral.price}
        if let forage=NatureCatalog.forage.first(where:{$0.id == id}) {return forage.salePrice}
        return NatureCatalog.ranchSpecies.first{$0.productID == id}?.salePrice ?? 0
    }
    var isMineral:Bool {Mineral.all.contains{$0.id == id}}
    var isForage:Bool {!isMineral && NatureCatalog.forage.contains{$0.id == id}}
    var spriteKey:String {
        if isMineral {return "mineral_"+id}
        return NatureItemInfo.find(id)?.spriteKey ?? "ranch_"+id
    }
    static let all:[ForgeMaterial]=[
        .init(id:"copper",name:"铜",kind:"金属",gathering:1,scouting:0,guarding:0),
        .init(id:"iron",name:"铁",kind:"金属",gathering:0,scouting:0,guarding:2),
        .init(id:"silver",name:"银",kind:"金属",gathering:0,scouting:2,guarding:0),
        .init(id:"gold",name:"金",kind:"软金属",gathering:0,scouting:2,guarding:0),
        .init(id:"quartz",name:"石英",kind:"晶石",gathering:0,scouting:1,guarding:0),
        .init(id:"moonstone",name:"月长石",kind:"晶石",gathering:0,scouting:1,guarding:1),
        .init(id:"diamond",name:"钻石",kind:"晶石",gathering:1,scouting:1,guarding:1),
        .init(id:"obsidian",name:"黑曜石",kind:"晶石",gathering:2,scouting:0,guarding:1),
        .init(id:"starlight_ore",name:"星辉矿",kind:"金属",gathering:1,scouting:2,guarding:0),
        .init(id:"sheep_wool",name:"羊毛",kind:"纤维",gathering:0,scouting:0,guarding:1),
        .init(id:"rabbit_fibre",name:"兔绒",kind:"纤维",gathering:1,scouting:0,guarding:0),
        .init(id:"alpaca_fibre",name:"羊驼绒",kind:"纤维",gathering:0,scouting:1,guarding:1),
        .init(id:"cloud_fleece",name:"云绒",kind:"纤维",gathering:1,scouting:1,guarding:0),
        .init(id:"cashmere",name:"羊绒",kind:"纤维",gathering:0,scouting:0,guarding:2),
        .init(id:"rattan",name:"藤条",kind:"藤材",gathering:1,scouting:0,guarding:2),
        .init(id:"willow_twig",name:"白柳落枝",kind:"木材",gathering:1,scouting:0,guarding:0),
        .init(id:"driftwood",name:"海漂木",kind:"木材",gathering:0,scouting:1,guarding:1),
        .init(id:"tin",name:"锡石",kind:"软金属",gathering:0,scouting:1,guarding:1),
        .init(id:"zinc",name:"闪锌矿",kind:"金属",gathering:1,scouting:0,guarding:2),
        .init(id:"fluorite",name:"萤石",kind:"晶石",gathering:0,scouting:2,guarding:1),
        .init(id:"platinum",name:"铂矿石",kind:"金属",gathering:0,scouting:2,guarding:2),
        .init(id:"meteor_iron",name:"陨铁",kind:"金属",gathering:1,scouting:0,guarding:3),
        .init(id:"sunstone",name:"日光石",kind:"晶石",gathering:1,scouting:3,guarding:0),
        .init(id:"reef_silk",name:"礁丝",kind:"纤维",gathering:0,scouting:1,guarding:2),
        .init(id:"echo_vine",name:"回声藤",kind:"藤材",gathering:2,scouting:1,guarding:1)
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
        if id == "shaft" && material.kind != "木材" {return -2}
        if id == "body" && material.kind != "纤维" {return -2}
        return 0
    }
}

enum ForgeGarment:String,CaseIterable {
    case mail, rattan, cloth, cashmere

    init(material:ForgeMaterial) {
        if material.kind == "金属" || material.kind == "软金属" {self = .mail}
        else if material.id == "rattan" {self = .rattan}
        else if material.id == "cashmere" {self = .cashmere}
        else {self = .cloth}
    }

    func name(for slot:GearSlot)->String {
        switch self {
        case .mail:return slot == .trousers ? "锁子护腿":"锁子甲"
        case .rattan:return slot == .trousers ? "藤编护腿":"藤甲"
        case .cloth:return slot == .trousers ? "布裤":"布衣"
        case .cashmere:return slot == .trousers ? "羊绒裤":"羊绒衫"
        }
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
    private var hasGarmentVariants:Bool {id == "top" || id == "trousers"}

    func outputName(materialIDs:[String])->String {
        guard let main=ForgeMaterial.all.first(where:{$0.id == materialIDs.first}) else{return name}
        if hasGarmentVariants {return ForgeGarment(material:main).name(for:slot)}
        return specialName(materialIDs:materialIDs) ?? main.name+name
    }

    var specialRecipes: [(name:String, materials:[String])] {
        switch id {
        case "sword": return [("牧途守望剑",["iron","copper","sheep_wool"])]
        case "coat": return [("月云护行衣",["cloud_fleece","alpaca_fibre","moonstone"]),
                            ("潮绸远行衣",["reef_silk","alpaca_fibre","platinum"])]
        case "pendant": return [("潮灯坠",["fluorite","tin"])]
        case "staff": return [("曦石寻路杖",["echo_vine","sunstone","platinum"])]
        case "longsword": return [("陨纹长剑",["meteor_iron","zinc","reef_silk"])]
        default: return []
        }
    }

    func specialName(materialIDs:[String])->String? {
        specialRecipes.first{$0.materials == materialIDs}?.name
    }

    func outputSprite(material:ForgeMaterial)->String {
        hasGarmentVariants ? gearSpriteKey+"_"+ForgeGarment(material:material).rawValue:gearSpriteKey
    }

    func supportsGearSprite(_ sprite:String)->Bool {
        if hasGarmentVariants {return ForgeGarment.allCases.contains{sprite == gearSpriteKey+"_"+$0.rawValue}}
        return sprite == gearSpriteKey
    }

    func modifier(materialIDs:[String])->Int {
        guard materialIDs.count == parts.count else{return 0}
        let total=zip(parts,materialIDs).reduce(0){total,pair in
            total+(ForgeMaterial.all.first{$0.id == pair.1}.map{pair.0.compatibility($0)} ?? 0)
        }
        return max(-6,min(6,total))
    }

    fileprivate func salePrice(materials:[ForgeMaterial],quality:Int)->Int? {
        guard let percent=Self.salePercents[quality] else{return nil}
        let value=materials.reduce(0){$0+$1.value}
        let labor=parts.count == 2 ? 4:7
        let special=specialName(materialIDs:materials.map(\.id)) == nil ? 0:5
        return (value*percent+50)/100+labor+special
    }

    private static let salePercents=[15:60,35:90,55:110,75:130,95:155,100:180]

    private static let grip=ForgePart(id:"grip",name:"握柄",preferred:["copper","iron","willow_twig","driftwood","zinc","platinum"])
    private static let wrap=ForgePart(id:"wrap",name:"缠带",preferred:["sheep_wool","alpaca_fibre","rabbit_fibre","cashmere","reef_silk","echo_vine"])
    private static let core=ForgePart(id:"gem",name:"杖芯",preferred:["quartz","moonstone","diamond","starlight_ore","fluorite","sunstone"])
    private static let lining=ForgePart(id:"lining",name:"衬里",preferred:["sheep_wool","rabbit_fibre","alpaca_fibre","cloud_fleece","cashmere","reef_silk"])
    private static let bodyMaterials=["iron","copper","rattan","sheep_wool","rabbit_fibre","alpaca_fibre","cloud_fleece","cashmere","reef_silk"]
    static let all:[ForgeMold]=[
        .init(id:"machete",name:"砍刀",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"blade",name:"厚刃",preferred:["iron","copper","obsidian","meteor_iron"]),grip],gathering:3,scouting:0,guarding:1),
        .init(id:"saber",name:"弯刀",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"blade",name:"弯刃",preferred:["iron","silver","obsidian","meteor_iron"]),grip],gathering:2,scouting:0,guarding:2),
        .init(id:"longsword",name:"长剑",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"blade",name:"长剑刃",preferred:["iron","starlight_ore","meteor_iron"]),grip,wrap],gathering:0,scouting:0,guarding:4),
        .init(id:"shortsword",name:"短剑",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"blade",name:"短剑刃",preferred:["iron","copper","obsidian"]),grip,wrap],gathering:1,scouting:1,guarding:2),
        .init(id:"wand",name:"魔杖",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"shaft",name:"细杖身",preferred:["willow_twig","driftwood"]),core],gathering:1,scouting:3,guarding:0),
        .init(id:"staff",name:"法杖",station:.furnace,slot:.tool,level:5,
              parts:[.init(id:"shaft",name:"长杖身",preferred:["driftwood","willow_twig","echo_vine"]),core,
                     .init(id:"frame",name:"杖箍",preferred:["copper","silver","iron","platinum"])],gathering:0,scouting:3,guarding:2),
        .init(id:"sword",name:"单手剑",station:.furnace,slot:.tool,level:5,parts:[.init(id:"blade",name:"剑刃",preferred:["iron","obsidian"]),.init(id:"grip",name:"剑柄",preferred:["copper","iron"]),.init(id:"wrap",name:"缠带",preferred:["sheep_wool","alpaca_fibre"])],gathering:1,scouting:0,guarding:1),
        .init(id:"sickle",name:"镰刀",station:.furnace,slot:.tool,level:5,parts:[.init(id:"blade",name:"镰刃",preferred:["copper","obsidian"]),.init(id:"grip",name:"握柄",preferred:["iron","copper"])],gathering:2,scouting:0,guarding:0),
        .init(id:"pendant",name:"吊坠",station:.furnace,slot:.charm,level:5,parts:[.init(id:"gem",name:"坠心",preferred:["quartz","moonstone","diamond","fluorite","sunstone"]),.init(id:"frame",name:"镶框",preferred:["silver","gold","tin","platinum"])],gathering:0,scouting:2,guarding:0),
        .init(id:"top",name:"上衣",station:.sewing,slot:.coat,level:5,
              parts:[.init(id:"body",name:"衣身",preferred:bodyMaterials),lining,
                     .init(id:"buckle",name:"衣扣",preferred:["copper","iron","moonstone","rattan"])],gathering:0,scouting:0,guarding:2),
        .init(id:"trousers",name:"下装",station:.sewing,slot:.trousers,level:5,
              parts:[.init(id:"body",name:"裤身",preferred:bodyMaterials),lining,
                     .init(id:"wrap",name:"系带",preferred:wrap.preferred+["rattan"])],gathering:0,scouting:0,guarding:2),
        .init(id:"coat",name:"外套",station:.sewing,slot:.coat,level:5,parts:[.init(id:"cloth",name:"衣身",preferred:["sheep_wool","cloud_fleece","reef_silk"]),.init(id:"lining",name:"衬里",preferred:["rabbit_fibre","alpaca_fibre"]),.init(id:"buckle",name:"衣扣",preferred:["copper","moonstone","platinum"])],gathering:0,scouting:0,guarding:2)
    ]
}

extension EconomyBalance {
    static func equipmentSalePrice(_ gear:CraftedGear)->Int? {
        if let recipe=CraftedGear.all.first(where:{$0.id == gear.id}) {
            let inputs=recipe.minerals.merging(recipe.materials,uniquingKeysWith:+)
            return inputs.reduce(recipe.price) {sum,part in
                let value=Mineral.all.first{$0.id == part.key}?.price ?? ForgeMaterial.all.first{$0.id == part.key}?.value ?? 0
                return sum+value*part.value
            }
        }
        guard let mold=ForgeMold.all.first(where:{gear.id.hasPrefix("forged_"+$0.id+"_") && gear.slot == $0.slot}) else{return nil}
        let prefix="forged_"+mold.id+"_"
        let encoded=gear.id.dropFirst(prefix.count)
        guard let suffix=encoded.lastIndex(of:"_"),encoded[suffix...].hasPrefix("_q") else{return nil}
        let digits=encoded[suffix...].dropFirst(2)
        guard let quality=Int(digits),String(quality) == digits else{return nil}
        let materialKey=encoded[..<suffix]
        var remaining=materialKey
        var materials:[ForgeMaterial]=[]
        for _ in mold.parts {
            guard let material=ForgeMaterial.all.first(where:{remaining == $0.id || remaining.hasPrefix($0.id+"_")}) else{return nil}
            materials.append(material)
            remaining=remaining.dropFirst(material.id.count+1)
        }
        guard materials.map(\.id).joined(separator:"_") == materialKey else{return nil}
        return mold.salePrice(materials:materials,quality:quality)
    }
}

extension CraftedGear {
    var description:String? {
        let baseName = name.components(separatedBy:" · ").first ?? name
        return ItemLore.text(for:"gear:"+baseName) ?? ItemLore.text(for:"gear:"+(forgeSprite ?? id))
    }
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
              result.roll.modifier == mold.modifier(materialIDs:result.materialIDs),
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
    func forgeMaterialCount(_ material:ForgeMaterial)->Int {
        if material.isMineral {return miningState.inventory[material.id,default:0]}
        if material.isForage {return expeditionState.inventory[material.id,default:0]}
        return garden.economy.finds[material.id,default:0]
    }
    func forgeModifier(mold:ForgeMold,materialIDs:[String])->Int {
        mold.modifier(materialIDs:materialIDs)
    }
    func canForge(mold:ForgeMold,materialIDs:[String])->Bool {
        guard levelProgress.level>=mold.level,materialIDs.count == mold.parts.count,expeditionState.gear.count<4096 else{return false}
        let counts=Dictionary(materialIDs.map{($0,1)},uniquingKeysWith:+)
        return counts.allSatisfy{id,count in
            guard let material=ForgeMaterial.all.first(where:{$0.id == id}) else{return false}
            return forgeMaterialCount(material)>=count
        }
    }
    mutating func forgeGear(moldID:String,materialIDs:[String],natural:Int?=nil)->Bool {
        guard let mold=ForgeMold.all.first(where:{$0.id == moldID}),canForge(mold:mold,materialIDs:materialIDs),
              natural.map({(1...20).contains($0)}) ?? true else{return false}
        let materials=materialIDs.compactMap{id in ForgeMaterial.all.first{$0.id == id}}
        guard let main=materials.first else{return false}
        let roll=CraftRoll(natural:natural ?? Int.random(in:1...20),modifier:forgeModifier(mold:mold,materialIDs:materialIDs))
        var result=ForgeResult(moldID:mold.id,materialIDs:materialIDs,roll:roll,name:roll.criticalFailure ? "锻造失败":mold.name)
        var expedition=expeditionState
        guard roll.criticalFailure || (expedition.gear[result.expectedGearID,default:0]<1_000_000_000
            && (expedition.generatedGear?[result.expectedGearID] != nil || (expedition.generatedGear?.count ?? 0)<4096)) else{return false}
        var mining=miningState
        for material in materials {
            if material.isMineral {mining.inventory[material.id,default:0]-=1}
            else if material.isForage {expedition.inventory[material.id,default:0]-=1}
            else {garden.economy.finds[material.id,default:0]-=1}
        }
        garden.economy.mining=mining
        if !roll.criticalFailure {
            let specialBonus=mold.specialName(materialIDs:materialIDs) == nil ? 0:1
            let name=mold.outputName(materialIDs:materialIDs)+" · "+roll.tierTitle
            let scale=max(1,roll.quality/20)
            let id=result.expectedGearID
            let item=expedition.generatedGear?[id] ?? CraftedGear(id:id,name:name,slot:mold.slot,level:mold.level,minerals:[:],price:0,
                gathering:min(30,(mold.gathering+materials.reduce(0){$0+$1.gathering})*scale/2+specialBonus),
                scouting:min(30,(mold.scouting+materials.reduce(0){$0+$1.scouting})*scale/2+specialBonus),
                guarding:min(30,(mold.guarding+materials.reduce(0){$0+$1.guarding})*scale/2+specialBonus),
                forgeSprite:mold.outputSprite(material:main),saleValue:mold.salePrice(materials:materials,quality:roll.quality))
            expedition.generatedGear=expedition.generatedGear ?? [:]
            expedition.generatedGear?[id]=item
            expedition.gear[id,default:0]+=1
            result.gearID=id;result.name=item.name
        }
        if !roll.criticalFailure || materials.contains(where:\.isForage) {garden.economy.expedition=expedition}
        garden.economy.forge=ForgeState(lastResult:result)
        return true
    }
}
