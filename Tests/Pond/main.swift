import Foundation

@main enum PondChecks {
    static func check(_ condition: Bool, file: StaticString = #file, line: UInt = #line) {
        precondition(condition, file: file, line: line)
    }

    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func fixture(level: Int, at date: Date) -> AppData {
        var data = AppData()
        let seconds = (1..<level).reduce(0) { $0 + LevelProgress.requirement($1) } * 60
        if seconds > 0 {
            data.sessions = [FocusSession(id: UUID(), title: "阅读", kind: .stopwatch, date: date, seconds: Double(seconds))]
        }
        data.garden.coins = 10_000
        data.preferences.sound = false
        return data
    }

    @MainActor static func main() throws {
        let now = Date()
        try construction(at: now)
        try clock(at: now)
        try harvest(at: now)
        try validation(at: now)
        try rollback(at: now)
        print("PASS: pond unlocks, fish and feed bounds, clock boundaries, inventory conservation, old saves, validation, and save rollback")
    }

    private static func construction(at now: Date) throws {
        var locked = fixture(level: 11, at: now)
        let lockedBefore = try encoded(locked)
        check(!locked.buildPond(at: now) && !locked.buyPondFry("common_carp", at: now))
        check(!locked.buyPondFeed(at: now) && !locked.fillPondFeed(.wheat, at: now) && !locked.expandPond(at: now))
        check(locked.harvestPondFish(at: now).isEmpty)
        check(try encoded(locked) == lockedBefore)

        var data = fixture(level: 12, at: now)
        data.garden.coins = PondState.buildPrice - 1
        check(!data.buildPond(at: now))
        data.garden.coins = 10_000
        check(data.buildPond(at: now) && !data.buildPond(at: now))
        check(data.pondState == PondState(lastFocus: data.totalFocus))
        check(data.garden.coins == 10_000 - PondState.buildPrice)
        check(!data.buyPondFry("ocean_fish", at: now) && !data.buyPondFry("moonlight", at: now))
        check(!data.expandPond(at: now))
        for _ in 0..<4 { check(data.buyPondFry("common_carp", at: now)) }
        check(data.pondState?.capacity == 4 && data.pondState?.fish.count == 4)
        check(data.garden.coins == 10_000 - PondState.buildPrice - 8)
        check(!data.buyPondFry("silver_scale", at: now))

        var large = fixture(level: 22, at: now)
        check(large.buildPond(at: now))
        large.garden.coins = PondState.expansionPrice - 1
        check(!large.expandPond(at: now))
        large.garden.coins = 10_000
        check(large.expandPond(at: now) && !large.expandPond(at: now))
        check(large.pondState?.capacity == 8 && large.pondState?.feedCapacity == 48)
        check(large.garden.coins == 10_000 - PondState.expansionPrice)
        for _ in 0..<8 { check(large.buyPondFry("moonlight", at: now)) }
        check(!large.buyPondFry("common_carp", at: now))

        for species in PondSpecies.all {
            check(species.fish?.waterTypes.contains(.fresh) == true)
            check((species.fish?.salePrice ?? 0) > species.price + PondState.feedBagPrice / PondState.feedBagPortions)
            var available = fixture(level: species.level, at: now)
            check(available.buildPond(at: now))
            let coins = available.garden.coins
            check(available.buyPondFry(species.id, at: now))
            check(available.garden.coins == coins - species.price)
            available.garden.coins = species.price - 1
            check(!available.buyPondFry(species.id, at: now))
        }

        data.garden.ingredients["小麦"] = 1
        data.garden.ingredients["玉米"] = 3
        data.garden.ingredients["胡萝卜"] = 1
        check(data.fillPondFeed(.wheat, at: now) && !data.fillPondFeed(.wheat, at: now))
        check(data.fillPondFeed(.corn, at: now) && !data.fillPondFeed(.carrot, at: now))
        check(data.pondState?.feed == 7 && data.garden.ingredients["小麦"] == 0 && data.garden.ingredients["玉米"] == 2)
        check(data.garden.ingredients["胡萝卜"] == 1)
        let coins = data.garden.coins
        for _ in 0..<2 { check(data.buyPondFeed(at: now)) }
        check(data.garden.coins == coins - 2 * PondState.feedBagPrice && data.pondState?.feed == 19)
        let fullBefore = try encoded(data)
        check(try !data.buyPondFeed(at: now) && encoded(data) == fullBefore)
        check(data.fillPondFeed(.corn, at: now) && data.pondState?.feed == 23)
        let cappedBefore = try encoded(data)
        check(try !data.fillPondFeed(.corn, at: now) && encoded(data) == cappedBefore)
        _ = try data.validated(at: now)
    }

    private static func clock(at now: Date) throws {
        var data = fixture(level: 12, at: now)
        let focus = data.totalFocus
        check(data.buildPond(at: now) && data.buyPondFry("common_carp", at: now))
        data.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: now)
        let lateFeed = now.addingTimeInterval(1300)
        check(data.buyPondFeed(at: lateFeed))
        check(data.pondState?.lastFocus == focus + 1300)
        check(data.pondState?.fish.first?.progress == 0 && data.pondState?.feed == 6)
        data.advanceFocusWorld(at: lateFeed)
        check(data.pondState?.fish.first?.fed == false)

        let lateFry = lateFeed.addingTimeInterval(500)
        check(data.buyPondFry("silver_scale", at: lateFry))
        check(data.pondState?.fish.map(\.progress) == [500, 0] && data.pondState?.feed == 5)
        let pause = lateFry.addingTimeInterval(100)
        data.timer?.pause(at: pause)
        data.advanceFocusWorld(at: pause)
        let paused = data.pondState
        let resume = pause.addingTimeInterval(5000)
        data.advanceFocusWorld(at: resume)
        check(data.pondState == paused && data.pondState?.fish.map(\.progress) == [600, 100])
        check(data.pondState?.feed == 4)

        data.timer?.resume(at: resume)
        let finish = resume.addingTimeInterval(600)
        data.advanceFocusWorld(at: finish)
        check(data.pondState?.readyCount == 1 && data.pondState?.fish.map(\.progress) == [1200, 700])
        let finished = data.pondState
        check(data.finishTimer(at: finish)?.seconds == 2500)
        data.advanceFocusWorld(at: finish)
        check(data.pondState == finished)
        data.timer = TimerRun(kind: .rest, target: 300, taskTitle: "休息", startedAt: finish, resumedAt: finish)
        let rested = finish.addingTimeInterval(300)
        data.advanceFocusWorld(at: rested)
        check(data.finishTimer(at: rested)?.rest == true && data.pondState == finished)
        _ = try data.validated(at: rested)

        let stock = [PondFish(speciesID: "common_carp"), PondFish(speciesID: "lake_trout"), PondFish(speciesID: "golden_stripe")]
        var long = PondState(lastFocus: 0, fish: stock, feed: 2)
        var split = long
        for step in stride(from: 0.5, through: 2100, by: 0.5) { split.advance(to: step) }
        check(long.advance(to: 999_999_999_999) && split.advance(to: 999_999_999_999))
        check(long == split && long.readyCount == 2 && long.feed == 0)
        check(long.fish.map(\.progress) == [1200, 2100, 0])
        check(long.isValid(focus: 999_999_999_999))
        let snapshot = long
        for time in [-1.0, .nan, .infinity, 700, 999_999_999_999, 1_000_000_000_000] { check(!long.advance(to: time)) }
        check(long == snapshot)
    }

    private static func harvest(at now: Date) throws {
        var data = fixture(level: 35, at: now)
        check(data.buildPond(at: now) && data.buyPondFeed(at: now))
        check(data.buyPondFry("common_carp", at: now) && data.buyPondFry("lake_trout", at: now))
        check(data.buyPondFry("common_carp", at: now) && data.harvestPondFish(at: now).isEmpty)
        data.sessions[0].seconds += 1200
        let first = data.pondState?.fish[0].id
        check(data.harvestPondFish(first, at: now) == ["common_carp": 1])
        check(data.harvestPondFish(first, at: now).isEmpty && data.pondState?.fish.count == 2)
        check(data.fishingState.inventory == ["common_carp": 1])
        data.sessions[0].seconds += 900
        data.advanceFocusWorld(at: now)
        let full = data.pondState
        data.garden.economy.fishing?.inventory["lake_trout"] = 1_000_000_000
        let beforeOverflow = try encoded(data)
        check(try data.harvestPondFish(at: now).isEmpty && encoded(data) == beforeOverflow)
        check(data.pondState == full && data.fishingState.inventory["common_carp"] == 1)
        data.garden.economy.fishing?.inventory["lake_trout"] = 999_999_999
        check(data.harvestPondFish(at: now) == ["common_carp": 1, "lake_trout": 1])
        check(data.pondState?.fish.isEmpty == true && data.pondState?.feed == 3)
        check(data.fishingState.inventory == ["common_carp": 2, "lake_trout": 1_000_000_000])
        check(data.fishingState.lifetime.isEmpty && data.fishingState.catches.isEmpty)
        let coins = data.garden.coins
        check(data.sellFishingCatch("common_carp", count: 1) && data.garden.coins == coins + 6)
        check(data.prepareFish("common_carp", count: 1))
        check(data.garden.ingredients[Ingredient.fishFillet.rawValue] == 1)
        _ = try data.validated(at: now)
    }

    private static func validation(at now: Date) throws {
        var data = fixture(level: 12, at: now)
        let legacy = try JSONDecoder().decode(AppData.self, from: encoded(data))
        check(legacy.pondState == nil)
        _ = try legacy.validated(at: now)
        check(data.buildPond(at: now) && data.buyPondFry("common_carp", at: now) && data.buyPondFeed(at: now))
        data.sessions[0].seconds += 450
        data.advanceFocusWorld(at: now)
        let saved = try JSONDecoder().decode(AppData.self, from: encoded(data)).validated(at: now)
        check(saved.pondState == data.pondState && saved.pondState?.fish.first?.progress == 450)

        guard let valid = data.pondState else { preconditionFailure("Pond fixture missing") }
        let corruptions: [(inout PondState) -> Void] = [
            { $0.feed = -1 }, { $0.feed = 25 }, { $0.lastFocus = -1 }, { $0.lastFocus += 1 }, { $0.lastFocus = .nan },
            { $0.fish.append($0.fish[0]) }, { $0.fish = (0..<5).map { _ in PondFish(speciesID: "common_carp") } },
            { $0.fish[0].speciesID = "yellowfin_tuna" }, { $0.fish[0].speciesID = "missing" },
            { $0.fish[0].progress = .infinity }, { $0.fish[0].progress = -1 }, { $0.fish[0].progress = 1201 },
            { $0.fish[0].fed = false }, { $0.fish[0].progress = 0 }
        ]
        for corrupt in corruptions {
            var invalid = valid
            corrupt(&invalid)
            check(!invalid.isValid(focus: data.totalFocus))
            data.garden.economy.pond = invalid
            check((try? data.validated(at: now)) == nil)
        }
    }

    @MainActor private static func rollback(at now: Date) throws {
        let store = GardenStore(preview: true)
        let manager = FileManager.default
        let folder = store.file.deletingLastPathComponent()
        check(folder.lastPathComponent == "Daygarden-Preview-\(ProcessInfo.processInfo.processIdentifier)")
        defer { store.storageLocked = true; try? manager.removeItem(at: folder) }
        store.data = fixture(level: 12, at: now)
        store.now = now
        check(store.commitGameChange { $0.buildPond(at: now) && $0.buyPondFry("common_carp", at: now) && $0.buyPondFeed(at: now) })
        check(store.startTimer(kind: .stopwatch, minutes: 20, task: nil, title: "阅读", at: now))
        let firstGrowth = now.addingTimeInterval(60)
        store.tick(firstGrowth)
        check(store.data.pondState?.fish.first?.progress == 60)
        check(store.save())
        check(try SaveFile.read(store.file).pondState == store.data.pondState)

        let previous = try encoded(store.data)
        let disk = try Data(contentsOf: store.file)
        let backup = folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at: store.file, to: backup)
        try manager.createDirectory(at: store.file, withIntermediateDirectories: false)
        try Data([1]).write(to: store.file.appendingPathComponent("blocked"))
        check(!store.commitGameChange { $0.buyPondFeed(at: firstGrowth) })
        check(try encoded(store.data) == previous)
        let ready = now.addingTimeInterval(1200)
        check(try !store.finishTimer(at: ready) && encoded(store.data) == previous)
        check(!store.commitGameChange { !$0.harvestPondFish(at: ready).isEmpty })
        check(try encoded(store.data) == previous && Data(contentsOf: backup) == disk)

        try manager.removeItem(at: store.file)
        try manager.moveItem(at: backup, to: store.file)
        check(store.finishTimer(at: ready))
        check(store.data.pondState?.readyCount == 1 && store.data.pondState?.feed == 5)
        check(store.commitGameChange { $0.harvestPondFish(at: ready) == ["common_carp": 1] })
        let saved = try SaveFile.read(store.file)
        check(saved.pondState?.readyCount == 0 && saved.fishingState.inventory["common_carp"] == 1)
    }
}
