import Foundation

let now=Date()
func fixture()->AppData {
    var data=AppData()
    let seconds=Double((1..<30).reduce(0){$0+LevelProgress.requirement($1)}*60)
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds)]
    data.garden.economy.mining=MiningState(inventory:Dictionary(uniqueKeysWithValues:Mineral.all.map{($0.id,100)}))
    data.garden.economy.finds=Dictionary(uniqueKeysWithValues:ForgeMaterial.all.filter{$0.kind == "纤维"}.map{($0.id,100)})
    data.garden.economy.expedition=ExpeditionState(hired:["rowan"],team:["rowan"],equipment:["rowan":[GearSlot.tool.rawValue:"copper_sickle"]],gear:["copper_sickle":1])
    return data
}
func encoded(_ data:AppData)throws->Data {let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return try encoder.encode(data)}
let sword=ForgeMold.all.first{$0.id == "sword"}!
let good=["iron","copper","sheep_wool"]
let strange=["gold","gold","gold"]
var failed=fixture()
let before=try encoded(failed)
for invalid in [0,21,Int.min,Int.max] {assert(!failed.forgeGear(moldID:"sword",materialIDs:good,natural:invalid))}
assert(!failed.forgeGear(moldID:"missing",materialIDs:good,natural:12))
assert(!failed.forgeGear(moldID:"sword",materialIDs:["iron","unknown","sheep_wool"],natural:12))
assert(!failed.forgeGear(moldID:"sword",materialIDs:["iron"],natural:12))
let afterInvalid=try encoded(failed)
assert(afterInvalid == before)
assert(failed.forgeGear(moldID:"sword",materialIDs:good,natural:1))
assert(failed.forgeState.lastResult!.roll.criticalFailure && failed.forgeState.lastResult!.gearID == nil)
assert(failed.miningState.inventory["iron"] == 99 && failed.miningState.inventory["copper"] == 99 && failed.garden.economy.finds["sheep_wool"] == 99)
assert(failed.expeditionState.generatedGear == nil && failed.expeditionState.gear["copper_sickle"] == 1)
_ = try failed.validated(at:now)

var rough=fixture()
assert(rough.forgeModifier(mold:sword,materialIDs:good)>rough.forgeModifier(mold:sword,materialIDs:strange))
assert(rough.forgeGear(moldID:"sword",materialIDs:strange,natural:2))
let roughResult=rough.forgeState.lastResult!
assert(roughResult.roll.quality == 15 && roughResult.gearID != nil)
assert(rough.miningState.inventory["gold"] == 97)
let roughGear=rough.expeditionState.resolveGear(roughResult.gearID!)!
var lucky=fixture()
assert(lucky.forgeGear(moldID:"sword",materialIDs:strange,natural:20))
let luckyResult=lucky.forgeState.lastResult!
let luckyGear=lucky.expeditionState.resolveGear(luckyResult.gearID!)!
assert(luckyResult.roll.criticalSuccess && luckyResult.roll.quality == 100)
assert(luckyGear.scouting>roughGear.scouting)
assert(lucky.expeditionState.equipment["rowan"]?[GearSlot.tool.rawValue] == "copper_sickle")
assert(lucky.equipExpeditionGear(luckyGear.id,companion:"rowan",slot:.tool))
assert(lucky.expeditionStats.scouting>fixture().expeditionStats.scouting)
assert(!lucky.stockEquipment(luckyGear.id,at:now))
assert(lucky.equipExpeditionGear(nil,companion:"rowan",slot:.tool))
assert(lucky.stockEquipment(luckyGear.id,at:now))
assert(lucky.garden.shopOrderCount == lucky.garden.capacity)
assert(!lucky.stockEquipment("copper_sickle",at:now))
assert(lucky.expeditionState.gear[luckyGear.id] == 0)
let order=lucky.garden.autoShopState.equipmentOrders![0]
assert(lucky.unstockEquipment(order.id,at:now))
assert(!lucky.unstockEquipment(order.id,at:now))
assert(lucky.expeditionState.gear[luckyGear.id] == 1)
assert(lucky.stockEquipment(luckyGear.id,at:now))
let soldFocus=lucky.gameFocus(at:now)+300
lucky.sessions.append(FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:300))
assert(lucky.advanceAutoShop(to:soldFocus))
assert(lucky.garden.autoShopState.equipmentOrders!.isEmpty)
assert(lucky.garden.autoShopState.receivables == luckyGear.salePrice)
assert(lucky.garden.autoShopState.receipts.first!.equipmentSprite == luckyGear.spriteKey)
assert(lucky.collectShopProceeds(at:now) == luckyGear.salePrice)
assert(lucky.collectShopProceeds(at:now) == 0)
_ = try lucky.validated(at:now)

var special=fixture()
assert(special.forgeGear(moldID:"sword",materialIDs:good,natural:12))
let specialResult=special.forgeState.lastResult!
assert(specialResult.name.contains("牧途守望剑"))
assert(special.forgeGear(moldID:"sword",materialIDs:good,natural:13))
assert(special.forgeState.lastResult!.gearID == specialResult.gearID)
assert(special.expeditionState.gear[specialResult.gearID!] == 2)
assert(special.forgeGear(moldID:"coat",materialIDs:["cloud_fleece","alpaca_fibre","moonstone"],natural:20))
assert(special.forgeState.lastResult!.name.contains("月云护行衣"))
let coat=special.expeditionState.resolveGear(special.forgeState.lastResult!.gearID!)!
assert(coat.slot == .coat && special.equipExpeditionGear(coat.id,companion:"rowan",slot:.coat))
let inventory=special.inventory.filter{$0.id.hasPrefix("gear:")}
assert(inventory.contains{$0.id == "gear:"+coat.id})
let bytes=try encoded(special)
let decoded=try JSONDecoder().decode(AppData.self,from:bytes)
assert(decoded.forgeState == special.forgeState && decoded.expeditionState == special.expeditionState)
_ = try decoded.validated(at:now)
var corrupt=decoded
corrupt.garden.economy.forge?.lastResult?.materialIDs[0]="unknown"
assert(!corrupt.forgeState.isValid(in:corrupt.expeditionState))
corrupt=decoded
corrupt.garden.economy.forge?.lastResult?.gearID="copper_sickle"
assert(!corrupt.forgeState.isValid(in:corrupt.expeditionState))
var old=try JSONSerialization.jsonObject(with:try encoded(fixture())) as! [String:Any]
var oldGarden=old["garden"] as! [String:Any],oldEconomy=oldGarden["economy"] as! [String:Any]
var oldExpedition=oldEconomy["expedition"] as! [String:Any]
oldExpedition.removeValue(forKey:"generatedGear");oldEconomy["expedition"]=oldExpedition;oldEconomy.removeValue(forKey:"forge")
oldGarden["economy"]=oldEconomy;old["garden"]=oldGarden
let legacy=try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:old))
assert(legacy.expeditionState.gear["copper_sickle"] == 1 && legacy.expeditionState.equipment["rowan"]?[GearSlot.tool.rawValue] == "copper_sickle")
_ = try legacy.validated(at:now)
print("PASS: forge material conservation, invalid inputs, catastrophic/rough/masterpiece outcomes, compatibility, fixed combinations, quality stacks, equip/inventory, shared shop capacity, unstock/receivables and save migration")
