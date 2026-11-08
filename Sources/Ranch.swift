import Foundation

struct RanchAnimal: Codable, Identifiable, Equatable {
    var id = UUID()
    var speciesID: String
    var progress: Double = 0
    var fed = false
    var ready = 0
    var species: NatureRanchSpecies? { NatureCatalog.ranchSpecies.first { $0.id == speciesID } }
    var productionSeconds: Double { Double(species?.productionMinutes ?? 1) * 60 }
    var storageLimit: Int { (species?.productCount ?? 1) * 8 }
}

struct RanchState: Codable, Equatable {
    var animals: [RanchAnimal] = []
    var trough = 0
    var feedBags = 0
    var expanded = false
    var lastFocus: Double? = nil
    var capacity: Int { expanded ? 8 : 4 }
    var troughCapacity: Int { expanded ? 48 : 24 }
    var readyCount: Int { animals.reduce(0) { $0 + $1.ready } }
    static let expansionPrice = 493
    static let expansionLevel = 4
    static let feedBagPrice = 12
    static let feedBagPortions = 6

    func isValid(focus: Double) -> Bool {
        guard (0...troughCapacity).contains(trough), (0...1_000_000).contains(feedBags),
              animals.count <= capacity, Set(animals.map(\.id)).count == animals.count,
              lastFocus.map({ $0.isFinite && $0 >= 0 && $0 <= focus }) ?? animals.isEmpty else { return false }
        return animals.allSatisfy { animal in
            guard let species = animal.species else { return false }
            return animal.progress.isFinite && animal.progress >= 0 && animal.progress < animal.productionSeconds &&
                (animal.fed || animal.progress == 0) && (0...animal.storageLimit).contains(animal.ready) &&
                animal.ready % species.productCount == 0 && (!animal.fed || animal.ready < animal.storageLimit)
        }
    }

    @discardableResult mutating func advance(to focus: Double) -> Bool {
        guard focus.isFinite, focus >= 0, focus < 1_000_000_000_000, lastFocus.map({ focus >= $0 }) ?? true else { return false }
        guard let previous = lastFocus else { lastFocus = focus; return true }
        guard focus > previous else { return false }
        var remaining = focus - previous
        lastFocus = focus
        while remaining > 0 {
            for index in animals.indices where !animals[index].fed && animals[index].ready < animals[index].storageLimit && trough > 0 {
                animals[index].fed = true
                trough -= 1
            }
            let active = animals.indices.filter { animals[$0].fed }
            guard !active.isEmpty else { break }
            let step = min(remaining, active.map { animals[$0].productionSeconds - animals[$0].progress }.min()!)
            for index in active {
                animals[index].progress += step
                if animals[index].progress >= animals[index].productionSeconds {
                    animals[index].ready += animals[index].species?.productCount ?? 1
                    animals[index].progress = 0
                    animals[index].fed = false
                }
            }
            remaining -= step
        }
        return true
    }
}

enum RanchFeed: String, CaseIterable, Identifiable {
    case bag = "混合饲料", wheat = "小麦", corn = "玉米", carrot = "胡萝卜", cabbage = "卷心菜", pumpkin = "南瓜"
    var id: String { rawValue }
    var portions: Int {
        switch self { case .bag: return 6; case .wheat: return 3; case .corn,.pumpkin: return 4; case .carrot,.cabbage: return 2 }
    }
}

extension AppData {
    var ranchState: RanchState { garden.economy.ranch ?? RanchState() }

    @discardableResult mutating func advanceRanch(to focus: Double) -> Bool {
        guard var ranch = garden.economy.ranch, ranch.advance(to: focus) else { return false }
        garden.economy.ranch = ranch
        return true
    }

    mutating func buyRanchAnimal(_ id: String, at date: Date = Date()) -> Bool {
        guard let species = NatureCatalog.ranchSpecies.first(where: { $0.id == id }),
              levelProgress.level >= species.level, garden.coins >= species.price,
              ranchState.animals.count < ranchState.capacity else { return false }
        var ranch = ranchState
        ranch.advance(to: gameFocus(at: date))
        ranch.animals.append(RanchAnimal(speciesID: id))
        garden.coins -= species.price
        garden.economy.ranch = ranch
        return true
    }

    mutating func buyRanchFeed(at date: Date = Date()) -> Bool {
        guard garden.coins >= RanchState.feedBagPrice, ranchState.feedBags < 1_000_000 else { return false }
        var ranch = ranchState
        ranch.advance(to: gameFocus(at: date))
        ranch.feedBags += 1
        garden.coins -= RanchState.feedBagPrice
        garden.economy.ranch = ranch
        return true
    }

    mutating func fillRanchTrough(_ food: RanchFeed, at date: Date = Date()) -> Bool {
        var ranch = ranchState
        ranch.advance(to: gameFocus(at: date))
        let available = food == .bag ? ranch.feedBags : garden.ingredients[food.rawValue, default: 0]
        guard available > 0, ranch.trough + food.portions <= ranch.troughCapacity else { return false }
        if food == .bag { ranch.feedBags -= 1 }
        else { garden.ingredients[food.rawValue, default: 0] -= 1 }
        ranch.trough += food.portions
        garden.economy.ranch = ranch
        return true
    }

    mutating func expandRanch(at date: Date = Date()) -> Bool {
        guard !ranchState.expanded, levelProgress.level >= RanchState.expansionLevel,
              garden.coins >= RanchState.expansionPrice else { return false }
        var ranch = ranchState
        ranch.advance(to: gameFocus(at: date))
        ranch.expanded = true
        garden.coins -= RanchState.expansionPrice
        garden.economy.ranch = ranch
        return true
    }

    mutating func collectRanchProduce(_ animalID: UUID? = nil, at date: Date = Date()) -> [String: Int] {
        var ranch = ranchState
        ranch.advance(to: gameFocus(at: date))
        var result: [String: Int] = [:]
        var ingredients: [String: Int] = [:]
        var materials: [String: Int] = [:]
        for animal in ranch.animals where (animalID == nil || animal.id == animalID) && animal.ready > 0 {
            guard let species = animal.species else { return [:] }
            result[species.productName, default: 0] += animal.ready
            if let ingredient = species.ingredient { ingredients[ingredient, default: 0] += animal.ready }
            else { materials[species.productID, default: 0] += animal.ready }
        }
        guard !result.isEmpty else { return [:] }
        guard ingredients.allSatisfy({ garden.ingredients[$0.key, default: 0] >= 0 && garden.ingredients[$0.key, default: 0] <= 1_000_000_000 - $0.value }),
              materials.allSatisfy({ garden.economy.finds[$0.key, default: 0] >= 0 && garden.economy.finds[$0.key, default: 0] <= 1_000_000_000 - $0.value }) else { return [:] }
        for (name, count) in ingredients { garden.ingredients[name, default: 0] += count }
        for (name, count) in materials { garden.economy.finds[name, default: 0] += count }
        for index in ranch.animals.indices where animalID == nil || ranch.animals[index].id == animalID { ranch.animals[index].ready = 0 }
        garden.economy.ranch = ranch
        return result
    }
}

struct RanchAnimalPose {
    var homeX: CGFloat
    var homeY: CGFloat
    var x: CGFloat
    var y: CGFloat
    var eating: Bool
    var facingRight: Bool
    var tilt: Double
    init(index: Int, time: Double, fed: Bool, reducedMotion: Bool) {
        homeX = [0.22, 0.42, 0.62, 0.82][index % 4]
        homeY = index < 4 ? 0.50 : 0.74
        let clock = time + Double(index) * 7
        let phase = clock.truncatingRemainder(dividingBy: 36)
        eating = !reducedMotion && fed && phase >= 12 && phase < 17
        let walking = !reducedMotion && phase >= 19 && phase < 33
        let walkPhase = min(1, max(0, (phase - 19) / 14))
        let distance = sin(walkPhase * 2 * .pi)
        x = homeX + (walking ? CGFloat(distance) * 0.012 : 0)
        y = homeY + (walking ? CGFloat(sin(walkPhase * 4 * .pi)) * 0.004 : 0)
        facingRight = walking && cos(walkPhase * 2 * .pi) > 0
        tilt = reducedMotion ? 0 : eating ? sin(clock * 5) * 3 : walking ? sin(clock * 6) * 1.5 : sin(clock * 1.8) * 0.6
    }
}
