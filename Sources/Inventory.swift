import Foundation

enum InventoryCategory:String,CaseIterable,Identifiable {
    case all="全部",crop="作物",ingredient="食材",prepared="半成品",dish="成品",seed="种子",material="材料",item="道具",clothing="服饰"
    var id:String {rawValue}
}

struct InventoryEntry:Identifiable,Equatable {
    enum Artwork:Equatable {case ingredient(String),dish(Int),seed(Crop),material,item,clothing(String?),nature(String)}
    var id:String
    var name:String
    var category:InventoryCategory
    var count:Int
    var artwork:Artwork
}

extension AppData {
    var inventory:[InventoryEntry] {
        let prepared=Set([Ingredient.cookedRice,.noodles,.cakeBase,.bread,.roastedTea])
        var result:[InventoryEntry]=Ingredient.allCases.compactMap {ingredient in
            let count=ingredientCount(ingredient)
            guard count>0 else{return nil}
            let category:InventoryCategory=prepared.contains(ingredient) ? .prepared:Crop(rawValue:ingredient.rawValue) != nil ? .crop:.ingredient
            return InventoryEntry(id:"ingredient:"+ingredient.rawValue,name:ingredient.rawValue,category:category,count:count,artwork:.ingredient(ingredient.rawValue))
        }
        result += garden.menu.compactMap {dish in
            let count=garden.dishes[dish.id,default:0]
            guard count>0 else{return nil}
            return InventoryEntry(id:"dish:"+dish.id,name:dish.name,category:.dish,count:count,artwork:.dish(dish.sprite))
        }
        result += Crop.allCases.compactMap {crop in
            let count=garden.cropSeeds[crop.rawValue,default:0]
            guard count>0 else{return nil}
            return InventoryEntry(id:"seed:"+crop.rawValue,name:crop.rawValue+"种子",category:.seed,count:count,artwork:.seed(crop))
        }
        result += garden.economy.finds.keys.sorted().compactMap {name in
            let count=garden.economy.finds[name,default:0]
            guard count>0,Ingredient(rawValue:name) == nil else{return nil}
            let potion=Potion.all.first{$0.id == name}
            let natural=NatureItemInfo.find(name)
            return InventoryEntry(id:"find:"+name,name:potion?.name ?? natural?.name ?? name,category:potion == nil ? .material:.item,count:count,artwork:natural.map{.nature($0.spriteKey)} ?? (potion == nil ? .material:.item))
        }
        for (prefix,items) in [("fishing",garden.economy.fishing?.inventory ?? [:]),("forage",garden.economy.expedition?.inventory ?? [:]),("mining",garden.economy.mining?.inventory ?? [:])] {
            result += items.keys.sorted().compactMap {id in
                guard let item=NatureItemInfo.find(id),items[id,default:0]>0 else{return nil}
                return InventoryEntry(id:prefix+":"+id,name:item.name,category:.material,count:items[id,default:0],artwork:.nature(item.spriteKey))
            }
        }
        result += NatureCatalog.baits.compactMap {bait in
            let count=garden.economy.fishing?.baitStock[bait.id,default:0] ?? 0
            return count>0 ? InventoryEntry(id:"bait:"+bait.id,name:bait.name,category:.item,count:count,artwork:.nature(bait.spriteKey)):nil
        }
        result += CraftedGear.all.compactMap {gear in
            let count=garden.economy.expedition?.gear[gear.id,default:0] ?? 0
            return count>0 ? InventoryEntry(id:"gear:"+gear.id,name:gear.name,category:.item,count:count,artwork:.nature(gear.spriteKey)):nil
        }
        result += Cosmetic.all.filter{garden.economy.owned.contains($0.id)}.map {item in
            InventoryEntry(id:"clothing:"+item.id,name:item.name,category:.clothing,count:1,artwork:.clothing(item.asset))
        }
        if garden.water>0 {result.append(.init(id:"water",name:"露水",category:.item,count:garden.water,artwork:.item))}
        return result.sorted {($0.category.rawValue,$0.name,$0.id)<($1.category.rawValue,$1.name,$1.id)}
    }
    func inventory(category:InventoryCategory,search:String)->[InventoryEntry] {
        let query=search.trimmingCharacters(in:.whitespacesAndNewlines)
        return inventory.filter {(category == .all || $0.category == category) && (query.isEmpty || $0.name.localizedStandardContains(query))}
    }
    mutating func unstock(_ id:UUID, at date:Date=Date())->Bool {
        guard let order=garden.orders.first(where:{$0.id == id}),!order.ready(gameFocus(at:date)) else{return false}
        if garden.order?.id == id {garden.order=nil}
        else {garden.economy.extraOrders.removeAll{$0.id == id}}
        garden.dishes[order.dish.id,default:0]+=1
        return true
    }
}
