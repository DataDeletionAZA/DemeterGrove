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

var team=fixture()
assert(team.levelProgress.level == 25)
let beforeHire=team.garden.coins
assert(!team.hireCompanion("unknown"))
assert(team.hireCompanion("rowan"))
assert(team.garden.coins == beforeHire-Companion.all[0].price)
assert(!team.hireCompanion("rowan"))
assert(!team.toggleExpeditionCompanion("mira"))
for person in Companion.all.dropFirst() {assert(team.hireCompanion(person.id))}
for person in Companion.all.prefix(4) {assert(team.toggleExpeditionCompanion(person.id))}
assert(team.expeditionState.hired.count == 8 && team.expeditionState.team.count == 4)
assert(!team.toggleExpeditionCompanion("cedar"))
assert(team.toggleExpeditionCompanion("mira"))
assert(team.toggleExpeditionCompanion("cedar"))
assert(team.expeditionState.team == ["rowan","oswin","iris","cedar"])

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
assert(team.toggleExpeditionCompanion("rowan"))
assert(team.equipExpeditionGear(nil,companion:"rowan",slot:.tool))
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

var solo=fixture(level:5)
assert(solo.embarkExpedition(locationID:"forest",minutes:1,at:now))
let soloStart=solo.expeditionState.trip!.startedFocus
assert(solo.expeditionState.trip!.companions.isEmpty)
assert(!solo.advanceExpedition(to:soloStart+59))
assert(solo.advanceExpedition(to:soloStart+60))
assert(solo.expeditionState.trip == nil && solo.expeditionState.inventory.values.reduce(0,+)>0)
assert(solo.expeditionState.history.last!.completed && solo.expeditionState.history.last!.duration == 60)

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

var legacy=fixture()
legacy.garden.economy.journey=Journey(kind:.adventure,startedAt:legacy.totalFocus,duration:600)
assert(!legacy.embarkExpedition(locationID:"forest",minutes:30,at:now))

let snapshot=try encode(team)
let decoded=try JSONDecoder().decode(AppData.self,from:snapshot)
assert(decoded.expeditionState == team.expeditionState)
assert(decoded.expeditionState.isValid(focus:decoded.gameFocus(at:now)))
_ = try decoded.validated(at:now)
var bad=decoded.expeditionState
bad.team.append(bad.team[0])
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
print("PASS: expedition team cap, legacy equipment preservation, equipment ownership, snapshot stats, effective-focus timing, early return, completion, all regions and save validation")
