import Foundation

@main enum RanchChecks {
    static func check(_ condition: Bool, file: StaticString = #file, line: UInt = #line) {
        precondition(condition, file: file, line: line)
    }
    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    static func fixture(focus: Double = 0) -> AppData {
        var data = AppData()
        data.preferences.sound = false
        data.garden.coins = 10000
        if focus > 0 { data.sessions = [FocusSession(id: UUID(), title: "阅读", kind: .stopwatch, date: Date(), seconds: focus)] }
        return data
    }
    static func validate(_ data: AppData, at date: Date, label: String) {
        do { _ = try data.validated(at: date) }
        catch { preconditionFailure("Invalid ranch fixture: " + label + " — " + String(describing: error)) }
    }
    @MainActor static func main() throws {
        let now = Date()
        let chicken = NatureCatalog.ranchSpecies.first { $0.id == "chicken" }!
        let cow = NatureCatalog.ranchSpecies.first { $0.id == "cow" }!
        check(chicken.productionMinutes == 15 && chicken.ingredient == "鸡蛋")
        check(cow.ingredient == "牛奶")
        var fresh = fixture()
        check(fresh.garden.economy.ranch == nil && !fresh.advanceRanch(to: 999))
        check(fresh.buyRanchAnimal("chicken", at: now))
        check(fresh.garden.coins == 10000 - chicken.price)
        let purchased = try encoded(fresh)
        check(!fresh.buyRanchAnimal("unknown", at: now))
        check(try encoded(fresh) == purchased)
        fresh.garden.ingredients["小麦"] = 1
        check(fresh.fillRanchTrough(.wheat, at: now))
        check(fresh.ranchState.trough == 3 && fresh.garden.ingredients["小麦"] == 0)
        check(!fresh.fillRanchTrough(.wheat, at: now))
        var poor = fixture()
        poor.garden.coins = 0
        let poorBefore = try encoded(poor)
        check(!poor.buyRanchAnimal("chicken", at: now) && !poor.buyRanchFeed(at: now) && !poor.expandRanch(at: now))
        check(try encoded(poor) == poorBefore)
        check(!fresh.expandRanch(at: now))
        var fullTrough = fixture()
        fullTrough.garden.economy.ranch = RanchState(trough: 24, feedBags: 1, lastFocus: 0)
        fullTrough.garden.ingredients["玉米"] = 2
        let fullBefore = try encoded(fullTrough)
        check(!fullTrough.fillRanchTrough(.corn, at: now))
        check(try encoded(fullTrough) == fullBefore)

        var timed = fresh
        timed.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: now)
        check(timed.advanceRanch(to: timed.gameFocus(at: now.addingTimeInterval(450))))
        check(timed.ranchState.animals[0].progress == 450 && timed.ranchState.trough == 2 && timed.ranchState.readyCount == 0)
        timed.timer?.pause(at: now.addingTimeInterval(450))
        check(!timed.advanceRanch(to: timed.gameFocus(at: now.addingTimeInterval(9999))))
        check(timed.ranchState.animals[0].progress == 450)
        timed.timer?.resume(at: now.addingTimeInterval(9999))
        let readyDate = now.addingTimeInterval(10449)
        check(timed.advanceRanch(to: timed.gameFocus(at: readyDate)))
        check(timed.ranchState.readyCount == 1 && timed.ranchState.trough == 2)
        let eggID = timed.ranchState.animals[0].id
        let eggsBefore = timed.garden.ingredients["鸡蛋", default: 0]
        check(timed.collectRanchProduce(eggID, at: readyDate) == ["鸡蛋": 1])
        check(timed.garden.ingredients["鸡蛋"] == eggsBefore + 1 && timed.ranchState.readyCount == 0)
        check(timed.collectRanchProduce(eggID, at: readyDate).isEmpty)
        let focusBeforeFinish = timed.gameFocus(at: readyDate)
        _ = timed.finishTimer(at: readyDate)
        check(timed.totalFocus == focusBeforeFinish && !timed.advanceRanch(to: timed.totalFocus))
        timed.timer = TimerRun(kind: .rest, target: 300, taskTitle: "休息", startedAt: readyDate, resumedAt: readyDate)
        check(!timed.advanceRanch(to: timed.gameFocus(at: readyDate.addingTimeInterval(300))))
        validate(timed, at: readyDate.addingTimeInterval(300), label: "rest after focused production")

        var exhausted = RanchState(animals: [RanchAnimal(speciesID: "chicken")], trough: 3, lastFocus: 0)
        check(exhausted.advance(to: 9000))
        check(exhausted.animals[0].ready == 3 && exhausted.trough == 0 && !exhausted.animals[0].fed)
        check(exhausted.advance(to: 90000) && exhausted.animals[0].ready == 3)
        let exhaustedBefore = try encoded(exhausted)
        check(!exhausted.advance(to: 80000) && !exhausted.advance(to: .nan) && !exhausted.advance(to: .infinity) && !exhausted.advance(to: 1e308))
        check(try encoded(exhausted) == exhaustedBefore)

        let animals = [RanchAnimal(speciesID: "chicken"), RanchAnimal(speciesID: "cow")]
        var long = RanchState(animals: animals, trough: 48, expanded: true, lastFocus: 0)
        var steps = long
        check(long.advance(to: 1_000_000_000))
        for seconds in stride(from: 30, through: 15000, by: 30) { _ = steps.advance(to: Double(seconds)) }
        check(steps.advance(to: 1_000_000_000))
        check(long == steps && long.readyCount == 16 && long.trough == 32)
        check(long.isValid(focus: 1_000_000_000))

        var noRetro = fixture(focus: 10000)
        check(noRetro.buyRanchAnimal("chicken", at: now))
        check(noRetro.buyRanchFeed(at: now))
        check(!noRetro.advanceRanch(to: 10000) && noRetro.ranchState.readyCount == 0)
        check(noRetro.ranchState.trough == 0 && noRetro.ranchState.feedBags == 1)
        noRetro.sessions[0].seconds += 900
        check(noRetro.advanceRanch(to: noRetro.totalFocus) && noRetro.ranchState.readyCount == 1)
        check(noRetro.ranchState.trough == 5 && noRetro.ranchState.feedBags == 0)
        validate(noRetro, at: now, label: "new animal and feed at existing focus")

        let legacyJSON = Data("""
        {"animals":[{"id":"62F339BD-B810-4515-974C-DFB28FCC1AC3","speciesID":"chicken","progress":450,"fed":true,"ready":1}],
        "trough":1,"feedBags":2,"expanded":false,"lastFocus":1350}
        """.utf8)
        var resumed = fixture(focus: 1350)
        resumed.garden.economy.ranch = try JSONDecoder().decode(RanchState.self, from: legacyJSON)
        validate(resumed, at: now, label: "old save with a half-finished meal and both feed stocks")
        check(resumed.ranchState.feedPortions == 13 && resumed.ranchState.readyCount == 1)
        resumed.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: nil)
        check(!resumed.advanceRanch(to: resumed.gameFocus(at: now.addingTimeInterval(3000))))
        resumed.timer?.resume(at: now)
        check(resumed.advanceRanch(to: resumed.gameFocus(at: now.addingTimeInterval(1350))))
        check(resumed.ranchState.readyCount == 3 && resumed.ranchState.trough == 0 && resumed.ranchState.feedBags == 2)
        check(resumed.advanceRanch(to: resumed.gameFocus(at: now.addingTimeInterval(1351))))
        check(resumed.ranchState.animals[0].progress == 1 && resumed.ranchState.feedPortions == 11 && resumed.ranchState.feedBags == 1)
        let savedMeal = resumed.ranchState
        resumed.timer?.pause(at: now.addingTimeInterval(1351))
        check(!resumed.advanceRanch(to: resumed.gameFocus(at: now.addingTimeInterval(7200))) && resumed.ranchState == savedMeal)
        resumed.timer?.resume(at: now.addingTimeInterval(7200))
        check(resumed.advanceRanch(to: resumed.gameFocus(at: now.addingTimeInterval(8099))))
        check(resumed.ranchState.readyCount == 4 && resumed.ranchState.feedPortions == 11)
        var fullAnimal = RanchState(animals: [RanchAnimal(speciesID: "chicken", ready: 8)], feedBags: 3, lastFocus: 0)
        check(fullAnimal.advance(to: 5000) && fullAnimal.feedBags == 3 && fullAnimal.trough == 0)

        var expansion = fixture(focus: 100000)
        for _ in 0..<4 { check(expansion.buyRanchAnimal("chicken", at: now)) }
        let full = try encoded(expansion)
        check(!expansion.buyRanchAnimal("chicken", at: now))
        check(try encoded(expansion) == full)
        let expansionCoins = expansion.garden.coins
        check(expansion.expandRanch(at: now))
        check(expansion.ranchState.capacity == 8 && expansion.ranchState.troughCapacity == 48 && expansion.garden.coins == expansionCoins - RanchState.expansionPrice)
        check(!expansion.expandRanch(at: now))
        check(expansion.buyRanchAnimal("mooncalf", at: now))
        var materialRanch = expansion.ranchState
        materialRanch.animals[4].ready = 2
        expansion.garden.economy.ranch = materialRanch
        check(expansion.collectRanchProduce(materialRanch.animals[4].id, at: now) == ["银色粪肥": 2])
        check(expansion.garden.economy.finds["mooncalf_dung"] == 2 && expansion.garden.ingredients["银色粪肥"] == nil)
        validate(expansion, at: now, label: "expanded ranch and collected mooncalf material")
        var cashmere = fixture(focus: 100000)
        check(cashmere.buyRanchAnimal("cashmere_goat", at: now) && cashmere.buyRanchFeed(at: now))
        cashmere.sessions[0].seconds += 35 * 60
        check(cashmere.collectRanchProduce(at: now) == ["羊绒": 1])
        check(cashmere.garden.economy.finds["cashmere"] == 1 && cashmere.ranchState.feedPortions == 5)
        validate(cashmere, at: now, label: "cashmere goat production and collected material")
        let cashmereQuote=cashmere.findPrice("cashmere"), beforeSale=cashmere.garden.coins
        check(cashmereQuote == 11 && cashmere.sellFind("cashmere"))
        check(cashmere.garden.coins == beforeSale+cashmereQuote && !cashmere.sellFind("cashmere"))
        var mixed = fixture(focus: 100000)
        mixed.garden.economy.ranch = RanchState(animals: [RanchAnimal(speciesID: "chicken", ready: 1), RanchAnimal(speciesID: "chicken", ready: 2), RanchAnimal(speciesID: "cow", ready: 3)], trough: 10, lastFocus: mixed.totalFocus)
        let previousEggs = mixed.garden.ingredients["鸡蛋", default: 0], previousMilk = mixed.garden.ingredients["牛奶", default: 0]
        check(mixed.collectRanchProduce(at: now) == ["鸡蛋": 3, "牛奶": 3])
        check(mixed.garden.ingredients["鸡蛋"] == previousEggs + 3 && mixed.garden.ingredients["牛奶"] == previousMilk + 3)
        check(mixed.ranchState.readyCount == 0 && mixed.ranchState.trough == 10)
        validate(mixed, at: now, label: "combined produce conservation")

        var blocked = fixture()
        check(blocked.buyRanchAnimal("chicken", at: now))
        var blockedRanch = blocked.ranchState
        blockedRanch.animals[0].ready = 1
        blocked.garden.economy.ranch = blockedRanch
        blocked.garden.ingredients["鸡蛋"] = 1_000_000_000
        let crowded = try encoded(blocked)
        check(blocked.collectRanchProduce(at: now).isEmpty)
        check(try encoded(blocked) == crowded)
        var invalid = blocked.ranchState
        invalid.trough = 25; check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.animals[0].progress = .nan; check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.animals[0].speciesID = "invalid"; check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.lastFocus = 10; check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.animals.append(invalid.animals[0]); check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.animals[0].ready = 9; check(!invalid.isValid(focus: 0))
        invalid = blocked.ranchState; invalid.animals[0].progress = 1; check(!invalid.isValid(focus: 0))

        for index in 0..<8 {
            for time in stride(from: 0.0, through: 72.0, by: 0.25) {
                let moving = RanchAnimalPose(index: index, time: time, fed: true, reducedMotion: false)
                check((0.2...0.9).contains(moving.x) && (0.49...0.8).contains(moving.y))
                let frozen = RanchAnimalPose(index: index, time: time, fed: true, reducedMotion: true)
                check(frozen.x == frozen.homeX && frozen.y == frozen.homeY && frozen.tilt == 0 && !frozen.eating && !frozen.facingRight)
                let next = RanchAnimalPose(index: index, time: time + 0.001, fed: true, reducedMotion: false)
                check(abs(next.x - moving.x) < 0.001 && abs(next.y - moving.y) < 0.001)
                for neighbor in (index + 1)..<8 {
                    let other = RanchAnimalPose(index: neighbor, time: time, fed: true, reducedMotion: false)
                    check(abs(other.x - moving.x) >= 0.17 || abs(other.y - moving.y) >= 0.22)
                }
            }
        }

        let store = GardenStore(preview: true)
        let manager = FileManager.default
        let folder = store.file.deletingLastPathComponent()
        defer { store.storageLocked = true; try? manager.removeItem(at: folder) }
        store.data = fixture()
        check(store.commitGameChange { $0.buyRanchAnimal("chicken", at: now) })
        check(store.commitGameChange { $0.buyRanchFeed(at: now) })
        store.data.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: now)
        store.now = now
        check(store.save() && store.data.ranchState.feedBags == 1)
        let persisted = try SaveFile.read(store.file)
        check(persisted.ranchState == store.data.ranchState)
        let disk = try Data(contentsOf: store.file)
        let prior = try encoded(store.data)
        let backup = folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at: store.file, to: backup)
        try manager.createDirectory(at: store.file, withIntermediateDirectories: false)
        try Data([1]).write(to: store.file.appendingPathComponent("blocked"))
        store.now = now.addingTimeInterval(1)
        check(!store.commitGameChange { $0.buyRanchFeed(at: now) })
        check(try encoded(store.data) == prior && Data(contentsOf: backup) == disk)
        try manager.removeItem(at: store.file); try manager.moveItem(at: backup, to: store.file)
        print("PASS: ranch production, automatic reserve feeding, paused/rest clocks, feed exhaustion, old save and partial meal, bounded long focus, no retroactive feed, expansion, collection conservation, invalid saves, persistence and failed-save rollback")
    }
}
