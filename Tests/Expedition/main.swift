import Foundation

let now=Date()
func fixture(level:Int=25)->AppData {
    var data=AppData()
    let seconds=Double((1..<level).reduce(0){$0+LevelProgress.requirement($1)}*60)
    if seconds>0 {data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds)]}
    data.garden.coins=100_000
    data.garden.economy.expedition=ExpeditionState(random:FocusRandom(state:12345))
    data.garden.economy.mining=MiningState(inventory:Dictionary(uniqueKeysWithValues:Mineral.all.map{($0.id,100)}))
    data.garden.economy.finds=["sheep_wool":20,"cloud_fleece":20,"alpaca_fibre":20]
    return data
}
func encode<T:Encodable>(_ value:T)throws->Data {
    let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
    return try encoder.encode(value)
}
func recruit(_ id:String, in data:inout AppData)->Bool {
    _ = data.openTavern(at:now)
    for _ in Companion.all {
        if data.tavernVisitors.contains(where:{$0.id == id}) {return data.hireCompanion(id)}
        guard data.refreshTavern(at:now) else {return false}
    }
    return false
}

var tavern=fixture(level:6)
assert(tavern.openTavern(at:now))
assert(!tavern.openTavern(at:now))
assert(tavern.tavernVisitors.map(\.id) == ["rowan","mira"])
assert(!tavern.hireCompanion("oswin") && !tavern.hireCompanion("iris"))
var broke=tavern
broke.garden.coins=TavernRoster.refreshPrice-1
assert(!broke.refreshTavern(at:now) && broke.garden.coins == TavernRoster.refreshPrice-1)
assert(broke.expeditionState.tavern == tavern.expeditionState.tavern)
let beforeRefresh=tavern.garden.coins
assert(tavern.refreshTavern(at:now))
assert(tavern.garden.coins == beforeRefresh-TavernRoster.refreshPrice)
assert(tavern.tavernVisitors.map(\.id) == ["rowan","oswin"])
assert(tavern.hireCompanion("oswin"))
assert(tavern.tavernVisitors.map(\.id) == ["rowan"])
let beforeAuto=tavern.garden.coins
let beforeCycle=tavern.expeditionState.tavern
tavern.timer=TimerRun(kind:.stopwatch,target:3600,taskTitle:"阅读",startedAt:now,resumedAt:now)
_ = tavern.advanceFocusWorld(at:now.addingTimeInterval(1799))
assert(tavern.expeditionState.tavern == beforeCycle)
tavern.timer?.pause(at:now.addingTimeInterval(1799))
_ = tavern.advanceFocusWorld(at:now.addingTimeInterval(3600))
assert(tavern.expeditionState.tavern == beforeCycle)
let pauseTime=now.addingTimeInterval(3600)
tavern.timer?.resumedAt=pauseTime
assert(tavern.advanceFocusWorld(at:pauseTime.addingTimeInterval(1)))
assert(tavern.tavernVisitors.map(\.id) == ["rowan","mira"] && tavern.garden.coins == beforeAuto)
assert(!tavern.refreshTavern(at:pauseTime.addingTimeInterval(1)))
let tavernSave=try encode(tavern)
let reloadedTavern=try JSONDecoder().decode(AppData.self,from:tavernSave)
assert(reloadedTavern.expeditionState.tavern == tavern.expeditionState.tavern)
let cycleStart=tavern.expeditionState.tavern!.refreshedAtFocus
var restTavern=tavern
_ = restTavern.finishTimer(at:pauseTime.addingTimeInterval(1))
restTavern.timer=TimerRun(kind:.rest,target:3600,taskTitle:"休息",startedAt:now,resumedAt:now)
_ = restTavern.advanceFocusWorld(at:now.addingTimeInterval(3600))
assert(restTavern.expeditionState.tavern?.refreshedAtFocus == cycleStart)
var lockedTavern=fixture(level:1)
assert(lockedTavern.openTavern(at:now) && lockedTavern.tavernVisitors.isEmpty)
assert(!lockedTavern.canRefreshTavern && !lockedTavern.refreshTavern(at:now))
lockedTavern.sessions=fixture(level:5).sessions
assert(lockedTavern.advanceFocusWorld(at:now))
assert(lockedTavern.tavernVisitors.map(\.id) == ["rowan","mira"])
var rotatingTavern=fixture(level:18)
assert(rotatingTavern.openTavern(at:now))
var steppingTavern=rotatingTavern
for interval in 1...8 {
    assert(steppingTavern.advanceTavern(to:steppingTavern.totalFocus+Double(interval)*TavernRoster.interval))
}
assert(rotatingTavern.advanceTavern(to:rotatingTavern.totalFocus+8*TavernRoster.interval))
assert(rotatingTavern.expeditionState.tavern == steppingTavern.expeditionState.tavern)

var team=fixture()
assert(team.levelProgress.level == 25)
let beforeHire=team.garden.coins
assert(!team.hireCompanion("unknown"))
assert(team.openTavern(at:now))
assert(team.hireCompanion("rowan"))
assert(team.garden.coins == beforeHire-Companion.all[0].price)
assert(!team.hireCompanion("rowan"))
assert(!team.toggleExpeditionCompanion("mira",at:"forest"))
for person in Companion.all.dropFirst() where person.level<=25 {assert(recruit(person.id,in:&team))}
for person in Companion.all.prefix(4) {assert(team.toggleExpeditionCompanion(person.id,at:"forest"))}
assert(team.expeditionState.hired.count == 8 && team.expeditionState.team(at:"forest").count == 4)
assert(!team.toggleExpeditionCompanion("cedar",at:"forest"))
assert(team.toggleExpeditionCompanion("mira",at:"forest"))
assert(team.toggleExpeditionCompanion("cedar",at:"forest"))
assert(team.expeditionState.team(at:"forest") == ["rowan","oswin","iris","cedar"])
assert(team.expeditionState.team(at:"river").isEmpty)
assert(team.toggleExpeditionCompanion("mira",at:"river"))
assert(!team.toggleExpeditionCompanion("mira",at:"reef"))
assert(!team.toggleExpeditionCompanion("mira",at:"missing"))

team.garden.economy.expedition?.gear=["copper_sickle":2,"iron_coat":1]
assert(team.equipExpeditionGear("copper_sickle",companion:"rowan",slot:.tool))
assert(!team.equipExpeditionGear("copper_sickle",companion:"mira",slot:.coat))
assert(team.equipExpeditionGear("copper_sickle",companion:"mira",slot:.tool))
assert(!team.equipExpeditionGear("copper_sickle",companion:"oswin",slot:.tool))
assert(team.equipExpeditionGear(nil,companion:"mira",slot:.tool))
assert(!team.equipExpeditionGear(nil,companion:"mira",slot:.tool))
assert(team.equipExpeditionGear("iron_coat",companion:"rowan",slot:.coat))
var low=fixture(level:1)
assert(!low.hireCompanion("rowan"))
assert(!low.embarkExpedition(locationID:"forest",minutes:30,at:now))

for minutes in [0,-1,1441,Int.max] {assert(!team.embarkExpedition(locationID:"forest",minutes:minutes,at:now))}
assert(!team.embarkExpedition(locationID:"unknown",minutes:30,at:now))
let stats=team.expeditionStats
assert(team.embarkExpedition(locationID:"forest",minutes:30,at:now))
assert(!team.embarkExpedition(locationID:"river",minutes:30,at:now))
let trip=team.expeditionState.trip!
assert(trip.companions.count == 4 && trip.gathering == stats.gathering && trip.guarding == stats.guarding)
assert(!team.toggleExpeditionCompanion("rowan",at:"forest"))
assert(team.toggleExpeditionCompanion("rowan",at:"river"))
assert(!team.equipExpeditionGear(nil,companion:"rowan",slot:.tool))
assert(team.equipExpeditionGear("copper_sickle",companion:"mira",slot:.tool))
assert(team.expeditionState.gear["copper_sickle"] == 2 && team.expeditionState.wornCount("copper_sickle") == 2)
assert(team.expeditionState.trip == trip)
let started=trip.startedFocus
assert(!team.advanceExpedition(to:started+299))
assert(team.advanceExpedition(to:started+300))
let earned=team.expeditionState.trip!.rewards
assert(earned.values.reduce(0,+)>0 && team.expeditionState.inventory.isEmpty)
assert(!team.advanceExpedition(to:started+300))
assert(!team.advanceExpedition(to:started-1))
team.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now,resumedAt:nil,accumulated:300)
assert(team.returnExpedition(at:now.addingTimeInterval(10000)))
assert(team.expeditionState.trip == nil && team.expeditionState.inventory == earned)
assert(team.expeditionState.history.last!.duration == 300 && !team.expeditionState.history.last!.completed)
let returned=try encode(team.expeditionState)
assert(!team.returnExpedition(at:now) && !team.advanceExpedition(to:started+10000))
let afterReturned=try encode(team.expeditionState)
assert(afterReturned == returned)

for (seed,minutes,earnsReward) in [(UInt64(1),1,false),(UInt64(2),1,true),(UInt64(1),4,true),(UInt64(13),5,true)] {
    var solo=fixture(level:5)
    solo.garden.economy.expedition?.random=FocusRandom(state:seed)
    var early=solo
    assert(solo.embarkExpedition(locationID:"forest",minutes:minutes,at:now))
    assert(early.embarkExpedition(locationID:"forest",minutes:10,at:now))
    let soloStart=solo.expeditionState.trip!.startedFocus
    assert(solo.expeditionState.trip!.companions.isEmpty)
    assert(!solo.advanceExpedition(to:soloStart+Double(minutes*60-1)))
    assert(solo.advanceExpedition(to:soloStart+Double(minutes*60)))
    assert(solo.expeditionState.trip == nil && solo.expeditionState.inventory.isEmpty == !earnsReward)
    assert(solo.expeditionState.history.last!.completed && solo.expeditionState.history.last!.duration == Double(minutes*60))
    early.timer=TimerRun(kind:.stopwatch,target:600,taskTitle:"阅读",startedAt:now,resumedAt:now)
    assert(early.returnExpedition(at:now.addingTimeInterval(Double(minutes*60))))
    assert(early.expeditionState.trip == nil && !early.expeditionState.history.last!.completed)
    assert(early.expeditionState.inventory == solo.expeditionState.inventory)
    assert(early.expeditionState.random == solo.expeditionState.random)
}

var equipped=fixture(level:25)
assert(equipped.embarkExpedition(locationID:"beach",minutes:60,at:now))
equipped.garden.economy.expedition?.trip?.gathering=240
equipped.garden.economy.expedition?.trip?.scouting=240
equipped.garden.economy.expedition?.trip?.guarding=240
assert(equipped.advanceExpedition(to:equipped.totalFocus+3600))
assert((24...36).contains(equipped.expeditionState.inventory.values.reduce(0,+)))

var gathering=fixture(level:5)
gathering.garden.economy.expedition?.random=FocusRandom(state:5)
let berry="wild_strawberry"
assert(!gathering.collectExpeditionForage(berry,at:"forest"))
assert(gathering.embarkExpedition(locationID:"forest",minutes:10,at:now))
assert(!gathering.collectExpeditionForage(berry,at:"forest"))
gathering.timer=TimerRun(kind:.stopwatch,target:600,taskTitle:"阅读",startedAt:now,resumedAt:nil,accumulated:300)
assert(gathering.advanceExpedition(to:gathering.gameFocus(at:now)))
let ready=gathering.expeditionState.trip!.unpackedCount(berry)
assert(ready>0)
let gatheringSave=try encode(gathering)
gathering=try JSONDecoder().decode(AppData.self,from:gatheringSave)
assert(gathering.expeditionState.trip?.packedRewards == nil)
var automatic=gathering
assert(!gathering.collectExpeditionForage(berry,at:"river"))
assert(gathering.collectExpeditionForage(berry,at:"forest"))
assert(!gathering.collectExpeditionForage(berry,at:"forest"))
assert(gathering.expeditionState.inventory[berry] == ready)
assert(gathering.expeditionState.trip?.unpackedCount(berry) == 0)
let packedSave=try encode(gathering)
gathering=try JSONDecoder().decode(AppData.self,from:packedSave)
_ = try gathering.validated(at:now)
assert(!gathering.collectExpeditionForage(berry,at:"forest"))
let beforeBerries=gathering.garden.ingredients[Ingredient.strawberry.rawValue,default:0]
assert(gathering.prepareForage(berry,count:ready))
gathering.timer?.accumulated=600
automatic.timer?.accumulated=600
assert(gathering.advanceExpedition(to:gathering.gameFocus(at:now)))
assert(automatic.advanceExpedition(to:automatic.gameFocus(at:now)))
assert(gathering.expeditionState.history == automatic.expeditionState.history)
assert(gathering.expeditionState.inventory[berry,default:0] == automatic.expeditionState.inventory[berry,default:0]-ready)
assert(gathering.garden.ingredients[Ingredient.strawberry.rawValue] == beforeBerries+ready)

var paused=fixture(level:5)
paused.timer=TimerRun(kind:.stopwatch,target:1800,taskTitle:"阅读",startedAt:now,resumedAt:now)
assert(paused.embarkExpedition(locationID:"forest",minutes:10,at:now))
paused.timer?.pause(at:now.addingTimeInterval(180))
assert(!paused.advanceExpedition(to:paused.gameFocus(at:now.addingTimeInterval(10000))))
assert(paused.expeditionState.trip!.events == 0)
paused.timer=TimerRun(kind:.rest,target:1200,taskTitle:"休息",startedAt:now,resumedAt:now)
assert(!paused.advanceExpedition(to:paused.gameFocus(at:now.addingTimeInterval(10000))))
assert(paused.expeditionState.trip!.events == 0)

var long=fixture()
assert(long.embarkExpedition(locationID:"polar",minutes:1440,at:now))
var stepped=long
let longStart=long.expeditionState.trip!.startedFocus
long.advanceExpedition(to:longStart+1_000_000)
for seconds in stride(from:1,through:86400,by:113) {stepped.advanceExpedition(to:longStart+Double(seconds))}
stepped.advanceExpedition(to:longStart+86400)
assert(long.expeditionState == stepped.expeditionState)
assert(long.expeditionState.history.count == 1 && long.expeditionState.trip == nil)
let polarIDs=Set(NatureCatalog.forage.filter{$0.locations.contains("polar") && $0.level<=25}.map(\.id))
assert(Set(long.expeditionState.inventory.keys).isSubset(of:polarIDs))
assert(!long.expeditionState.inventory.isEmpty)

for place in ExpeditionLocation.all {
    var region=fixture(level:place.level)
    assert(region.embarkExpedition(locationID:place.id,minutes:30,at:now))
    let start=region.expeditionState.trip!.startedFocus
    region.advanceExpedition(to:start+1800)
    let ids=Set(NatureCatalog.forage.filter{$0.locations.contains(place.id) && $0.level<=place.level}.map(\.id))
    assert(!region.expeditionState.inventory.isEmpty && Set(region.expeditionState.inventory.keys).isSubset(of:ids))
    assert(region.expeditionState.isValid(focus:start+1800))
}

for (location,level,materials,wildlife) in [
    ("marsh",8,["cattail_fibre","bog_myrtle","bog_glass"],"american_bittern"),
    ("reef",28,["sea_grape","reef_silk","tide_glass"],"reef_manta"),
    ("highland",35,["alpine_juniper","cloud_lichen","wind_silver"],"alpine_ibex"),
    ("ruins",40,["echo_vine","archive_moss","rune_shard"],"archive_moth")
] {
    var locked=fixture(level:level-1), unlocked=fixture(level:level)
    assert(!locked.embarkExpedition(locationID:location,minutes:60,at:now))
    assert(unlocked.embarkExpedition(locationID:location,minutes:60,at:now))
    if location == "marsh" {
        assert(unlocked.advanceExpedition(to:unlocked.totalFocus+3600))
        assert(unlocked.expeditionState.inventory["bog_glass"] == nil)
        unlocked=fixture(level:10)
    } else {
        assert(unlocked.returnExpedition(at:now))
    }
    assert(unlocked.embarkExpedition(locationID:location,minutes:1440,at:now))
    let saved=try encode(unlocked)
    unlocked=try JSONDecoder().decode(AppData.self,from:saved)
    _=try unlocked.validated(at:now)
    let start=unlocked.expeditionState.trip!.startedFocus
    unlocked.garden.economy.expedition?.trip?.gathering=240
    unlocked.garden.economy.expedition?.trip?.scouting=240
    unlocked.garden.economy.expedition?.trip?.guarding=240
    assert(unlocked.advanceExpedition(to:start+86400))
    assert(Set(unlocked.expeditionState.inventory.keys) == Set(materials))
    assert(unlocked.expeditionState.discoveries.contains("wildlife:"+wildlife))
    assert(unlocked.expeditionState.inventory.values.reduce(0,+) <= 288*3)
    assert(unlocked.expeditionState.isValid(focus:start+86400))
}

var expandedTeam=fixture(level:40)
for (id,level) in [("coralie",30),("arden",35),("sable",40)] {
    var locked=fixture(level:level-1), unlocked=fixture(level:level)
    assert(locked.openTavern(at:now))
    assert(!locked.hireCompanion(id))
    let person=Companion.all.first{$0.id == id}!
    assert(unlocked.openTavern(at:now))
    for _ in Companion.all where !unlocked.tavernVisitors.contains(where:{$0.id == id}) {
        assert(unlocked.refreshTavern(at:now))
    }
    let coins=unlocked.garden.coins
    assert(person.level == level && unlocked.hireCompanion(id) && !unlocked.hireCompanion(id))
    assert(unlocked.garden.coins == coins-person.price)
    assert(recruit(id,in:&expandedTeam) && expandedTeam.toggleExpeditionCompanion(id,at:"ruins"))
}
assert(expandedTeam.embarkExpedition(locationID:"ruins",minutes:30,at:now))
let expandedSave=try encode(expandedTeam)
let expandedReload=try JSONDecoder().decode(AppData.self,from:expandedSave)
_ = try expandedReload.validated(at:now)
assert(expandedReload.expeditionState.trip?.companions == ["coralie","arden","sable"])

var legacy=fixture()
legacy.garden.economy.journey=Journey(kind:.adventure,startedAt:legacy.totalFocus,duration:600)
assert(!legacy.embarkExpedition(locationID:"forest",minutes:30,at:now))

var previousTeam=fixture()
previousTeam.garden.economy.expedition?.preferredLocation="river"
previousTeam.garden.economy.expedition?.team=["rowan"]
previousTeam.garden.economy.expedition?.hired=["rowan"]
let previousTeamSave=try encode(previousTeam)
previousTeam=try JSONDecoder().decode(AppData.self,from:previousTeamSave)
assert(previousTeam.expeditionState.locationTeams == nil && previousTeam.expeditionState.team(at:"river") == ["rowan"])
assert(previousTeam.embarkExpedition(locationID:"forest",minutes:1,at:now))
assert(previousTeam.expeditionState.trip?.companions == [] && previousTeam.expeditionState.team(at:"river") == ["rowan"])
assert(previousTeam.returnExpedition(at:now))
assert(previousTeam.embarkExpedition(locationID:"river",minutes:1,at:now))
assert(previousTeam.expeditionState.trip?.companions == ["rowan"])
_ = try previousTeam.validated(at:now)

let snapshot=try encode(team)
let decoded=try JSONDecoder().decode(AppData.self,from:snapshot)
assert(decoded.expeditionState == team.expeditionState)
assert(decoded.expeditionState.isValid(focus:decoded.gameFocus(at:now)))
_ = try decoded.validated(at:now)
var bad=decoded.expeditionState
bad.locationTeams?["forest"]?.append("rowan")
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
bad=decoded.expeditionState
bad.tavern?.visitors=["unknown"]
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
bad=decoded.expeditionState
bad.inventory["unknown"]=1
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
bad=decoded.expeditionState
bad.equipment["mira"]=[GearSlot.coat.rawValue:"copper_sickle"]
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
bad=decoded.expeditionState
bad.equipment["oswin"]=[GearSlot.coat.rawValue:"iron_coat"]
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
bad=decoded.expeditionState
bad.history[0].duration = .nan
assert(!bad.isValid(focus:decoded.gameFocus(at:now)))
var corrupt=decoded
corrupt.garden.economy.expedition=bad
do {_ = try corrupt.validated(at:now);assertionFailure("Invalid expedition must fail save validation")}
catch { }
var oldObject=try JSONSerialization.jsonObject(with:snapshot) as! [String:Any]
var oldGarden=oldObject["garden"] as! [String:Any]
var oldEconomy=oldGarden["economy"] as! [String:Any]
oldEconomy.removeValue(forKey:"expedition")
oldGarden["economy"]=oldEconomy;oldObject["garden"]=oldGarden
let oldData=try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:oldObject))
assert(oldData.garden.economy.expedition == nil && oldData.garden.coins == decoded.garden.coins)
assert(oldData.miningState == decoded.miningState && oldData.garden.economy.finds == decoded.garden.economy.finds)
print("PASS: tavern roster, local expedition teams, equipment, effective-focus timing, manual forage, return, completion, all regions and save validation")
