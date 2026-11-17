import Foundation

struct Companion:Identifiable {
    let id:String
    let name:String
    let role:String
    let level:Int
    let price:Int
    let gathering:Int
    let scouting:Int
    let guarding:Int
    var spriteKey:String {"companion_"+id}
    static let all:[Companion]=[
        .init(id:"rowan",name:"罗温",role:"林间采集者",level:5,price:45,gathering:2,scouting:1,guarding:0),
        .init(id:"mira",name:"米拉",role:"河谷向导",level:5,price:35,gathering:1,scouting:2,guarding:0),
        .init(id:"oswin",name:"奥斯温",role:"巡路护卫",level:6,price:38,gathering:0,scouting:1,guarding:2),
        .init(id:"iris",name:"伊里斯",role:"草药师",level:8,price:95,gathering:3,scouting:1,guarding:0),
        .init(id:"cedar",name:"西达",role:"山地勘察员",level:12,price:115,gathering:1,scouting:3,guarding:1),
        .init(id:"brann",name:"布兰",role:"远行护卫",level:14,price:110,gathering:1,scouting:1,guarding:3),
        .init(id:"linnet",name:"林奈特",role:"雨林博物学者",level:18,price:190,gathering:3,scouting:3,guarding:1),
        .init(id:"vesper",name:"维斯珀",role:"星夜领航员",level:25,price:260,gathering:2,scouting:4,guarding:3),
        .init(id:"coralie",name:"珂拉莉",role:"礁湾观察员",level:30,price:290,gathering:3,scouting:4,guarding:2),
        .init(id:"arden",name:"阿登",role:"高地向导",level:35,price:330,gathering:2,scouting:3,guarding:5),
        .init(id:"sable",name:"塞布尔",role:"遗迹修护师",level:40,price:380,gathering:4,scouting:3,guarding:3)
    ]
}

enum GearSlot:String,Codable,CaseIterable {case tool="工具",coat="外衣",trousers="下装",charm="饰物"}
struct CraftedGear:Identifiable,Codable,Equatable {
    let id:String
    let name:String
    let slot:GearSlot
    let level:Int
    let minerals:[String:Int]
    let price:Int
    let gathering:Int
    let scouting:Int
    let guarding:Int
    var materials:[String:Int]=[:]
    var forgeSprite:String? = nil
    var saleValue:Int? = nil
    var spriteKey:String {forgeSprite ?? "gear_"+id}
    var salePrice:Int {EconomyBalance.equipmentSalePrice(self) ?? saleValue ?? max(1,price*2)}
    static let all:[CraftedGear]=[
        .init(id:"copper_sickle",name:"铜刃采集镰",slot:.tool,level:5,minerals:["copper":4,"coal":2],price:12,gathering:1,scouting:0,guarding:0),
        .init(id:"iron_staff",name:"铁箍行路杖",slot:.tool,level:8,minerals:["iron":4,"coal":3],price:20,gathering:0,scouting:1,guarding:1),
        .init(id:"iron_coat",name:"铁扣防护外衣",slot:.coat,level:8,minerals:["iron":3,"copper":2],price:29,gathering:0,scouting:0,guarding:2,materials:["sheep_wool":2]),
        .init(id:"quartz_charm",name:"石英寻踪坠",slot:.charm,level:12,minerals:["quartz":4,"copper":2],price:24,gathering:0,scouting:2,guarding:0),
        .init(id:"silver_compass",name:"银壳罗盘",slot:.charm,level:14,minerals:["silver":4,"quartz":2],price:40,gathering:1,scouting:2,guarding:0),
        .init(id:"obsidian_blade",name:"黑曜采集刃",slot:.tool,level:20,minerals:["obsidian":5,"iron":3],price:58,gathering:3,scouting:0,guarding:1),
        .init(id:"moon_coat",name:"月石护行衣",slot:.coat,level:25,minerals:["moonstone":4,"silver":3],price:87,gathering:0,scouting:1,guarding:3,materials:["cloud_fleece":2,"alpaca_fibre":2]),
        .init(id:"star_lens",name:"星辉勘察镜",slot:.charm,level:30,minerals:["starlight_ore":3,"diamond":1,"gold":2],price:116,gathering:2,scouting:3,guarding:1)
    ]
}

struct ExpeditionTrip:Codable,Equatable,Identifiable {
    var id=UUID()
    var locationID:String
    var startedFocus:Double
    var duration:Double
    var level:Int
    var companions:[String]
    var gathering:Int
    var scouting:Int
    var guarding:Int
    var events=0
    var rewards:[String:Int]=[:]
    var discoveries:[String]=[]
    var packedRewards:[String:Int]? = nil

    func unpackedCount(_ itemID: String) -> Int {
        rewards[itemID,default:0] - (packedRewards?[itemID] ?? 0)
    }
}
struct ExpeditionRecord:Codable,Equatable,Identifiable {
    var id:UUID
    var locationID:String
    var duration:Double
    var plannedDuration:Double
    var completed:Bool
    var companions:[String]
    var rewards:[String:Int]
    var discoveries:[String]
    var claimableQuantity:Int? = nil
}
struct TavernRoster:Codable,Equatable {
    static let interval:Double = 30*60
    static let refreshPrice = 12
    static let capacity = 2
    var refreshedAtFocus:Double
    var visitors:[String]
}
struct ExpeditionState:Codable,Equatable {
    static let rewardLimit = 1_000_000_000
    var hired:Set<String>=[]
    var team:[String]=[]
    var equipment:[String:[String:String]]=[:]
    var gear:[String:Int]=[:]
    var generatedGear:[String:CraftedGear]? = nil
    var trip:ExpeditionTrip?
    var inventory:[String:Int]=[:]
    var discoveries:Set<String>=[]
    var history:[ExpeditionRecord]=[]
    var random=FocusRandom()
    var preferredMinutes=30
    var preferredLocation="forest"
    var locationTeams:[String:[String]]? = nil
    var tavern:TavernRoster? = nil
    var pendingRewards:[String:[String:Int]]? = nil

    func unclaimedRewards(at locationID:String) -> [String:Int] {
        pendingRewards?[locationID] ?? [:]
    }

    func rewardSpace(for itemID:String) -> Int {
        Self.rewardLimit - inventory[itemID,default:0]
            - (pendingRewards ?? [:]).values.reduce(0) { $0+$1[itemID,default:0] }
    }

    func team(at locationID:String) -> [String] {
        if let locationTeams { return locationTeams[locationID] ?? [] }
        return locationID == preferredLocation ? team:[]
    }

    mutating func migrateTeam() {
        guard locationTeams == nil else { return }
        locationTeams = team.isEmpty ? [:]:[preferredLocation:team]
        team = []
    }

    func isTraveling(_ companionID:String) -> Bool {
        trip?.companions.contains(companionID) == true
    }

    func gearBonuses(for companionID:String) -> (gathering:Int,scouting:Int,guarding:Int) {
        let equipped = (equipment[companionID] ?? [:]).values.compactMap(resolveGear)
        return (equipped.reduce(0){$0+$1.gathering},equipped.reduce(0){$0+$1.scouting},equipped.reduce(0){$0+$1.guarding})
    }
}

struct ExpeditionLocation: Identifiable {
    let id: String
    let name: String
    let level: Int
    let backdrop: String
    static let all: [ExpeditionLocation] = [
        .init(id:"forest",name:"森林",level:5,backdrop:"Forest"),
        .init(id:"marsh",name:"芦苇湿地",level:8,backdrop:"ReedMarsh"),
        .init(id:"river",name:"河谷",level:10,backdrop:"River"),
        .init(id:"mountains",name:"群山",level:12,backdrop:"MountainLake"),
        .init(id:"beach",name:"海滩",level:15,backdrop:"Beach"),
        .init(id:"tropical",name:"雨林",level:18,backdrop:"Tropical"),
        .init(id:"polar",name:"极地",level:25,backdrop:"Polar"),
        .init(id:"reef",name:"珊瑚潟湖",level:28,backdrop:"CoralLagoon"),
        .init(id:"highland",name:"云雾高地",level:35,backdrop:"MistHighland"),
        .init(id:"ruins",name:"古塔遗迹",level:40,backdrop:"Ruins")
    ]
}

extension ExpeditionState {
    func isValid(focus: Double) -> Bool {
        let companionIDs = Set(Companion.all.map(\.id))
        let forageIDs = Set(NatureCatalog.forage.map(\.id))
        let discoveryIDs = Set(NatureCatalog.forage.map { "forage:" + $0.id } + NatureCatalog.wildlife.map { "wildlife:" + $0.id })
        let locations = Set(ExpeditionLocation.all.map(\.id))
        func validRewards(_ rewards: [String:Int]) -> Bool {
            Set(rewards.keys).isSubset(of: forageIDs) && rewards.values.allSatisfy { (0...Self.rewardLimit).contains($0) }
        }
        func validTeam(_ ids: [String]) -> Bool { ids.count <= 4 && Set(ids).count == ids.count && Set(ids).isSubset(of: hired) }
        guard hired.isSubset(of: companionIDs), validTeam(team),
              (locationTeams == nil || team.isEmpty),
              (locationTeams ?? [:]).allSatisfy({locations.contains($0.key) && validTeam($0.value)}),
              (1...1440).contains(preferredMinutes), locations.contains(preferredLocation),
              validRewards(inventory), discoveries.isSubset(of: discoveryIDs),
              history.count <= 256, Set(history.map(\.id)).count == history.count,
              gear.count<=4096, (generatedGear?.count ?? 0)<=4096,
              (generatedGear ?? [:]).allSatisfy({id,item in
                  id == item.id && id.hasPrefix("forged_") && !item.name.isEmpty && item.name.count<=60
                    && (1...100000).contains(item.level) && item.price == 0 && item.minerals.isEmpty && item.materials.isEmpty
                    && [item.gathering,item.scouting,item.guarding].allSatisfy{(0...30).contains($0)}
                    && item.saleValue.map{(1...1_000_000).contains($0)} == true
                    && ForgeMold.all.contains{$0.supportsGearSprite(item.spriteKey) && $0.slot == item.slot}
              }),
              gear.allSatisfy({ id,count in resolveGear(id) != nil && (0...1_000_000_000).contains(count) }),
              Set(equipment.keys).isSubset(of: hired) else { return false }
        if let tavern {
            guard tavern.refreshedAtFocus.isFinite, tavern.refreshedAtFocus >= 0, tavern.refreshedAtFocus <= focus,
                  tavern.visitors.count <= TavernRoster.capacity,
                  Set(tavern.visitors).count == tavern.visitors.count,
                  Set(tavern.visitors).isSubset(of: companionIDs) else { return false }
        }
        if let pendingRewards {
            guard Set(pendingRewards.keys).isSubset(of:locations),
                  pendingRewards.values.allSatisfy({!$0.isEmpty && validRewards($0) && $0.values.allSatisfy{$0 > 0}}),
                  Set(pendingRewards.values.flatMap(\.keys)).allSatisfy({rewardSpace(for:$0) >= 0}) else { return false }
        }
        var worn: [String:Int] = [:]
        for slots in equipment.values {
            for (slot,id) in slots {
                guard let item = resolveGear(id), item.slot.rawValue == slot else { return false }
                worn[id,default:0] += 1
            }
        }
        guard worn.allSatisfy({ gear[$0.key,default:0] >= $0.value }) else { return false }
        if let trip {
            guard locations.contains(trip.locationID), validTeam(trip.companions),
                  trip.startedFocus.isFinite, trip.startedFocus >= 0, trip.startedFocus <= focus,
                  trip.duration.isFinite, (60...86400).contains(trip.duration), trip.duration.truncatingRemainder(dividingBy:60) == 0,
                  (1...100000).contains(trip.level), (1...1000).contains(trip.gathering),
                  (1...1000).contains(trip.scouting), (1...1000).contains(trip.guarding),
                  trip.events >= 0, trip.events <= Int(min(trip.duration,focus-trip.startedFocus)/300),
                  validRewards(trip.rewards), validRewards(trip.packedRewards ?? [:]),
                  (trip.packedRewards ?? [:]).allSatisfy({$0.value > 0 && $0.value <= trip.rewards[$0.key,default:0]}),
                  trip.rewards.keys.allSatisfy({trip.unpackedCount($0) <= rewardSpace(for:$0)}),
                  Set(trip.discoveries).count == trip.discoveries.count,
                  Set(trip.discoveries).isSubset(of:discoveryIDs), !history.contains(where: { $0.id == trip.id }) else { return false }
        }
        return history.allSatisfy { record in
            locations.contains(record.locationID) && validTeam(record.companions)
                && record.duration.isFinite && record.duration >= 0 && record.duration <= record.plannedDuration
                && record.plannedDuration.isFinite && (60...86400).contains(record.plannedDuration) && record.plannedDuration.truncatingRemainder(dividingBy:60) == 0
                && (!record.completed || record.duration == record.plannedDuration)
                && validRewards(record.rewards) && Set(record.discoveries).count == record.discoveries.count && Set(record.discoveries).isSubset(of: discoveryIDs)
                && (record.claimableQuantity.map { record.completed && (0...record.rewards.values.reduce(0,+)).contains($0) } ?? true)
        }
    }
}

extension AppData {
    var expeditionState: ExpeditionState { garden.economy.expedition ?? ExpeditionState() }

    var expeditionStats: (gathering:Int,scouting:Int,guarding:Int) {
        expeditionStats(at:expeditionState.preferredLocation)
    }

    func expeditionStats(at locationID:String) -> (gathering:Int,scouting:Int,guarding:Int) {
        let state = expeditionState
        var gathering = 1 + garden.rank(.wand)*2, scouting = 1, guarding = 1
        for id in state.team(at:locationID) {
            if let companion = Companion.all.first(where: { $0.id == id }) {
                let gear = state.gearBonuses(for:id)
                gathering += companion.gathering + gear.gathering
                scouting += companion.scouting + gear.scouting
                guarding += companion.guarding + gear.guarding
            }
        }
        return (gathering,scouting,guarding)
    }

    var tavernVisitors:[Companion] {
        guard let roster = garden.economy.expedition?.tavern else { return [] }
        return tavernCandidates.filter { roster.visitors.contains($0.id) }
    }

    var canRefreshTavern:Bool {
        guard let visitors = garden.economy.expedition?.tavern?.visitors else { return false }
        return tavernCandidates.contains { !visitors.contains($0.id) }
    }

    private var tavernCandidates:[Companion] {
        let hired = garden.economy.expedition?.hired ?? []
        let level = levelProgress.level
        return Companion.all.filter { $0.level <= level && !hired.contains($0.id) }
    }

    private func nextTavernVisitors(after last:String?, intervals:Double = 1) -> [String] {
        let eligible = Set(tavernCandidates.map(\.id))
        let catalog = Companion.all.map(\.id)
        let candidates = catalog.indices.filter { eligible.contains(catalog[$0]) }
        guard !candidates.isEmpty else { return [] }
        let first = last.flatMap { catalog.firstIndex(of:$0) }
            .flatMap { previous in candidates.firstIndex { $0 > previous } } ?? 0
        let offset = Int((intervals-1).truncatingRemainder(dividingBy:Double(candidates.count))) * TavernRoster.capacity
        return (0..<min(TavernRoster.capacity,candidates.count)).map { catalog[candidates[(first+offset+$0)%candidates.count]] }
    }

    mutating func openTavern(at date:Date = Date()) -> Bool {
        var state = expeditionState
        guard state.tavern == nil else { return false }
        state.tavern = TavernRoster(refreshedAtFocus:gameFocus(at:date),visitors:nextTavernVisitors(after:nil))
        garden.economy.expedition = state
        return true
    }

    @discardableResult
    mutating func advanceTavern(to focus:Double) -> Bool {
        guard var state = garden.economy.expedition, let roster = state.tavern, focus.isFinite, focus >= roster.refreshedAtFocus else { return false }
        let intervals = ((focus-roster.refreshedAtFocus)/TavernRoster.interval).rounded(.down)
        let firstArrival = roster.visitors.isEmpty && !tavernCandidates.isEmpty
        guard intervals >= 1 || firstArrival else { return false }
        let refreshedAt = firstArrival ? focus:roster.refreshedAtFocus+intervals*TavernRoster.interval
        state.tavern = TavernRoster(refreshedAtFocus:refreshedAt,visitors:nextTavernVisitors(after:roster.visitors.last,intervals:max(1,intervals)))
        garden.economy.expedition = state
        return true
    }

    mutating func refreshTavern(at date:Date = Date()) -> Bool {
        var state = expeditionState
        guard let roster = state.tavern, garden.coins >= TavernRoster.refreshPrice, canRefreshTavern else { return false }
        state.tavern = TavernRoster(refreshedAtFocus:gameFocus(at:date),visitors:nextTavernVisitors(after:roster.visitors.last))
        garden.coins -= TavernRoster.refreshPrice
        garden.economy.expedition = state
        return true
    }

    mutating func hireCompanion(_ id: String) -> Bool {
        var state = expeditionState
        guard let companion = tavernVisitors.first(where: { $0.id == id }), garden.coins >= companion.price else { return false }
        garden.coins -= companion.price
        state.hired.insert(id)
        garden.economy.expedition = state
        return true
    }

    mutating func toggleExpeditionCompanion(_ id: String, at locationID:String) -> Bool {
        var state = expeditionState
        guard state.hired.contains(id), state.trip?.locationID != locationID,
              let location = ExpeditionLocation.all.first(where:{$0.id == locationID}), levelProgress.level >= location.level else { return false }
        state.migrateTeam()
        var team = state.team(at:locationID)
        if let index = team.firstIndex(of:id) { team.remove(at:index) }
        else { guard team.count < 4 else { return false }; team.append(id) }
        state.locationTeams?[locationID] = team.isEmpty ? nil:team
        garden.economy.expedition = state
        return true
    }

    mutating func equipExpeditionGear(_ id: String?, companion: String, slot: GearSlot) -> Bool {
        var state = expeditionState
        guard state.hired.contains(companion), !state.isTraveling(companion) else { return false }
        if let id {
            guard let item = state.resolveGear(id), item.slot == slot,
                  state.equipment[companion]?[slot.rawValue] != id else { return false }
            guard state.wornCount(id) < state.gear[id,default:0] else { return false }
        } else if state.equipment[companion]?[slot.rawValue] == nil { return false }
        state.equipment[companion,default:[:]][slot.rawValue] = id
        if state.equipment[companion]?.isEmpty == true { state.equipment.removeValue(forKey:companion) }
        garden.economy.expedition = state
        return true
    }

    mutating func embarkExpedition(locationID: String, minutes: Int, at date: Date = Date()) -> Bool {
        var state = expeditionState
        guard state.trip == nil, garden.economy.trip(.adventure) == nil, (1...1440).contains(minutes),
              let place = ExpeditionLocation.all.first(where: { $0.id == locationID }), levelProgress.level >= place.level else { return false }
        state.migrateTeam()
        let stats = expeditionStats(at:locationID)
        state.trip = ExpeditionTrip(locationID:locationID,startedFocus:gameFocus(at:date),duration:Double(minutes*60),level:levelProgress.level,
                                    companions:state.team(at:locationID),gathering:stats.gathering,scouting:stats.scouting,guarding:stats.guarding)
        state.preferredMinutes = minutes; state.preferredLocation = locationID
        garden.economy.expedition = state
        return true
    }

    @discardableResult
    mutating func advanceExpedition(to focus: Double) -> Bool {
        guard var state = garden.economy.expedition, var trip = state.trip, focus.isFinite, focus >= trip.startedFocus else { return false }
        let before = state
        let elapsed = min(trip.duration, focus - trip.startedFocus)
        let events = Int(elapsed / 300)
        while trip.events < events { expeditionEvent(trip:&trip,state:&state); trip.events += 1 }
        if elapsed >= trip.duration {
            finishExpedition(trip:&trip,elapsed:trip.duration,completed:true,state:&state)
        } else { state.trip = trip }
        guard state != before else { return false }
        garden.economy.expedition = state
        return true
    }

    @discardableResult
    mutating func returnExpedition(at date: Date = Date()) -> Bool {
        guard garden.economy.expedition?.trip != nil else { return false }
        let focus = gameFocus(at:date)
        advanceExpedition(to:focus)
        guard var state = garden.economy.expedition, var trip = state.trip else { return true }
        let elapsed = max(0,min(trip.duration,focus-trip.startedFocus))
        trip.rewards = trip.packedRewards ?? [:]
        trip.discoveries = trip.rewards.keys.sorted().map { "forage:"+$0 }
        finishExpedition(trip:&trip,elapsed:elapsed,completed:false,state:&state)
        garden.economy.expedition = state
        return true
    }

    mutating func claimExpeditionRewards(at locationID:String) -> Bool {
        guard var state = garden.economy.expedition,
              let rewards = state.pendingRewards?.removeValue(forKey:locationID), !rewards.isEmpty,
              rewards.allSatisfy({$0.value > 0 && $0.value <= ExpeditionState.rewardLimit-state.inventory[$0.key,default:0]}) else { return false }
        for (id,count) in rewards { state.inventory[id,default:0] += count }
        if state.pendingRewards?.isEmpty == true { state.pendingRewards = nil }
        garden.economy.expedition = state
        return true
    }

    private func expeditionEvent(trip: inout ExpeditionTrip, state: inout ExpeditionState) {
        let forage = NatureCatalog.forage.filter { $0.locations.contains(trip.locationID) && $0.level <= trip.level }
        let scouting = min(12,trip.scouting)
        let weighted = forage.map { item in
            item.rarity.weight * (100 + scouting * (NatureRarity.allCases.firstIndex(of:item.rarity) ?? 0) * 12)
        }
        let total = weighted.reduce(0,+)
        if total > 0 {
            var roll = state.random.next(total)
            for (index,item) in forage.enumerated() {
                if roll < weighted[index] {
                    let gatheringChance = min(100,max(0,trip.gathering-1)*5)
                    let guardingChance = min(25,trip.guarding*2)
                    let gatheredExtra = state.random.next(100) < gatheringChance
                    let guardedExtra = state.random.next(100) < guardingChance
                    let count = 1 + (gatheredExtra ? 1:0) + (guardedExtra ? 1:0)
                    let available = min(ExpeditionState.rewardLimit - trip.rewards[item.id,default:0],
                                        state.rewardSpace(for:item.id) - trip.unpackedCount(item.id))
                    if available > 0 { trip.rewards[item.id,default:0] += min(count,available) }
                    let key = "forage:" + item.id
                    if !trip.discoveries.contains(key) { trip.discoveries.append(key) }
                    break
                }
                roll -= weighted[index]
            }
        }
        let wildlife = NatureCatalog.wildlife.filter { $0.locations.contains(trip.locationID) && $0.level <= trip.level }
        if !wildlife.isEmpty, state.random.next(100) < min(85,30+trip.scouting*3) {
            let key = "wildlife:" + wildlife[state.random.next(wildlife.count)].id
            if !trip.discoveries.contains(key) { trip.discoveries.append(key) }
        }
    }

    private func finishExpedition(trip: inout ExpeditionTrip, elapsed: Double, completed: Bool, state: inout ExpeditionState) {
        var claimable = 0
        if completed {
            let remainingSeconds = Int(elapsed.truncatingRemainder(dividingBy:300))
            if remainingSeconds > 0, state.random.next(300) < remainingSeconds { expeditionEvent(trip:&trip,state:&state) }
            var pending = state.pendingRewards ?? [:]
            for id in trip.rewards.keys {
                let count = trip.unpackedCount(id)
                guard count > 0 else { continue }
                pending[trip.locationID,default:[:]][id,default:0] += count
                claimable += count
            }
            state.pendingRewards = pending.isEmpty ? nil:pending
        }
        state.discoveries.formUnion(trip.discoveries)
        state.history.append(ExpeditionRecord(id:trip.id,locationID:trip.locationID,duration:elapsed,plannedDuration:trip.duration,
                                              completed:completed,companions:trip.companions,rewards:trip.rewards,discoveries:trip.discoveries,
                                              claimableQuantity:completed ? claimable:nil))
        if state.history.count > 256 { state.history.removeFirst(state.history.count-256) }
        state.trip = nil
    }
}
