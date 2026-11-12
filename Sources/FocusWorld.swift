import Foundation

extension AppData {
    @discardableResult
    mutating func advanceFocusWorld(at date:Date,settleLegacy:Bool=true)->Bool {
        let focus=gameFocus(at:date)
        var changed=false
        for kind in [JourneyKind.fishing,.adventure] where settleLegacy {
            if let trip=garden.economy.trip(kind),trip.progress(focus)>=1 {
                changed = collectJourney(kind,at:date) != nil || changed
            }
        }
        changed = advanceAutoShop(to:focus) || changed
        changed = advanceRanch(to:focus) || changed
        changed = advancePond(to:focus) || changed
        let active=timer.map { $0.kind != .rest && $0.resumedAt != nil && ($0.kind == .stopwatch || $0.elapsed(at:date)<$0.target) } ?? false
        changed = advanceFishing(to:focus,active:active && garden.economy.trip(.fishing) == nil) || changed
        changed = advanceMining(to:focus) || changed
        changed = advanceExpedition(to:focus) || changed
        return changed
    }
}

struct NatureItemInfo {
    var name:String
    var spriteKey:String
    var price:Int
    static func find(_ id:String)->NatureItemInfo? {
        if let item=NatureCatalog.forage.first(where:{$0.id == id}) {return .init(name:item.name,spriteKey:item.spriteKey,price:item.salePrice)}
        if let animal=NatureCatalog.ranchSpecies.first(where:{$0.productID == id}) {return .init(name:animal.productName,spriteKey:"product_"+animal.id,price:animal.salePrice)}
        return mineral(id) ?? fishingCatch(id)
    }
    static func mineral(_ id:String)->NatureItemInfo? {
        Mineral.all.first(where:{$0.id == id}).map{.init(name:$0.name,spriteKey:$0.spriteKey,price:$0.price)}
    }
    static func fishingCatch(_ id:String)->NatureItemInfo? {
        if let fish=NatureCatalog.fish.first(where:{$0.id == id}) {return .init(name:fish.name,spriteKey:fish.spriteKey,price:fish.salePrice)}
        let miscellaneous=["waterweed":"水草","driftwood":"浮木","shell":"贝壳","river_pebble":"河卵石"]
        if let name=miscellaneous[id] {return .init(name:name,spriteKey:"material_"+id,price:1)}
        return nil
    }
}

extension AppData {
    mutating func prepareForage(_ id:String,count:Int)->Bool {
        guard let forage=NatureCatalog.forage.first(where:{$0.id == id}),forage.isCookable,
              let raw=forage.ingredient,let ingredient=Ingredient(rawValue:raw),count>0,
              garden.economy.expedition?.inventory[id,default:0] ?? 0 >= count,
              garden.ingredients[ingredient.rawValue,default:0]<=1_000_000_000-count else{return false}
        garden.economy.expedition?.inventory[id,default:0]-=count
        garden.ingredients[ingredient.rawValue,default:0]+=count
        return true
    }
    mutating func sellForage(_ id:String,count:Int)->Bool {
        guard let item=NatureItemInfo.find(id),count>0,
              garden.economy.expedition?.inventory[id,default:0] ?? 0 >= count,
              garden.coins<=1_000_000_000_000-item.price*count else{return false}
        garden.economy.expedition?.inventory[id,default:0]-=count
        garden.coins+=item.price*count;return true
    }
    mutating func compostWaterweed()->Bool {
        guard var fish=garden.economy.fishing,fish.inventory["waterweed",default:0]>=5,
              garden.plots.contains(where:{$0.crop != nil}) else{return false}
        fish.inventory["waterweed",default:0]-=5;garden.economy.fishing=fish
        for index in garden.plots.indices where garden.plots[index].crop != nil {garden.plots[index].bonus+=60}
        return true
    }
    mutating func useRanchFertilizer()->Bool {
        guard garden.economy.finds["mooncalf_dung",default:0]>0,garden.plots.contains(where:{$0.crop != nil}) else{return false}
        garden.economy.finds["mooncalf_dung",default:0]-=1
        for index in garden.plots.indices where garden.plots[index].crop != nil {garden.plots[index].bonus+=180}
        return true
    }
}
