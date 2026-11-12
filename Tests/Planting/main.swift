import Foundation

@main enum PlantingChecks {
    static func check(_ condition:Bool,file:StaticString=#file,line:UInt=#line) {
        precondition(condition,file:file,line:line)
    }
    static func encoded<T:Encodable>(_ value:T) throws -> Data {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        return try encoder.encode(value)
    }
    static func fixture(fields:Int=1,seeds:[String:Int]=[Crop.carrot.rawValue:3],water:Int=20)->AppData {
        var data=AppData()
        data.preferences.sound=false
        data.garden.cropSeeds=seeds;data.garden.water=water;data.garden.coins=4321
        data.garden.plots=(0..<(fields*6)).map{_ in Plot()}
        data.garden.economy.upgrades[Upgrade.farmland.rawValue]=fields-1
        return data
    }
    @MainActor static func main() throws {
        let now=Date()
        var single=fixture()
        let ids=single.garden.plots.map(\.id)
        for id in ids.prefix(3) {check(single.plant(.carrot,in:id,at:now))}
        check(single.garden.cropSeeds[Crop.carrot.rawValue] == 0 && single.garden.water == 17)
        let exhausted=try encoded(single)
        check(!single.plant(.carrot,in:ids[3],at:now))
        check(try encoded(single) == exhausted)
        single.garden.cropSeeds[Crop.mint.rawValue]=2
        let occupied=try encoded(single)
        check(!single.plant(.mint,in:ids[0],at:now))
        check(!single.plant(.mint,in:UUID(),at:now))
        check(try encoded(single) == occupied)

        var few=fixture(seeds:[Crop.mint.rawValue:1,Crop.starlightCarrot.rawValue:2])
        check(few.plantRandomly(at:now) == 3)
        check(few.garden.plots.filter{$0.crop != nil}.count == 3)
        check(few.garden.cropSeeds.values.allSatisfy{$0 == 0} && few.garden.water == 17 && few.garden.coins == 4321)
        let noSeeds=try encoded(few)
        check(try few.plantRandomly(at:now) == 0 && encoded(few) == noSeeds)

        var dry=fixture(water:0)
        let noWater=try encoded(dry)
        check(try dry.plantRandomly(at:now) == 0 && encoded(dry) == noWater)
        check(!dry.plant(.carrot,in:dry.garden.plots[0].id,at:now))
        var limited=fixture(seeds:[Crop.carrot.rawValue:8,Crop.mint.rawValue:8],water:2)
        check(limited.plantRandomly(at:now) == 2)
        check(limited.garden.seeds == 14 && limited.garden.water == 0)

        var currentField = fixture(fields:3,seeds:[Crop.carrot.rawValue:5],water:4)
        for index in [6, 8, 9, 11] {
            currentField.garden.plots[index].crop = .tomato
        }
        let seededBefore = try encoded(currentField)
        check(try currentField.plantRandomly(startingOn:-1,at:now) == 0 && encoded(currentField) == seededBefore)
        check(try currentField.plantRandomly(startingOn:3,at:now) == 0 && encoded(currentField) == seededBefore)
        check(currentField.plantRandomly(startingOn:1,at:now) == 4)
        check(currentField.garden.plots.indices.filter { currentField.garden.plots[$0].crop == .carrot } == [7, 10, 12, 13])
        check(currentField.garden.seeds == 1 && currentField.garden.water == 0)
        var lastField = fixture(fields:3,seeds:[Crop.mint.rawValue:2],water:5)
        for index in 12..<17 { lastField.garden.plots[index].crop = .tomato }
        check(lastField.plantRandomly(startingOn:2,at:now) == 2)
        check(lastField.garden.plots.indices.filter { lastField.garden.plots[$0].crop == .mint } == [0, 17])
        check(lastField.garden.seeds == 0 && lastField.garden.water == 3)

        for fields in [2,3] {
            var expanded=fixture(fields:fields,seeds:[Crop.carrot.rawValue:30],water:30)
            expanded.garden.plots[0]=Plot(id:expanded.garden.plots[0].id,crop:.tomato,plantedAt:0,duration:900,bonus:60)
            let existing=try encoded(expanded.garden.plots[0])
            let count=fields*6-1
            check(expanded.plantRandomly(at:now) == count)
            check(try encoded(expanded.garden.plots[0]) == existing)
            check(expanded.garden.plots.allSatisfy{$0.crop != nil})
            check(expanded.garden.seeds == 30-count && expanded.garden.water == 30-count && expanded.garden.coins == 4321)
            let full=try encoded(expanded)
            check(try expanded.plantRandomly(at:now) == 0 && encoded(expanded) == full)
            _ = try expanded.validated()
        }

        var timed=fixture(seeds:[Crop.carrot.rawValue:6])
        let started=now.addingTimeInterval(-240)
        timed.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:started,resumedAt:started)
        check(timed.plant(.carrot,in:timed.garden.plots[0].id,at:now))
        check(timed.plantRandomly(at:now) == 5)
        check(timed.garden.plots.allSatisfy{$0.plantedAt == 240 && $0.progress(timed.gameFocus(at:now)) == 0})
        _ = try timed.validated(at:now)
        let later=now.addingTimeInterval(60)
        timed.timer?.pause(at:later)
        check(timed.garden.plots.allSatisfy{abs($0.progress(timed.gameFocus(at:later))-0.1) < 0.0001})
        check(timed.gameFocus(at:later.addingTimeInterval(600)) == 300)
        _ = timed.finishTimer(at:later)
        check(timed.garden.plots.allSatisfy{abs($0.progress(timed.totalFocus)-0.1) < 0.0001})
        _ = try timed.validated(at:later)

        var replanted=fixture(seeds:[Crop.carrot.rawValue:2])
        replanted.garden.economy.finds["bloom"]=2
        replanted.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now,resumedAt:nil,
                                gameReminders:GameReminderOptions(enabled:[.crops]),notifiedGameEvents:[])
        let reusedPlot=replanted.garden.plots[0].id
        check(replanted.plant(.carrot,in:reusedPlot,at:now))
        check(replanted.usePotion("bloom") && replanted.usePotion("bloom"))
        check(replanted.takeGameNotices(at:now).count == 1)
        check(replanted.harvest(reusedPlot,at:now) && replanted.plant(.carrot,in:reusedPlot,at:now))
        replanted.timer?.resume(at:now)
        let mature=now.addingTimeInterval(600)
        check(replanted.garden.plots[0].progress(replanted.gameFocus(at:mature)) == 1)
        check(replanted.takeGameNotices(at:mature).count == 1)
        check(replanted.takeGameNotices(at:mature).isEmpty)

        let store=GardenStore(preview:true)
        let manager=FileManager.default
        let folder=store.file.deletingLastPathComponent()
        check(folder.lastPathComponent == "Daygarden-Preview-\(ProcessInfo.processInfo.processIdentifier)")
        defer {store.storageLocked=true;try? manager.removeItem(at:folder)}
        store.data=fixture(fields:3,seeds:[Crop.carrot.rawValue:4,Crop.mint.rawValue:3],water:20)
        check(store.commitGameChange{$0.plant(.mint,in:$0.garden.plots[0].id,at:now)})
        var count=0
        check(store.commitGameChange{count=$0.plantRandomly(startingOn:1,at:now);return count > 0})
        check(count == 6)
        let persisted=try SaveFile.read(store.file)
        check(try encoded(persisted.garden) == encoded(store.data.validated().garden))
        check(persisted.garden.plots.indices.filter { persisted.garden.plots[$0].crop != nil } == [0, 6, 7, 8, 9, 10, 11])
        check(persisted.garden.cropSeeds.values.allSatisfy{$0 >= 0} && persisted.garden.water == 13)

        store.data=fixture(seeds:[Crop.carrot.rawValue:4],water:10)
        check(store.save())
        let previous=try encoded(store.data)
        let disk=try Data(contentsOf:store.file)
        let backup=folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at:store.file,to:backup)
        try manager.createDirectory(at:store.file,withIntermediateDirectories:false)
        try Data([1]).write(to:store.file.appendingPathComponent("blocked"))
        check(!store.commitGameChange{$0.plant(.carrot,in:$0.garden.plots[0].id,at:now)})
        check(try encoded(store.data) == previous)
        check(!store.commitGameChange{$0.plantRandomly(at:now) > 0})
        check(try encoded(store.data) == previous)
        check(try Data(contentsOf:backup) == disk)
        check(store.saveStatus == "保存失败")
        RunLoop.main.run(until:Date().addingTimeInterval(0.65))
        check(try store.saveStatus == "保存失败" && Data(contentsOf:backup) == disk)
        try manager.removeItem(at:store.file);try manager.moveItem(at:backup,to:store.file)

        let soup=Dish.allCases.first{$0.id == "胡萝卜浓汤"}!
        var shop=fixture()
        shop.garden.dishes[soup.id]=1
        check(shop.stock(soup,at:now))
        let order=shop.garden.orders[0]
        shop.garden.economy.upgrades[Upgrade.shop.rawValue]=3
        check(shop.garden.orders[0].price == order.price)
        shop.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:300)]
        check(shop.collectSale(order.id,at:now) && shop.garden.coins == 4321+order.price)
        check(!shop.collectSale(order.id,at:now))
        print("PASS: repeated planting, exhausted/occupied guards, current field and page order, seed and water limits, expanded fields, new-crop reminders, saved inventory, failed-save rollback, frozen sale proceeds")
    }
}
