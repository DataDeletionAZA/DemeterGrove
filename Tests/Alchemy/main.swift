import Foundation

let now=Date()
func fixture()->AppData {
    var data=AppData()
    let seconds=Double((1..<8).reduce(0){$0+LevelProgress.requirement($1)}*60)
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds)]
    data.garden.coins=500
    for item in Ingredient.allCases {data.garden.ingredients[item.rawValue]=10}
    data.garden.economy.expedition=ExpeditionState(inventory:Dictionary(uniqueKeysWithValues:NatureCatalog.forage.map{($0.id,10)}))
    return data
}
func check(_ okay:Bool,_ name:String){precondition(okay,name)}
func encoded(_ data:AppData)throws->Data {let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return try encoder.encode(data)}
func advance(_ data:inout AppData,_ seconds:Double){data.sessions.append(FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds))}
let mint=AlchemyMaterial(name:"薄荷",kind:.ingredient)
let pumpkin=AlchemyMaterial(name:"南瓜",kind:.ingredient)
let herb=AlchemyMaterial(name:"月光草",kind:.material)
let all=Ingredient.allCases.map{AlchemyMaterial(name:$0.rawValue,kind:.ingredient)}+NatureCatalog.forage.map{AlchemyMaterial(name:$0.name,kind:.material)}
check(all.allSatisfy{(1...3).contains($0.profile?.traits.count ?? 0)},"each material has one to three traits")
check(AlchemyFormula.catalog.allSatisfy(\.isValid),"catalog formulas are valid")
var selection=PotionSelection()
for material in all.prefix(5){check(selection.add(material.name,kind:material.kind,available:1),"five distinct materials")}
check(!selection.add(all[5].name,kind:all[5].kind,available:1),"sixth rejected")
check(!selection.add(all[0].name,kind:all[0].kind,available:1),"duplicate rejected")
selection.remove(selection.portions[1].id)
check(selection.add(all[5].name,kind:all[5].kind,available:1) && Set(selection.portions.map(\.slot)).count == 5,"vacated slot reused")
let good=AlchemyAssessment(materials:[mint],heat:.gentle,minutes:8)
for poor in [AlchemyAssessment(materials:[mint],heat:.strong,minutes:8),AlchemyAssessment(materials:[mint],heat:.gentle,minutes:1),AlchemyAssessment(materials:[mint],heat:.gentle,minutes:40)] {
    check(poor.qualityBase<good.qualityBase && poor.successChance<good.successChance,"heat and timing affect outcome")
}
let fish=Ingredient.allCases.first{$0.category == .fish}!
let badFit=AlchemyAssessment(materials:[.init(name:fish.rawValue,kind:.ingredient)],heat:.strong,minutes:18)
check(badFit.successChance<good.successChance,"material suitability affects success")
let pumpkinAssessment=AlchemyAssessment(materials:[pumpkin],heat:.medium,minutes:14)
check(good.weights[.dew,default:0]>pumpkinAssessment.weights[.dew,default:0] && pumpkinAssessment.weights[.feed,default:0]>good.weights[.feed,default:0],"materials change effect weights")
var primary:[AlchemyEffect:Int]=[:],successes=0
for seed in UInt64(0)..<4000 {
    let result=AlchemyOutcome.roll(assessment:good,seed:seed)
    check(result.isValid,"weighted rolls have bounded unique effects")
    if let first=result.effects.first {primary[first,default:0]+=1;successes+=1}
}
check(successes>3500 && primary[.dew,default:0]>primary[.seeds,default:0]*3,"effect selection follows weights")
let seed=(UInt64(0)..<1000).first{AlchemyOutcome.roll(assessment:good,seed:$0).succeeded}!
var data=fixture()
let pristine=try encoded(data)
for materials in [[],[mint,mint],Array(all.prefix(6)),[herb,AlchemyMaterial(name:"moon_herb",kind:.material)]] {
    check(!data.startAlchemy(materials:materials,heat:.gentle,minutes:8,at:now),"invalid material set rejected")
    check(try encoded(data) == pristine,"rejected start keeps inventory")
}
check(!data.startAlchemy(materials:[mint],heat:.gentle,minutes:0,at:now),"zero duration rejected")
check(data.startAlchemy(materials:[mint],heat:.gentle,minutes:8,seed:seed,at:now),"single material brewing")
check(data.garden.ingredients[mint.name] == 9 && data.alchemyState.active != nil,"consume once at start")
let saved=try encoded(data)
check(!data.startAlchemy(materials:[mint],heat:.gentle,minutes:8,at:now),"no overlapping brews")
check(try encoded(data) == saved,"overlapping start leaves stock")
var reload=try JSONDecoder().decode(AppData.self,from:saved)
_ = try reload.validated(at:now)
check(reload.alchemyState == data.alchemyState,"outcome persists through reload")
check(!reload.collectAlchemy(at:now.addingTimeInterval(86400)),"wall time does not advance brewing")
reload.timer=TimerRun(kind:.rest,target:600,taskTitle:"休息",startedAt:now,resumedAt:now)
check(!reload.collectAlchemy(at:now.addingTimeInterval(600)),"rest does not advance brewing")
reload.timer=TimerRun(kind:.stopwatch,target:600,taskTitle:"阅读",startedAt:now,resumedAt:now)
reload.timer!.pause(at:now.addingTimeInterval(60))
check(!reload.collectAlchemy(at:now.addingTimeInterval(3600)),"pause does not advance brewing")
reload.timer=nil
advance(&reload,480)
check(reload.gameReadyEvents(at:now).filter{$0.id.hasPrefix("alchemy/")}.count == 1,"completed brew readiness")
check(reload.collectAlchemy(at:now) && !reload.collectAlchemy(at:now),"collect exactly once")
check(reload.alchemyState.batches.count == 1 && reload.knownAlchemyFormulas.contains{$0.materials == [mint]},"success discovers formula")
check(reload.inventory.contains{$0.id.hasPrefix("alchemy:") && $0.count == 1},"potion appears in inventory")
_ = try reload.validated(at:now)
let batch=reload.alchemyState.batches[0]
let balance=reload.garden.coins
check(reload.sellAlchemy(batch.id) && reload.garden.coins == balance+batch.price && !reload.sellAlchemy(batch.id),"sale consumes exactly one potion")
var purchased=fixture()
let formula=AlchemyFormula.catalog[2],coins=purchased.garden.coins
check(purchased.buyAlchemyFormula(formula.id) && purchased.garden.coins == coins-formula.purchasePrice,"purchase teaches recipe at listed price")
check(!purchased.buyAlchemyFormula(formula.id),"cannot buy known recipe twice")
var poor=fixture();poor.garden.coins=0
check(!poor.buyAlchemyFormula(formula.id) && poor.knownAlchemyFormulas.isEmpty,"insufficient money preserves knowledge")
var locked=AppData();locked.garden.coins=500;locked.garden.ingredients[mint.name]=10
check(!locked.buyAlchemyFormula(formula.id) && !locked.startAlchemy(materials:[mint],heat:.gentle,minutes:8,at:now),"unlock required")
var aliases=fixture();aliases.garden.economy.expedition?.inventory["moon_herb"]=1
aliases.garden.economy.finds["月光草"]=1
check(aliases.startAlchemy(materials:[herb],heat:.gentle,minutes:13,at:now) && aliases.potionMaterialCount("moon_herb") == 1,"legacy and expedition stock deducted once")
var legacyFish=fixture();legacyFish.garden.ingredients[fish.rawValue]=0;legacyFish.garden.economy.finds[fish.rawValue]=1
check(legacyFish.startAlchemy(materials:[.init(name:fish.rawValue,kind:.ingredient)],heat:.strong,minutes:18,at:now) && legacyFish.ingredientCount(fish) == 0,"legacy fish stock is usable")
var usable=fixture()
let mixture=AlchemyBatch(name:"复合药剂",formula:AlchemyFormula.catalog[0],outcome:.init(quality:80,effects:[.dew,.growth,.feed]),price:10)
usable.garden.economy.alchemy=AlchemyState(batches:[mixture])
let beforeUse=try encoded(usable)
check(!usable.useAlchemy(mixture.id),"growth effect requires planted crop")
check(try encoded(usable) == beforeUse,"unusable mixture does not partly apply")
usable.garden.plots[0].crop = .carrot
let water=usable.garden.water,feed=usable.ranchState.feedBags
check(usable.useAlchemy(mixture.id) && usable.garden.water == water+6 && usable.ranchState.feedBags == feed+2 && usable.garden.plots[0].bonus == 240,"all effects applied once")
check(!usable.useAlchemy(mixture.id),"consumed potion cannot be reused")
var failure=fixture()
let failureSeed=(UInt64(0)..<1000).first{!AlchemyOutcome.roll(assessment:good,seed:$0).succeeded}!
check(failure.startAlchemy(materials:[mint],heat:.gentle,minutes:8,seed:failureSeed,at:now),"failed result still starts brew")
advance(&failure,480)
check(failure.collectAlchemy(at:now) && failure.alchemyState.batches.isEmpty && failure.knownAlchemyFormulas.isEmpty && failure.garden.ingredients[mint.name] == 9,"failed brew consumes materials and discovers nothing")
var malformed=fixture();malformed.garden.economy.alchemy=AlchemyState(batches:[mixture])
malformed.garden.economy.alchemy!.batches[0].outcome.effects=[.dew,.dew]
do {_ = try malformed.validated(at:now);preconditionFailure("duplicate effects accepted")}catch{}
print("Alchemy: materials, weighted effects, focus time, purchases, inventory, persistence and validation passed")
