import Foundation

@main enum FocusWorldChecks {
    static func check(_ value:Bool,file:StaticString=#file,line:UInt=#line) {precondition(value,file:file,line:line)}
    static func encoded<T:Encodable>(_ value:T)throws->Data {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        return try encoder.encode(value)
    }
    static func fixture(at now:Date)->AppData {
        var data=AppData()
        let seconds=Double((1..<30).reduce(0){$0+LevelProgress.requirement($1)}*60)
        data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds)]
        data.preferences.sound=false;data.preferences.notifications=false
        data.garden.coins=50_000
        data.garden.dishes=[Dish.soup.id:1000]
        data.garden.ingredients[Ingredient.carrot.rawValue]=100
        data.garden.ingredients["薄荷"]=2
        data.garden.economy.autoShop=AutoShopState(enabled:true,dishIDs:[Dish.soup.id],lastAdvancedFocus:seconds)
        data.garden.order=ShopOrder(dish:.soup,placedAt:seconds,proceeds:123)
        data.garden.economy.ranch=RanchState(animals:[RanchAnimal(speciesID:"chicken")],trough:24,lastFocus:seconds)
        data.garden.economy.fishing=FishingState(enabled:true,baitID:"earthworm",baitStock:["earthworm":1000],
            cast:FishingCast(startedFocus:seconds,duration:120,locationID:"lake",baitID:"earthworm",rodID:"willow"),
            random:FocusRandom(state:456),lastFocus:seconds)
        data.garden.economy.mining=MiningState(layers:["quarry_coal":MineProgress(lastFocus:seconds)],selectedLayer:"quarry_coal",inventory:["copper":20,"coal":20])
        data.garden.economy.expedition=ExpeditionState(inventory:["moon_herb":2],random:FocusRandom(state:789))
        check(data.embarkExpedition(locationID:"forest",minutes:1440,at:now))
        data.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now.addingTimeInterval(-600),resumedAt:now.addingTimeInterval(-600))
        return data
    }
    static func sameWorld(_ first:AppData,_ second:AppData) {
        check(first.garden.autoShopState == second.garden.autoShopState)
        check(first.ranchState == second.ranchState)
        check(first.fishingState == second.fishingState)
        check(first.miningState == second.miningState)
        check(first.expeditionState == second.expeditionState)
    }
    static func completionFixture(at now:Date)->AppData {
        var data=AppData()
        data.preferences.sound=false;data.preferences.notifications=false
        let focus=Double((1..<8).reduce(0){$0+LevelProgress.requirement($1)}*60)
        data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:focus)]
        data.garden.economy.fishing=FishingState(enabled:true,cast:FishingCast(startedFocus:focus,duration:60,locationID:"lake",rodID:"willow"),random:FocusRandom(state:1),lastFocus:focus)
        data.garden.economy.expedition=ExpeditionState(random:FocusRandom(state:2))
        check(data.embarkExpedition(locationID:"forest",minutes:1,at:now))
        return data
    }

    @MainActor static func main() throws {
        let now=Date().addingTimeInterval(60)
        let store=GardenStore(preview:true)
        defer {store.storageLocked=true;try? FileManager.default.removeItem(at:store.file.deletingLastPathComponent())}
        store.now=now;store.data=fixture(at:now)
        check(store.save())
        let baseline=try encoded(store.data)
        let disk=try Data(contentsOf:store.file)
        let backup=store.file.deletingLastPathComponent().appendingPathComponent("focus-world-readable.json")
        try FileManager.default.moveItem(at:store.file,to:backup)
        try FileManager.default.createDirectory(at:store.file,withIntermediateDirectories:false)
        let actions:[(String,(inout AppData)->Bool)]=[
            ("shop collection",{$0.collectShopProceeds(at:now)>0}),
            ("ranch purchase",{$0.buyRanchFeed(at:now)}),
            ("fishing purchase",{$0.buyFishingBait("earthworm")} ),
            ("mining selection",{$0.selectMine("quarry_coal",at:now)}),
            ("equipment crafting",{$0.forgeGear(moldID:"sickle",materialIDs:["copper","copper"],natural:12)} ),
            ("expedition forage",{data in
                guard let trip=data.expeditionState.trip,let id=trip.rewards.keys.sorted().first else{return false}
                return data.collectExpeditionForage(id,at:trip.locationID)
            }),
            ("expedition return",{$0.returnExpedition(at:now)}),
            ("cooking",{$0.cook(.soup,natural:16)}),
            ("potion brewing",{$0.embark(.potions,recipe:"dew",at:now)})
        ]
        for (_,edit) in actions {
            var edited=false
            check(!store.commitGameChange {data in edited=edit(&data);return edited})
            check(edited)
            check(try encoded(store.data) == baseline)
        }
        check(try Data(contentsOf:backup) == disk)
        try FileManager.default.removeItem(at:store.file)
        try FileManager.default.moveItem(at:backup,to:store.file)
        let oldSeeds=store.data.garden.seeds
        check(store.commitGameChange{$0.buySeeds(.carrot)})
        check(store.data.garden.seeds == oldSeeds+1)
        check(store.data.garden.autoShopState.soldCount == 2 && store.data.ranchState.animals[0].progress == 600)
        check(!store.data.fishingState.catches.isEmpty && store.data.miningState.inventory["coal",default:0]>20)
        check(store.data.expeditionState.trip!.events == 2)
        let saved=try SaveFile.read(store.file)
        sameWorld(store.data,saved)
        check(saved.garden.coins == store.data.garden.coins && saved.garden.dishes == store.data.garden.dishes)
        print("PASS: failed writes roll back every focus world state, inventory and money; successful retry persists each advancement once")

        let good=store.data
        var invalid:[AppData]=[]
        var bad=good;bad.garden.economy.autoShop?.receivables += 1;invalid.append(bad)
        bad=good;bad.garden.economy.ranch?.animals[0].speciesID="unknown";invalid.append(bad)
        bad=good;bad.garden.economy.fishing?.rodID="unknown";invalid.append(bad)
        bad=good;bad.garden.economy.mining?.inventory["unknown"]=1;invalid.append(bad)
        bad=good;bad.garden.economy.expedition?.team=["unknown"];invalid.append(bad)
        for value in invalid {
            do {_ = try value.validated(at:now);preconditionFailure("Invalid focus world state accepted")}
            catch { }
        }

        var legacy=fixture(at:now)
        legacy.timer=nil
        legacy.garden.economy.autoShop=nil;legacy.garden.economy.ranch=nil;legacy.garden.economy.fishing=nil
        legacy.garden.economy.mining=nil;legacy.garden.economy.expedition=nil
        let legacyFocus=legacy.totalFocus
        legacy.garden.order=ShopOrder(dish:.soup,placedAt:legacyFocus-300,proceeds:4321)
        legacy.garden.economy.journeys=[Journey(kind:.fishing,startedAt:legacyFocus-900,duration:900),Journey(kind:.adventure,startedAt:legacyFocus-1200,duration:1200)]
        legacy.garden.economy.upgrades[Upgrade.wand.rawValue]=2
        legacy.garden.economy.finds=["星砂":7]
        legacy.tasks=[GardenTask(title:"整理材料",notes:"保留正文")]
        legacy.habits=[Habit(title:"阅读")]
        legacy.diaries=[dayKey(now):Diary(text:"旧日记")]
        let oldURL=store.file.deletingLastPathComponent().appendingPathComponent("v017.json")
        try SaveFile.write(legacy,to:oldURL)
        var loaded=try SaveFile.read(oldURL)
        check(loaded.garden.economy.autoShop == nil && loaded.garden.economy.expedition == nil)
        let oldCoins=loaded.garden.coins,oldDishes=loaded.garden.dishes,oldIngredients=loaded.garden.ingredients
        let oldTasks=loaded.tasks,oldHabits=loaded.habits,oldDiaries=loaded.diaries
        check(loaded.advanceFocusWorld(at:now))
        check(loaded.garden.economy.activeJourneys.isEmpty && loaded.garden.economy.expeditions == 2)
        check(loaded.garden.economy.finds["星砂"] == 7 && loaded.garden.economy.finds["银鳞鱼"] == 1 && loaded.garden.economy.finds["琥珀石"] == 3)
        check(loaded.garden.autoShopState.receivables == 4321 && loaded.garden.orders.isEmpty)
        check(loaded.garden.dishes == oldDishes && loaded.garden.ingredients == oldIngredients && loaded.garden.coins == oldCoins)
        check(loaded.tasks == oldTasks && loaded.habits == oldHabits && loaded.diaries == oldDiaries)
        check(loaded.tasks[0].id == legacy.tasks[0].id && loaded.tasks[0].notes == "保留正文" && loaded.habits[0].id == legacy.habits[0].id)
        check(loaded.collectShopProceeds(at:now) == 4321 && loaded.collectShopProceeds(at:now) == 0)
        _ = try loaded.validated(at:now)
        print("PASS: old saves retain planning records, ingredients, dishes, money, legacy journey rewards and exact pending shop prices")

        var jump=fixture(at:now),stepped=jump
        check(jump.advanceFocusWorld(at:now.addingTimeInterval(86400)))
        for value in stride(from:0,through:86400,by:113) {stepped.advanceFocusWorld(at:now.addingTimeInterval(Double(value)))}
        stepped.advanceFocusWorld(at:now.addingTimeInterval(86400))
        check(jump.garden.dishes == stepped.garden.dishes && jump.garden.autoShopState.receivables == stepped.garden.autoShopState.receivables)
        check(jump.ranchState == stepped.ranchState && jump.miningState == stepped.miningState && jump.expeditionState == stepped.expeditionState)
        check(jump.fishingState.inventory == stepped.fishingState.inventory && jump.fishingState.random == stepped.fishingState.random)
        check(jump.fishingState.cast?.startedFocus == stepped.fishingState.cast?.startedFocus && jump.fishingState.cast?.duration == stepped.fishingState.cast?.duration)

        store.storageLocked=true
        let reopened=GardenStore(preview:true)
        defer {reopened.storageLocked=true}
        reopened.now=now
        check(reopened.data.timer?.resumedAt == nil && reopened.data.timer?.accumulated == 600)
        sameWorld(reopened.data,saved)
        reopened.tick(now.addingTimeInterval(10000))
        sameWorld(reopened.data,saved)
        check(reopened.finishTimer(at:now.addingTimeInterval(10000)))
        reopened.data.pomodoroBreakReady=true
        check(reopened.startTimer(kind:.rest,minutes:5,task:nil,at:now.addingTimeInterval(10000)))
        let beforeRest=reopened.data
        reopened.tick(now.addingTimeInterval(10180))
        sameWorld(reopened.data,beforeRest)
        reopened.tick(now.addingTimeInterval(10300))
        sameWorld(reopened.data,beforeRest)
        check(reopened.data.timer == nil)
        print("PASS: long updates match frequent updates; restart pauses progress and rest leaves every game clock fixed")

        reopened.data=fixture(at:now)
        reopened.data.timer=nil
        reopened.data.garden.order=nil;reopened.data.garden.dishes=[Dish.soup.id:0]
        reopened.data.garden.economy.autoShop=AutoShopState(enabled:true,dishIDs:[Dish.soup.id],lastAdvancedFocus:reopened.data.totalFocus)
        reopened.now=now
        check(reopened.startTimer(kind:.stopwatch,minutes:30,task:nil,at:now.addingTimeInterval(-600)))
        reopened.now=now
        check(reopened.commitGameChange{$0.cook(.soup,natural:16)})
        let cookedAt=reopened.gameFocus
        check(reopened.data.garden.sales == 0 && reopened.data.garden.orders.first?.placedAt == cookedAt)
        reopened.tick(now.addingTimeInterval(299))
        check(reopened.data.garden.sales == 0)
        reopened.tick(now.addingTimeInterval(300))
        check(reopened.data.garden.sales == 1)

        reopened.data=AppData();reopened.data.preferences.sound=false
        let levelThree=Double((LevelProgress.requirement(1)+LevelProgress.requirement(2))*60)
        reopened.data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:levelThree)]
        reopened.data.garden.economy.fishing=FishingState(enabled:true,baitID:"earthworm",baitStock:["earthworm":20],random:FocusRandom(state:99),lastFocus:levelThree)
        check(reopened.startTimer(kind:.countdown,minutes:5,task:nil,at:now))
        check(reopened.data.fishingState.cast != nil && reopened.data.fishingState.baitStock["earthworm"] == 19)
        reopened.data.garden.economy.fishing?.cast?.duration=300
        reopened.tick(now.addingTimeInterval(300))
        check(reopened.data.timer == nil && reopened.data.fishingState.cast == nil)
        check(reopened.data.fishingState.catches.count == 1 && reopened.data.fishingState.baitStock["earthworm"] == 19)
        reopened.tick(now.addingTimeInterval(600))
        check(reopened.data.fishingState.cast == nil && reopened.data.fishingState.baitStock["earthworm"] == 19)
        check(reopened.startTimer(kind:.countdown,minutes:2,task:nil,at:now.addingTimeInterval(600)))
        check(reopened.data.fishingState.baitStock["earthworm"] == 18)
        reopened.data.garden.economy.fishing?.cast?.duration=120
        check(reopened.pauseTimer(at:now.addingTimeInterval(660)))
        let pausedCast=reopened.data.fishingState.cast
        reopened.tick(now.addingTimeInterval(990))
        check(reopened.data.fishingState.cast == pausedCast && reopened.data.fishingState.baitStock["earthworm"] == 18)
        check(reopened.resumeTimer(at:now.addingTimeInterval(1000)))
        reopened.tick(now.addingTimeInterval(1060))
        check(reopened.data.timer == nil && reopened.data.fishingState.cast == nil)
        check(reopened.data.fishingState.catches.count == 2 && reopened.data.fishingState.baitStock["earthworm"] == 18)
        print("PASS: cooking cannot create backdated sales; fishing starts consume one bait and deadline catches settle without another cast")

        let reminderOptions=GameReminderOptions(enabled:[.fishing,.adventure])
        reopened.data=completionFixture(at:now)
        check(reopened.startTimer(kind:.countdown,minutes:1,task:nil,gameReminders:reminderOptions,at:now))
        let beforeDeadline=try encoded(reopened.data)
        reopened.message="截止前"
        let deadlineBackup=store.file.deletingLastPathComponent().appendingPathComponent("deadline-readable.json")
        try FileManager.default.moveItem(at:reopened.file,to:deadlineBackup)
        try FileManager.default.createDirectory(at:reopened.file,withIntermediateDirectories:false)
        check(!reopened.finishTimer(at:now.addingTimeInterval(60)))
        check(try encoded(reopened.data) == beforeDeadline)
        check(reopened.message == "截止前" && reopened.data.fishingState.catches.isEmpty && reopened.data.expeditionState.history.isEmpty)
        check(reopened.data.fishingState.inventory.isEmpty && reopened.data.expeditionState.inventory.isEmpty)
        try FileManager.default.removeItem(at:reopened.file)
        try FileManager.default.moveItem(at:deadlineBackup,to:reopened.file)
        check(reopened.finishTimer(at:now.addingTimeInterval(60)))
        check(reopened.data.timer == nil && reopened.data.fishingState.catches.count == 1 && reopened.data.expeditionState.history.count == 1)
        check(reopened.message.contains("钓鱼完成") && reopened.message.contains("已放入库存") && reopened.message.contains("已放进行囊"))
        let finalFish=reopened.data.fishingState.inventory,finalLoot=reopened.data.expeditionState.inventory
        let finalMessage=reopened.message
        reopened.tick(now.addingTimeInterval(120))
        check(reopened.data.fishingState.inventory == finalFish && reopened.data.expeditionState.inventory == finalLoot)
        check(reopened.deliverGameReminders(at:now.addingTimeInterval(120)).isEmpty && reopened.message == finalMessage)
        print("PASS: final-second fish and expedition notices follow one successful save; failed finish emits no notice, markers or rewards")

        reopened.data=completionFixture(at:now)
        check(reopened.startTimer(kind:.countdown,minutes:1,task:nil,at:now))
        check(reopened.data.timer?.gameReminders?.enabled.isEmpty == true)
        check(reopened.finishTimer(at:now.addingTimeInterval(60)))
        check(reopened.data.fishingState.catches.count == 1 && reopened.data.expeditionState.history.count == 1)
        check(!reopened.message.contains("已放入库存") && !reopened.message.contains("已放进行囊"))

        var archives=completionFixture(at:now)
        archives.garden.economy.fishing?.enabled=false;archives.garden.economy.fishing?.cast=nil
        archives.garden.economy.expedition?.trip=nil
        let archiveFocus=archives.totalFocus
        let fishID=NatureCatalog.fish.first{$0.locations.contains("lake")}!.id
        archives.garden.economy.fishing?.inventory=[fishID:1]
        archives.garden.economy.fishing?.catches=[FishingCatch(itemID:fishID,focus:archiveFocus-1,locationID:"lake")]
        let oldRecord=ExpeditionRecord(id:UUID(),locationID:"forest",duration:60,plannedDuration:60,completed:true,companions:[],rewards:["moon_herb":1],discoveries:[])
        archives.garden.economy.expedition?.inventory=["moon_herb":1]
        archives.garden.economy.expedition?.history=[oldRecord]
        reopened.data=archives
        check(reopened.startTimer(kind:.stopwatch,minutes:30,task:nil,gameReminders:reminderOptions,at:now))
        check(reopened.deliverGameReminders(at:now).isEmpty)
        reopened.data.garden.economy.fishing?.catches.append(FishingCatch(itemID:fishID,focus:archiveFocus+1,locationID:"lake"))
        reopened.data.garden.economy.fishing?.inventory[fishID,default:0]+=1
        var newRecord=oldRecord;newRecord.id=UUID();newRecord.rewards=["moon_herb":2]
        reopened.data.garden.economy.expedition?.history.append(newRecord)
        reopened.data.garden.economy.expedition?.inventory["moon_herb",default:0]+=2
        reopened.now=now.addingTimeInterval(1)
        let notices=reopened.deliverGameReminders(at:reopened.now)
        check(notices.count == 2 && notices.allSatisfy{!$0.text.contains("可领取")})
        check(notices.first{$0.kind == .fishing}?.text.contains("1 份") == true)
        check(notices.first{$0.kind == .adventure}?.text.contains("2 份") == true)
        check(reopened.deliverGameReminders(at:reopened.now).isEmpty)
        let notified=try SaveFile.read(reopened.file)
        check(notified.timer?.notifiedGameEvents == reopened.data.timer?.notifiedGameEvents)
        reopened.data.garden.economy.fishing?.catches.append(FishingCatch(focus:archiveFocus+2,locationID:"lake"))
        reopened.now=now.addingTimeInterval(2)
        let markers=reopened.data.timer?.notifiedGameEvents
        try FileManager.default.moveItem(at:reopened.file,to:deadlineBackup)
        try FileManager.default.createDirectory(at:reopened.file,withIntermediateDirectories:false)
        check(reopened.deliverGameReminders(at:reopened.now).isEmpty && reopened.data.timer?.notifiedGameEvents == markers)
        try FileManager.default.removeItem(at:reopened.file)
        try FileManager.default.moveItem(at:deadlineBackup,to:reopened.file)
        let emptyCast=reopened.deliverGameReminders(at:reopened.now)
        check(emptyCast.count == 1 && emptyCast[0].text.contains("空钩") && !emptyCast[0].text.contains("放入库存"))
        check(reopened.deliverGameReminders(at:reopened.now).isEmpty)
        print("PASS: new reminders default off, skip prior records at start, persist one-time markers and retry unmarked delivery after write failure")
    }
}
