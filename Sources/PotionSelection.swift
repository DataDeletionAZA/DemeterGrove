import Foundation

struct PotionSelection {
    enum Kind: String, Codable {case ingredient,material}
    struct Portion:Identifiable {
        let id=UUID()
        var name:String
        var kind:Kind
        var slot:Int
        var droppedAt=Date()
    }
    private(set) var portions:[Portion]=[]
    mutating func add(_ name:String,kind:Kind,available:Int)->Bool {
        let name=kind == .material ? Potion.materialName(name):name
        guard available>0, !portions.contains(where:{$0.name == name && $0.kind == kind}),
              AlchemyMaterial(name:name,kind:kind).profile != nil, portions.count<5 else{return false}
        let slot=(0..<5).first{candidate in !portions.contains{$0.slot == candidate}}!
        portions.append(Portion(name:name,kind:kind,slot:slot));return true
    }
    mutating func remove(_ id:UUID) {portions.removeAll{$0.id == id}}
    mutating func clear() {portions=[]}
    func count(_ name:String,kind:Kind)->Int {
        let name=kind == .material ? Potion.materialName(name):name
        return portions.filter{$0.name == name && $0.kind == kind}.count
    }
    func matches(_ potion:Potion)->Bool {
        portions.count == 2 && count(potion.ingredient,kind:.ingredient) == 1 && count(potion.material,kind:.material) == 1
    }
}

extension Potion {
    var forageID:String? {
        switch material {case "月光草":return "moon_herb";case "琥珀石":return "amber";case "星砂":return "star_sand";default:return nil}
    }
    static func materialName(_ value:String)->String {
        all.first{$0.forageID == value}?.material ?? NatureCatalog.forage.first{$0.id == value}?.name ?? value
    }
}

extension AppData {
    func potionMaterialCount(_ value:String)->Int {
        let name=Potion.materialName(value)
        guard let id=NatureCatalog.forage.first(where:{$0.name == name})?.id else {return garden.economy.finds[name,default:0]}
        return garden.economy.finds[name,default:0] + garden.economy.finds[id,default:0] + (garden.economy.expedition?.inventory[id,default:0] ?? 0)
    }
    var potionMaterialNames:[String] {
        Set(NatureCatalog.forage.map(\.name)).filter{potionMaterialCount($0)>0}.sorted()
    }
    mutating func consumePotionMaterials(_ potion:Potion)->Bool {
        guard garden.ingredients[potion.ingredient,default:0]>0,potionMaterialCount(potion.material)>0 else {return false}
        guard consumePotionMaterial(potion.material) else{return false}
        garden.ingredients[potion.ingredient,default:0]-=1
        return true
    }
    mutating func consumePotionMaterial(_ material:String)->Bool {
        let name=Potion.materialName(material)
        let id=NatureCatalog.forage.first{$0.name == name}?.id
        let keys=[name,id].compactMap{$0}
        if let key=keys.first(where:{garden.economy.finds[$0,default:0]>0}) {garden.economy.finds[key,default:0]-=1}
        else if let id,garden.economy.expedition?.inventory[id,default:0] ?? 0 > 0 {
            garden.economy.expedition?.inventory[id,default:0]-=1
        } else {return false}
        return true
    }
}
