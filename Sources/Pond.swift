import Foundation

struct PondSpecies: Identifiable {
    let id: String
    let level: Int
    let price: Int
    let growthMinutes: Int

    var fish: NatureFish? { NatureCatalog.fish.first { $0.id == id } }

    static let all: [PondSpecies] = [
        .init(id: "common_carp", level: 12, price: 2, growthMinutes: 20),
        .init(id: "silver_scale", level: 12, price: 2, growthMinutes: 25),
        .init(id: "moonlight", level: 18, price: 4, growthMinutes: 25),
        .init(id: "golden_stripe", level: 25, price: 7, growthMinutes: 35),
        .init(id: "lake_trout", level: 35, price: 6, growthMinutes: 35)
    ]
}

struct PondFish: Codable, Identifiable, Equatable {
    var id = UUID()
    var speciesID: String
    var progress: Double = 0
    var fed = false

    var species: PondSpecies? { PondSpecies.all.first { $0.id == speciesID } }
    var growthSeconds: Double { Double(species?.growthMinutes ?? 1) * 60 }
    var ready: Bool { progress >= growthSeconds }
}

struct PondState: Codable, Equatable {
    static let buildLevel = 12
    static let buildPrice = 493
    static let expansionLevel = 22
    static let expansionPrice = 986
    static let feedBagPortions = 6
    static let feedBagPrice = 12
    static let grains: [RanchFeed] = [.wheat, .corn]

    var lastFocus: Double
    var fish: [PondFish] = []
    var feed = 0
    var expanded = false

    var capacity: Int { expanded ? 8 : 4 }
    var feedCapacity: Int { expanded ? 48 : 24 }
    var readyCount: Int { fish.filter(\.ready).count }

    func isValid(focus: Double) -> Bool {
        guard focus.isFinite, focus < 1_000_000_000_000,
              lastFocus.isFinite, lastFocus >= 0, lastFocus <= focus,
              (0...feedCapacity).contains(feed), fish.count <= capacity,
              Set(fish.map(\.id)).count == fish.count else { return false }
        return fish.allSatisfy { stock in
            guard stock.species?.fish?.waterTypes.contains(.fresh) == true else { return false }
            return stock.progress.isFinite && (0...stock.growthSeconds).contains(stock.progress) &&
                stock.fed == (stock.progress > 0)
        }
    }

    @discardableResult mutating func advance(to focus: Double) -> Bool {
        guard focus.isFinite, focus < 1_000_000_000_000, lastFocus >= 0, focus > lastFocus else { return false }
        let elapsed = focus - lastFocus
        lastFocus = focus
        for index in fish.indices where !fish[index].ready {
            if !fish[index].fed {
                guard feed > 0 else { continue }
                feed -= 1
                fish[index].fed = true
            }
            fish[index].progress = min(fish[index].growthSeconds, fish[index].progress + elapsed)
        }
        return true
    }
}

extension AppData {
    var pondState: PondState? { garden.economy.pond }

    @discardableResult mutating func advancePond(to focus: Double) -> Bool {
        guard var pond = pondState, pond.advance(to: focus) else { return false }
        garden.economy.pond = pond
        return true
    }

    mutating func buildPond(at date: Date = Date()) -> Bool {
        guard pondState == nil, levelProgress.level >= PondState.buildLevel,
              garden.coins >= PondState.buildPrice else { return false }
        let focus = gameFocus(at: date)
        guard focus.isFinite, focus >= 0, focus < 1_000_000_000_000 else { return false }
        garden.economy.pond = PondState(lastFocus: focus)
        garden.coins -= PondState.buildPrice
        return true
    }

    mutating func expandPond(at date: Date = Date()) -> Bool {
        guard var pond = pondState, !pond.expanded, levelProgress.level >= PondState.expansionLevel,
              garden.coins >= PondState.expansionPrice else { return false }
        pond.advance(to: gameFocus(at: date))
        pond.expanded = true
        garden.economy.pond = pond
        garden.coins -= PondState.expansionPrice
        return true
    }

    mutating func buyPondFry(_ speciesID: String, at date: Date = Date()) -> Bool {
        guard var pond = pondState, pond.fish.count < pond.capacity,
              let species = PondSpecies.all.first(where: { $0.id == speciesID }),
              levelProgress.level >= species.level, garden.coins >= species.price else { return false }
        pond.advance(to: gameFocus(at: date))
        pond.fish.append(PondFish(speciesID: speciesID))
        garden.economy.pond = pond
        garden.coins -= species.price
        return true
    }

    mutating func buyPondFeed(at date: Date = Date()) -> Bool {
        guard var pond = pondState, garden.coins >= PondState.feedBagPrice else { return false }
        pond.advance(to: gameFocus(at: date))
        guard pond.feed + PondState.feedBagPortions <= pond.feedCapacity else { return false }
        pond.feed += PondState.feedBagPortions
        garden.economy.pond = pond
        garden.coins -= PondState.feedBagPrice
        return true
    }

    mutating func fillPondFeed(_ grain: RanchFeed, at date: Date = Date()) -> Bool {
        guard var pond = pondState, PondState.grains.contains(grain),
              garden.ingredients[grain.rawValue, default: 0] > 0 else { return false }
        pond.advance(to: gameFocus(at: date))
        guard pond.feed + grain.portions <= pond.feedCapacity else { return false }
        pond.feed += grain.portions
        garden.economy.pond = pond
        garden.ingredients[grain.rawValue, default: 0] -= 1
        return true
    }

    mutating func harvestPondFish(_ id: UUID? = nil, at date: Date = Date()) -> [String: Int] {
        guard var pond = pondState else { return [:] }
        pond.advance(to: gameFocus(at: date))
        let harvest = pond.fish.filter { $0.ready && (id == nil || $0.id == id) }
        guard !harvest.isEmpty else { return [:] }
        var counts: [String: Int] = [:]
        for fish in harvest { counts[fish.speciesID, default: 0] += 1 }

        var fishing = fishingState
        for (speciesID, count) in counts {
            guard (0...(1_000_000_000 - count)).contains(fishing.inventory[speciesID, default: 0]) else { return [:] }
            fishing.inventory[speciesID, default: 0] += count
        }
        let harvestedIDs = Set(harvest.map(\.id))
        pond.fish.removeAll { harvestedIDs.contains($0.id) }
        garden.economy.pond = pond
        garden.economy.fishing = fishing
        return counts
    }
}
