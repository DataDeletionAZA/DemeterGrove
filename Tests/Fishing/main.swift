import Foundation

@main enum FishingChecks {
    static func check(_ value:Bool,file:StaticString=#file,line:UInt=#line) {precondition(value,file:file,line:line)}
    static func encoded<T:Encodable>(_ value:T)throws->Data {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return try encoder.encode(value)
    }
    static func fixture(level:Int=50)->AppData {
        var data=AppData();data.preferences.sound=false;data.preferences.notifications=false;data.garden.coins=20_000
        let minutes=(1..<level).reduce(0){$0+LevelProgress.requirement($1)}
        data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:Date(),seconds:Double(minutes*60))]
        return data
    }
    static func sameProgress(_ first:FishingState,_ second:FishingState) {
        check(first.inventory == second.inventory && first.lifetime == second.lifetime)
        check(first.random == second.random && first.cast == second.cast && first.baitStock == second.baitStock)
        check(first.emptyCasts == second.emptyCasts && first.lastFocus == second.lastFocus)
        check(first.catches.map(\.itemID) == second.catches.map(\.itemID))
        check(first.catches.map(\.focus) == second.catches.map(\.focus))
        check(first.catches.map(\.locationID) == second.catches.map(\.locationID))
    }
    static func started(location:String="lake",rod:String="star",bait:String?="earthworm",stock:Int=10_000)->FishingState {
        var state=FishingState(enabled:true,locationID:location,rodID:rod,baitID:bait,
            ownedRods:Set(FishingRod.all.map(\.id)),baitStock:bait.map{[$0:stock]} ?? [:],random:FocusRandom(state:12345))
        check(state.advance(to:0,active:true,level:50));return state
    }
    @MainActor static func main() throws {
        let now=Date()
        var automatic=fixture()
        check(automatic.configureFishing(enabled:true,location:"lake",rod:"willow",bait:nil,at:now))
        check(automatic.fishingState.cast == nil)
        automatic.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now,resumedAt:now)
        check(automatic.advanceFocusWorld(at:now) && automatic.fishingState.cast != nil)
        check(automatic.advanceFocusWorld(at:now.addingTimeInterval(400)))
        check(!automatic.fishingState.catches.isEmpty)

        var frozen=started(stock:2)
        frozen.advance(to:30,active:true,level:50)
        let remaining=frozen.cast!.startedFocus+frozen.cast!.duration-30
        frozen.enabled=false
        let stockBefore=frozen.baitStock,randomBefore=frozen.random,inventoryBefore=frozen.inventory
        frozen.advance(to:30_000,active:true,level:50)
        check(frozen.baitStock == stockBefore && frozen.random == randomBefore && frozen.inventory == inventoryBefore)
        check(frozen.cast!.startedFocus+frozen.cast!.duration-30_000 == remaining)
        frozen.enabled=true;frozen.advance(to:30_000+remaining,active:false,level:50)
        check(frozen.catches.count == 1 && frozen.cast == nil)

        var depleted=started(stock:1)
        check(depleted.baitStock["earthworm"] == 0 && depleted.cast?.baitID == "earthworm")
        depleted.advance(to:1000,active:true,level:50)
        check(depleted.cast?.baitID == nil && depleted.baitStock["earthworm"] == 0 && !depleted.catches.isEmpty)
        var incompatible=started(location:"polar_coast",bait:"earthworm",stock:2)
        check(incompatible.cast?.baitID == nil && incompatible.baitStock["earthworm"] == 2)
        incompatible.advance(to:500,active:true,level:50)
        check(incompatible.baitStock["earthworm"] == 2)
        var oldBait=FishingState(enabled:true,locationID:"polar_coast",cast:FishingCast(startedFocus:0,duration:120,locationID:"polar_coast",baitID:"earthworm",rodID:"willow"),random:FocusRandom(state:8),lastFocus:0)
        var noBait=oldBait;noBait.cast?.baitID=nil
        oldBait.advance(to:120,active:false,level:50);noBait.advance(to:120,active:false,level:50)
        sameProgress(oldBait,noBait)

        var jump=started(),steps=jump
        jump.advance(to:86400,active:true,level:50)
        for seconds in stride(from:17,through:86394,by:17) {steps.advance(to:Double(seconds),active:true,level:50)}
        steps.advance(to:86400,active:true,level:50);sameProgress(jump,steps)
        let unchanged=try encoded(jump)
        for invalid in [-1.0,Double.nan,.infinity,1e308,FishingState.focusLimit,86399] {
            check(!jump.advance(to:invalid,active:true,level:50));check(try encoded(jump) == unchanged)
        }
        check(!jump.isValid(focus:.infinity) && !jump.isValid(focus:FishingState.focusLimit))
        var backlog=started(),chunked=backlog
        backlog.advance(to:3_000_000,active:true,level:50)
        check(backlog.cast!.startedFocus+backlog.cast!.duration<=3_000_000)
        while backlog.cast!.startedFocus+backlog.cast!.duration<=3_000_000 {backlog.advance(to:3_000_000,active:true,level:50)}
        for seconds in stride(from:100_000,through:3_000_000,by:100_000) {chunked.advance(to:Double(seconds),active:true,level:50)}
        sameProgress(backlog,chunked)

        var paused=automatic
        let pauseDate=now.addingTimeInterval(450)
        paused.timer?.pause(at:pauseDate);paused.advanceFocusWorld(at:pauseDate)
        let pauseState=paused.fishingState
        check(!paused.advanceFocusWorld(at:pauseDate.addingTimeInterval(999)) && paused.fishingState == pauseState)
        _=paused.finishTimer(at:pauseDate)
        paused.timer=TimerRun(kind:.rest,target:300,taskTitle:"休息",startedAt:pauseDate,resumedAt:pauseDate)
        check(!paused.advanceFocusWorld(at:pauseDate.addingTimeInterval(300)) && paused.fishingState == pauseState)

        let places=Dictionary(uniqueKeysWithValues:FishingLocation.all.map{($0.id,$0)})
        let fish=Dictionary(uniqueKeysWithValues:NatureCatalog.fish.map{($0.id,$0)})
        check(Set(["lake","river","mountains","beach","tropical","sea","polar"]).isSubset(of:Set(places.keys)))
        check(places["mountains"]!.name == "高山湖区")
        check(places["river_cool"]!.background == "River" && places["polar_coast"]!.background == "PolarCoast" && places["sea_warm"]!.background == "SeaWarm")
        check(!places["polar"]!.contains(fish["capelin"]!) && places["polar_coast"]!.contains(fish["capelin"]!))
        check(places["polar"]!.contains(fish["arctic_char"]!) && !places["polar_coast"]!.contains(fish["arctic_char"]!))
        check(!places["river"]!.contains(fish["brown_trout"]!) && places["river_cool"]!.contains(fish["brown_trout"]!))
        check(!places["sea"]!.contains(fish["yellowfin_tuna"]!) && places["sea_warm"]!.contains(fish["yellowfin_tuna"]!))
        var observed=Set<String>()
        for place in FishingLocation.all {
            check(!place.fish.isEmpty && !place.baits.isEmpty)
            check(place.fish.allSatisfy{$0.fishingHabitatIDs.contains(place.habitatID) && $0.waterTypes.contains(place.waterType)})
            check(place.baits.allSatisfy{$0.locations.contains(place.regionID) && $0.waterTypes.contains(place.waterType)})
            var state=started(location:place.id,rod:"abyssal",bait:place.baits.first!.id,stock:10_000)
            state.advance(to:1_000_000,active:true,level:50)
            for id in state.lifetime.keys where fish[id] != nil {check(place.contains(fish[id]!));observed.insert(id)}
            check(state.isValid(focus:1_000_000))
        }
        check(observed == Set(fish.keys))
        for specimen in NatureCatalog.fish {
            check(FishingLocation.all.contains{place in place.contains(specimen) && place.baits.contains{specimen.baitIDs.contains($0.id)}})
        }
        let errors=NatureCatalog.validationErrors()
        precondition(errors.isEmpty,errors.joined(separator:"\n"))
        for (id,level,habitat,bait) in [
            ("reed_marsh",8,"reed_marsh","reed_nymph"),
            ("coral_lagoon",28,"coral_lagoon","reef_crab"),
            ("mist_highland",35,"mist_highland","alpine_grub"),
            ("abyss",45,"abyss","abyss_light")
        ] {
            let place=places[id]!
            check(place.level == level && place.habitatID == habitat && place.fish.count == 4)
            check(place.baits.contains{$0.id == bait && $0.level == level})
            var before=fixture(level:level-1), unlocked=fixture(level:level)
            check(!before.buyFishingBait(bait))
            check(!before.configureFishing(enabled:true,location:id,rod:"willow",bait:nil,at:now))
            let price=place.baits.first{$0.id == bait}!.price
            let startingCoins=unlocked.garden.coins
            check(unlocked.buyFishingBait(bait,count:5))
            check(unlocked.fishingState.baitStock[bait] == 5 && unlocked.garden.coins == startingCoins-price*5)
            check(unlocked.configureFishing(enabled:true,location:id,rod:"willow",bait:bait,at:now))
            let saved=try JSONDecoder().decode(AppData.self,from:encoded(unlocked))
            _=try saved.validated(at:now)
            check(saved.fishingState == unlocked.fishingState)
        }
        for id in ["reedglass","storm","abyssal"] {
            let rod=FishingRod.all.first{$0.id == id}!
            let previous=FishingRod.all[rod.rank-1]
            check(rod.speed < previous.speed && rod.speed >= 0.70)
            var locked=fixture(level:rod.level-1),unlocked=fixture(level:rod.level)
            check(!locked.buyFishingRod(id))
            let startingCoins=unlocked.garden.coins
            check(unlocked.buyFishingRod(id) && !unlocked.buyFishingRod(id))
            check(unlocked.garden.coins == startingCoins-rod.price && unlocked.fishingState.ownedRods.contains(id))
        }
        for (id,fishID,required,previous,level) in [
            ("coral_lagoon","pearl_mantle","reedglass","star",30),
            ("mist_highland","cloud_koi","storm","reedglass",40),
            ("abyss","abyssal_comet","abyssal","storm",45)
        ] {
            var good=started(location:id,rod:required,bait:"spiral_spoon")
            var lowLevel=good, lowRank=started(location:id,rod:previous,bait:"spiral_spoon")
            let elapsed=1_000_000.0
            good.advance(to:elapsed,active:true,level:level)
            lowLevel.advance(to:elapsed,active:true,level:level-1)
            lowRank.advance(to:elapsed,active:true,level:level)
            check(good.lifetime[fishID,default:0]>0)
            check(lowLevel.lifetime[fishID] == nil && lowRank.lifetime[fishID] == nil)
            let coins=good.lifetime.reduce(0){sum,row in
                sum+row.value*(NatureItemInfo.fishingCatch(row.key)?.price ?? 0)
            }
            check(Double(coins)*3600/elapsed < 120)
        }
        for id in ["reed_nymph","reef_crab","alpine_grub","abyss_light","spiral_spoon"] {
            check(NatureCatalog.fish.contains{$0.baitIDs.contains(id)})
        }
        var wrongBait=started(location:"abyss",rod:"abyssal",bait:"alpine_grub",stock:5)
        wrongBait.advance(to:5000,active:true,level:45)
        check(wrongBait.cast?.baitID == nil && wrongBait.baitStock["alpine_grub"] == 5)
        var lowRod=started(location:"sea_warm",bait:nil);lowRod.rodID="willow";lowRod.cast?.rodID="willow"
        lowRod.advance(to:100_000,active:true,level:50)
        check(lowRod.lifetime.keys.allSatisfy{fish[$0]?.rarity != .legendary})

        var trade=fixture()
        trade.garden.economy.fishing=FishingState(inventory:["common_carp":9,"arapaima":2,"waterweed":3],lifetime:["common_carp":9,"arapaima":2,"waterweed":3])
        let initialCoins=trade.garden.coins,initialFillets=trade.garden.ingredients[Ingredient.fishFillet.rawValue,default:0]
        check(trade.sellFishingCatch("common_carp",count:3) && trade.prepareFish("common_carp",count:4))
        check(trade.fishingState.inventory["common_carp"] == 2 && trade.fishingState.lifetime["common_carp"] == 9)
        check(trade.garden.coins == initialCoins+3*fish["common_carp"]!.salePrice)
        check(trade.garden.ingredients[Ingredient.fishFillet.rawValue] == initialFillets+4)
        let priorTrade=try encoded(trade)
        check(!trade.sellFishingCatch("common_carp",count:3) && !trade.prepareFish("arapaima",count:1))
        check(!trade.sellFishingCatch("unknown",count:1) && !trade.prepareFish("common_carp",count:0))
        check(!trade.sellFishingCatch("common_carp",count:Int.max) && !trade.prepareFish("common_carp",count:Int.max))
        check(try encoded(trade) == priorTrade)
        check(trade.sellFishingCatch("waterweed",count:3) && trade.fishingState.inventory["waterweed"] == 0)

        var preparation=fixture()
        preparation.garden.economy.fishing=FishingState(inventory:["silver_scale":1,"moonlight":1,"golden_stripe":1,"driftwood":1])
        for (id,ingredient) in [("silver_scale",Ingredient.silverFish),("moonlight",.moonFish),("golden_stripe",.goldFish)] {
            let before=preparation.ingredientCount(ingredient)
            check(preparation.prepareFish(id,count:1))
            check(preparation.ingredientCount(ingredient) == before+1 && preparation.fishingState.inventory[id] == 0)
        }
        preparation.garden.economy.expedition=ExpeditionState(inventory:["driftwood":1,"quartz":1])
        preparation.garden.economy.mining=MiningState(inventory:["quartz":1])
        let inventory=Dictionary(uniqueKeysWithValues:preparation.inventory.map{($0.id,$0)})
        check(inventory["fishing:driftwood"]?.name == "浮木" && inventory["forage:driftwood"]?.name == "海漂木")
        check(inventory["mining:quartz"]?.name == "石英" && inventory["forage:quartz"]?.name == "石英晶簇")
        preparation.garden.economy.fishing?.catches=[FishingCatch(itemID:"driftwood",focus:0,locationID:"lake")]
        check(preparation.gameReadyEvents(at:now).contains{$0.kind == .fishing && $0.name == "浮木"})
        let beforeDriftwood=preparation.garden.coins
        check(preparation.sellFishingCatch("driftwood",count:1))
        check(preparation.garden.coins == beforeDriftwood+1 && preparation.expeditionState.inventory["driftwood"] == 1)

        var oldCast=started(location:"sea_warm",bait:nil)
        oldCast.cast?.duration=240
        check(oldCast.isValid(focus:120))
        oldCast.advance(to:239,active:true,level:25)
        check(oldCast.catches.isEmpty)
        oldCast.advance(to:240,active:true,level:25)
        check(oldCast.catches.count == 1)
        check((288...480).contains(oldCast.cast!.duration))

        var upgraded=fixture();upgraded.garden.economy.upgrades[Upgrade.rod.rawValue]=3
        let priorLegacyPurchase=try encoded(upgraded)
        check(!upgraded.buyFishingRod("ocean"))
        check(try encoded(upgraded) == priorLegacyPurchase)
        check(upgraded.configureFishing(enabled:true,location:"sea",rod:"ocean",bait:"squid",at:now))
        check(Set(["willow","ash","river","ocean"]).isSubset(of:upgraded.fishingState.ownedRods))
        let priorUpgrade=try encoded(upgraded)
        check(!upgraded.configureFishing(enabled:true,location:"sea_warm",rod:"star",bait:nil,at:now))
        check(!upgraded.configureFishing(enabled:true,location:"polar_coast",rod:"ocean",bait:"earthworm",at:now))
        check(try encoded(upgraded) == priorUpgrade)
        let roundtrip=try JSONDecoder().decode(AppData.self,from:encoded(upgraded))
        check(roundtrip.fishingState == upgraded.fishingState);_ = try roundtrip.validated(at:now)
        var locked=AppData();check(!locked.configureFishing(enabled:true,location:"lake",rod:"willow",bait:nil,at:now))
        check(locked.garden.economy.fishing == nil)

        var switching=fixture()
        switching.garden.economy.fishing=FishingState(enabled:true,locationID:"polar_coast",rodID:"star",baitID:"squid",
            ownedRods:Set(FishingRod.all.map(\.id)),baitStock:["squid":4],random:FocusRandom(state:90))
        switching.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now,resumedAt:now)
        switching.advanceFocusWorld(at:now)
        let previousCast=switching.fishingState.cast!
        check(switching.configureFishing(enabled:true,location:"sea_warm",rod:"ocean",bait:"minnow",at:now))
        check(switching.fishingState.cast == previousCast && switching.fishingState.locationID == "sea_warm")
        switching.advanceFocusWorld(at:now.addingTimeInterval(previousCast.duration))
        check(switching.fishingState.catches.last?.locationID == "polar_coast")
        check(switching.fishingState.cast?.locationID == "sea_warm" && switching.fishingState.cast?.rodID == "ocean")
        if let caught=switching.fishingState.catches.last?.itemID,let specimen=fish[caught] {check(places["polar_coast"]!.contains(specimen))}

        let store=GardenStore(preview:true),manager=FileManager.default
        let folder=store.file.deletingLastPathComponent()
        defer {store.storageLocked=true;try? manager.removeItem(at:folder)}
        store.data=trade;store.now=now
        check(store.save() && store.commitGameChange{$0.sellFishingCatch("common_carp",count:1)})
        check(try SaveFile.read(store.file).fishingState == store.data.fishingState)
        let disk=try Data(contentsOf:store.file),priorStore=try encoded(store.data),backup=folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at:store.file,to:backup);try manager.createDirectory(at:store.file,withIntermediateDirectories:false)
        try Data([1]).write(to:store.file.appendingPathComponent("blocked"))
        check(!store.commitGameChange{$0.prepareFish("common_carp",count:1)})
        check(try encoded(store.data) == priorStore && Data(contentsOf:backup) == disk)
        try manager.removeItem(at:store.file);try manager.moveItem(at:backup,to:store.file)
        print("PASS: fishing automatic start, disabled freeze, bait depletion, pause/rest, seeded long-step and backlog equivalence, finite clocks, all \(fish.count) fish reachable in valid habitats, location and rod gates, trade conservation, legacy rods, persistence and failed-save rollback")
    }
}
