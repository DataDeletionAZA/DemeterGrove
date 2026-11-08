import Foundation

struct PotionSelection {
    enum Kind {case ingredient,material}
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
        guard available>portions.filter({$0.name == name && $0.kind == kind}).count,
              portions.count<2 else{return false}
        let slot=(0..<2).first{candidate in !portions.contains{$0.slot == candidate}}!
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
    static func materialName(_ value:String)->String {all.first{$0.forageID == value}?.material ?? value}
}

extension AppData {
    func potionMaterialCount(_ value:String)->Int {
        let name=Potion.materialName(value)
        guard let id=Potion.all.first(where:{$0.material == name})?.forageID else {return garden.economy.finds[name,default:0]}
        return garden.economy.finds[name,default:0] + garden.economy.finds[id,default:0] + (garden.economy.expedition?.inventory[id,default:0] ?? 0)
    }
    var potionMaterialNames:[String] {
        Set(Potion.all.map(\.material)).filter{potionMaterialCount($0)>0}.sorted()
    }
    mutating func consumePotionMaterials(_ potion:Potion)->Bool {
        guard garden.ingredients[potion.ingredient,default:0]>0,potionMaterialCount(potion.material)>0 else {return false}
        let keys=[potion.material,potion.forageID].compactMap{$0}
        if let key=keys.first(where:{garden.economy.finds[$0,default:0]>0}) {garden.economy.finds[key,default:0]-=1}
        else if let id=potion.forageID,garden.economy.expedition?.inventory[id,default:0] ?? 0 > 0 {
            garden.economy.expedition?.inventory[id,default:0]-=1
        } else {return false}
        garden.ingredients[potion.ingredient,default:0]-=1
        return true
    }
}
