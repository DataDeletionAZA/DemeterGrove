import Foundation

struct FocusRandom: Codable, Equatable {
    var state: UInt64 = UInt64.random(in:1...UInt64.max)
    mutating func next(_ bound:Int)->Int {
        state &+= 0x9e3779b97f4a7c15
        var value=state
        value=(value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value=(value ^ (value >> 27)) &* 0x94d049bb133111eb
        return Int((value ^ (value >> 31)) % UInt64(max(1,bound)))
    }
}

struct FishingRod:Identifiable {
    let id:String
    let name:String
    let level:Int
    let price:Int
    let rank:Int
    let speed:Double
    var spriteKey:String {"rod_"+id}
    static let all:[FishingRod]=[
        .init(id:"willow",name:"柳木钓竿",level:3,price:0,rank:0,speed:1),
        .init(id:"ash",name:"白蜡木钓竿",level:5,price:30,rank:1,speed:0.95),
        .init(id:"river",name:"河行钓竿",level:10,price:60,rank:2,speed:0.90),
        .init(id:"ocean",name:"潮汐钓竿",level:15,price:100,rank:3,speed:0.85),
        .init(id:"star",name:"星纹钓竿",level:25,price:180,rank:4,speed:0.80),
        .init(id:"reedglass",name:"芦晶钓竿",level:30,price:225,rank:5,speed:0.77),
        .init(id:"storm",name:"风纹钓竿",level:40,price:315,rank:6,speed:0.74),
        .init(id:"abyssal",name:"深渊钓竿",level:45,price:425,rank:7,speed:0.71)
    ]
}

struct FishingCast:Codable,Equatable {
    var startedFocus:Double
    var duration:Double
    var locationID:String
    var baitID:String?
    var rodID:String
}
struct FishingCatch:Codable,Equatable,Identifiable {
    var id=UUID()
    var itemID:String?
    var focus:Double
    var locationID:String
}
struct FishingState:Codable,Equatable {
    var enabled=false
    var locationID="lake"
    var rodID="willow"
    var baitID:String?
    var ownedRods:Set<String>=["willow"]
    var baitStock:[String:Int]=[:]
    var cast:FishingCast?
    var random=FocusRandom()
    var inventory:[String:Int]=[:]
    var lifetime:[String:Int]=[:]
    var catches:[FishingCatch]=[]
    var emptyCasts=0
    var lastFocus:Double?
}

struct FishingLocation:Identifiable {
    let id:String
    let regionID:String
    let habitatID:String
    let waterType:NatureWaterType
    let name:String
    let level:Int
    let minimum:Int
    let maximum:Int
    let background:String
    func contains(_ fish:NatureFish)->Bool {
        fish.locations.contains(regionID) && fish.fishingHabitatIDs.contains(habitatID) && fish.waterTypes.contains(waterType)
    }
    func accepts(_ bait:NatureBait)->Bool {
        bait.locations.contains(regionID) && bait.waterTypes.contains(waterType)
    }
    var fish:[NatureFish] {NatureCatalog.fish.filter{contains($0)}}
    var baits:[NatureBait] {NatureCatalog.baits.filter{accepts($0)}}
    static let all:[FishingLocation]=[
        .init(id:"lake",regionID:"lake",habitatID:"temperate_lake",waterType:.fresh,name:"暮色湖",level:3,minimum:120,maximum:300,background:"Lake"),
        .init(id:"reed_marsh",regionID:"marsh",habitatID:"reed_marsh",waterType:.fresh,name:"芦苇湿地",level:8,minimum:210,maximum:360,background:"ReedMarsh"),
        .init(id:"river",regionID:"river",habitatID:"lowland_river",waterType:.fresh,name:"河谷缓流",level:10,minimum:150,maximum:330,background:"River"),
        .init(id:"river_cool",regionID:"river",habitatID:"cool_river",waterType:.fresh,name:"清流上游",level:10,minimum:150,maximum:330,background:"River"),
        .init(id:"mountains",regionID:"mountains",habitatID:"mountain_lake",waterType:.fresh,name:"高山湖区",level:12,minimum:150,maximum:360,background:"MountainLake"),
        .init(id:"beach",regionID:"beach",habitatID:"coast",waterType:.salt,name:"潮间海岸",level:15,minimum:180,maximum:360,background:"Beach"),
        .init(id:"tropical",regionID:"tropical",habitatID:"tropical_river",waterType:.fresh,name:"雨林水湾",level:18,minimum:120,maximum:300,background:"Tropical"),
        .init(id:"sea",regionID:"sea",habitatID:"cool_shelf",waterType:.salt,name:"冷流海域",level:20,minimum:210,maximum:420,background:"Sea"),
        .init(id:"sea_warm",regionID:"sea",habitatID:"warm_pelagic",waterType:.salt,name:"暖流远洋",level:20,minimum:360,maximum:600,background:"SeaWarm"),
        .init(id:"polar",regionID:"polar",habitatID:"polar_lake",waterType:.fresh,name:"冰原湖",level:25,minimum:210,maximum:420,background:"Polar"),
        .init(id:"polar_coast",regionID:"polar",habitatID:"polar_coast",waterType:.salt,name:"极地近岸",level:25,minimum:210,maximum:420,background:"PolarCoast"),
        .init(id:"coral_lagoon",regionID:"reef",habitatID:"coral_lagoon",waterType:.salt,name:"珊瑚潟湖",level:28,minimum:225,maximum:435,background:"CoralLagoon"),
        .init(id:"mist_highland",regionID:"highland",habitatID:"mist_highland",waterType:.fresh,name:"云雾高地",level:35,minimum:240,maximum:420,background:"MistHighland"),
        .init(id:"abyss",regionID:"abyss",habitatID:"abyss",waterType:.salt,name:"深海崖岸",level:45,minimum:360,maximum:600,background:"AbyssCoast")
    ]
}

extension FishingState {
    static let focusLimit:Double=1_000_000_000_000
    func isValid(focus:Double)->Bool {
        let rods=Set(FishingRod.all.map(\.id)),baits=Set(NatureCatalog.baits.map(\.id))
        let goods=Set(NatureCatalog.fish.map(\.id)+["waterweed","driftwood","shell","river_pebble"])
        guard focus.isFinite,focus>=0,focus<Self.focusLimit,
              FishingLocation.all.contains(where:{$0.id == locationID}),rods.contains(rodID),ownedRods.contains(rodID),
              ownedRods.isSubset(of:rods),ownedRods.contains("willow"),baitID.map({baits.contains($0)}) ?? true,
              baitStock.allSatisfy({baits.contains($0.key) && (0...1_000_000_000).contains($0.value)}),
              inventory.allSatisfy({goods.contains($0.key) && (0...1_000_000_000).contains($0.value)}),
              lifetime.allSatisfy({goods.contains($0.key) && (0...1_000_000_000).contains($0.value)}),
              (0...1_000_000_000).contains(emptyCasts),catches.count<=32,
              lastFocus.map({$0.isFinite && $0>=0 && $0<=focus}) ?? true else {return false}
        if let cast {
            guard cast.startedFocus.isFinite,cast.startedFocus>=0,cast.startedFocus<=focus,
                  cast.duration.isFinite,(60...600).contains(cast.duration),ownedRods.contains(cast.rodID),
                  FishingLocation.all.contains(where:{$0.id == cast.locationID}),cast.baitID.map({baits.contains($0)}) ?? true else {return false}
        }
        return catches.allSatisfy { item in item.focus.isFinite && item.focus>=0 && item.focus<=focus && (item.itemID.map{goods.contains($0)} ?? true) && FishingLocation.all.contains(where:{$0.id == item.locationID}) }
    }
    private mutating func beginCast(at focus:Double) {
        guard let location=FishingLocation.all.first(where:{$0.id == locationID}),let rod=FishingRod.all.first(where:{$0.id == rodID}) else{return}
        let usable=baitID.flatMap {id in location.baits.first{$0.id == id && baitStock[id,default:0]>0}}
        if let usable {baitStock[usable.id,default:0]-=1}
        let speed:Double
        switch usable?.id {case "glow_paste":speed=0.85;case "earthworm","shrimp","squid","minnow","reed_nymph","reef_crab","alpine_grub","abyss_light":speed=0.90;case nil:speed=1;default:speed=0.95}
        let seconds=Double(location.minimum+random.next(location.maximum-location.minimum+1))*rod.speed*speed
        cast=FishingCast(startedFocus:focus,duration:max(60,seconds.rounded()),locationID:locationID,baitID:usable?.id,rodID:rodID)
    }
    private mutating func catchItem(_ cast:FishingCast,level:Int)->String? {
        guard let rod=FishingRod.all.first(where:{$0.id == cast.rodID}),
              let location=FishingLocation.all.first(where:{$0.id == cast.locationID}) else{return nil}
        let usableBait=cast.baitID.flatMap{id in location.baits.first{$0.id == id}?.id}
        let roll=random.next(100),fishChance=55+(usableBait == nil ? 0:15)+min(10,rod.rank*2)
        if roll<fishChance {
            let choices=location.fish.filter {$0.level<=level && rod.rank >= $0.minimumRodRank}
            let weights=choices.map {fish in fish.rarity.weight*(fish.baitIDs.contains(usableBait ?? "") ? 3:1)}
            let total=weights.reduce(0,+)
            guard total>0 else{return "waterweed"}
            var selection=random.next(total)
            for (fish,weight) in zip(choices,weights) {selection-=weight;if selection<0{return fish.id}}
        }
        if roll<fishChance+(usableBait == nil ? 28:14) {return "waterweed"}
        if roll<96 {return location.waterType == .salt ? "shell":random.next(2) == 0 ? "driftwood":"river_pebble"}
        return nil
    }
    @discardableResult
    mutating func advance(to focus:Double,active:Bool,level:Int)->Bool {
        let before=self
        guard focus.isFinite,focus>=0,focus<Self.focusLimit else{return false}
        let previous=lastFocus ?? focus
        guard focus>=previous else{return false}
        if !enabled {
            if cast != nil {cast?.startedFocus += focus-previous}
            lastFocus=focus
            return self != before
        }
        if cast == nil,active {beginCast(at:focus)}
        var rounds=0
        while let current=cast,focus>=current.startedFocus+current.duration,rounds<10_000 {
            let finished=current.startedFocus+current.duration
            let item=catchItem(current,level:level)
            if let item {
                inventory[item]=min(1_000_000_000,inventory[item,default:0]+1)
                lifetime[item]=min(1_000_000_000,lifetime[item,default:0]+1)
            } else {emptyCasts=min(1_000_000_000,emptyCasts+1)}
            catches.append(FishingCatch(itemID:item,focus:finished,locationID:current.locationID))
            catches=Array(catches.suffix(32));cast=nil;rounds+=1
            if finished<focus || active {beginCast(at:finished)}
        }
        lastFocus=focus
        return self != before
    }
}

extension AppData {
    var fishingState:FishingState {garden.economy.fishing ?? FishingState()}
    @discardableResult mutating func advanceFishing(to focus:Double,active:Bool)->Bool {
        guard var state=garden.economy.fishing else{return false}
        let changed=state.advance(to:focus,active:active,level:levelProgress.level)
        if changed {garden.economy.fishing=state}
        return changed
    }
    mutating func configureFishing(enabled:Bool,location:String,rod:String,bait:String?,at date:Date=Date())->Bool {
        guard garden.economy.trip(.fishing) == nil else{return false}
        guard let place=FishingLocation.all.first(where:{$0.id == location}),levelProgress.level>=place.level,
              let selectedRod=FishingRod.all.first(where:{$0.id == rod}),levelProgress.level>=selectedRod.level,
              bait.map({id in place.baits.contains{$0.id == id && $0.level<=levelProgress.level}}) ?? true else{return false}
        let focus=gameFocus(at:date)
        guard focus.isFinite,focus>=0,focus<FishingState.focusLimit else{return false}
        let active=timer.map{$0.kind != .rest && $0.resumedAt != nil && ($0.kind == .stopwatch || $0.elapsed(at:date)<$0.target)} ?? false
        var state=fishingState
        // Existing rod upgrades remain owned when continuous fishing is first configured.
        for known in FishingRod.all where known.rank<=garden.rank(.rod) {state.ownedRods.insert(known.id)}
        guard state.ownedRods.contains(rod) else{return false}
        state.advance(to:focus,active:active,level:levelProgress.level)
        state.lastFocus=focus;state.enabled=enabled;state.locationID=location;state.rodID=rod;state.baitID=bait
        state.advance(to:focus,active:active,level:levelProgress.level)
        garden.economy.fishing=state;return true
    }
    mutating func buyFishingRod(_ id:String)->Bool {
        guard let rod=FishingRod.all.first(where:{$0.id == id}),levelProgress.level>=rod.level,garden.coins>=rod.price else{return false}
        var state=fishingState
        guard !state.ownedRods.contains(id),rod.rank>garden.rank(.rod) else{return false}
        garden.coins-=rod.price;state.ownedRods.insert(id);garden.economy.fishing=state;return true
    }
    mutating func buyFishingBait(_ id:String,count:Int=1)->Bool {
        guard let bait=NatureCatalog.baits.first(where:{$0.id == id}),levelProgress.level>=bait.level,(1...100).contains(count),garden.coins>=bait.price*count else{return false}
        var state=fishingState
        guard state.baitStock[id,default:0]<=1_000_000_000-count else{return false}
        garden.coins-=bait.price*count;state.baitStock[id,default:0]+=count;garden.economy.fishing=state;return true
    }
    mutating func sellFishingCatch(_ id:String,count:Int)->Bool {
        var state=fishingState
        let price=NatureItemInfo.fishingCatch(id)?.price ?? 0
        guard price>0,count>0,state.inventory[id,default:0]>=count,garden.coins<=1_000_000_000_000-price*count else{return false}
        state.inventory[id,default:0]-=count;garden.coins+=price*count;garden.economy.fishing=state;return true
    }
    mutating func prepareFish(_ id:String,count:Int)->Bool {
        var state=fishingState
        guard let ingredient=NatureCatalog.fish.first(where:{$0.id == id})?.cookingIngredient,
              count>0,state.inventory[id,default:0]>=count else{return false}
        guard garden.ingredients[ingredient.rawValue,default:0]<=1_000_000_000-count else{return false}
        state.inventory[id,default:0]-=count;garden.ingredients[ingredient.rawValue,default:0]+=count
        garden.economy.fishing=state;return true
    }
}
