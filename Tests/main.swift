import Foundation

let start = Date(timeIntervalSince1970: 1_800_000_000)
for crop in Crop.allCases {
    let plot = Plot(crop:crop,plantedAt:100)
    for (progress,stage) in [(0.0,0),(0.079,0),(0.081,1),(0.299,1),(0.301,2),(0.999,2),(1.0,3),(2.0,3)] {
        assert(plot.growthStage(100+crop.seconds*progress) == stage)
    }
}
var data = AppData()
let plot = data.garden.plots[0].id
assert(data.plant(.carrot, in: plot))
assert(!data.plant(.tomato, in: plot))
assert(!data.harvest(plot))
data.timer = TimerRun(kind: .pomodoro, target: 600, taskTitle: "阅读", startedAt: start, resumedAt: start)
data.timer!.pause(at: start.addingTimeInterval(200))
assert(data.timer!.elapsed(at: start.addingTimeInterval(500)) == 200)
data.timer!.resumedAt = start.addingTimeInterval(500)
assert(data.timer!.elapsed(at: start.addingTimeInterval(1000)) == 600)
let result = data.finishTimer(at: start.addingTimeInterval(1000))!
assert(result.seconds == 600 && result.water == 2)
assert(data.finishTimer(at: start.addingTimeInterval(1001)) == nil)
assert(data.harvest(plot))
assert(!data.harvest(plot))
assert(data.cook(.soup))
assert(!data.cook(.soup))
assert(data.stock(.soup))
assert(!data.stock(.soup))
assert(!data.collectSale())
data.timer = TimerRun(kind: .rest, target: 300, taskTitle: "休息", startedAt: start, resumedAt: start)
_ = data.finishTimer(at: start.addingTimeInterval(300))
assert(data.totalFocus == 600 && !data.collectSale())
for seconds in [100.0, 200.0] {
    data.timer = TimerRun(kind: .stopwatch, target: 1, taskTitle: "学习", startedAt: start, resumedAt: start)
    _ = data.finishTimer(at: start.addingTimeInterval(seconds))
}
assert(data.totalFocus == 900 && data.garden.water == 6)
assert(data.collectSale() && data.garden.coins == 53)
assert(!data.collectSale())
assert(data.buySeeds() && data.garden.coins == 35)
var emptyGarden = AppData()
emptyGarden.garden.seeds = 0
emptyGarden.garden.coins = 0
emptyGarden.garden.water = 1
assert(emptyGarden.exchangeSeed() && emptyGarden.garden.seeds == 1)
assert(!emptyGarden.exchangeSeed())
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: start)!
var habit = Habit(title: "读书", days: [dayKey(start), dayKey(yesterday)])
assert(habit.streak(at: start) == 2)
habit.days.remove(dayKey(start))
assert(habit.streak(at: start) == 1)
assert(Diary(text: "今天 学习\nabc").characters == 7)
assert(clockText(59.1) == "01:00" && clockText(3601) == "01:00:01")
let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("save.json")
try SaveFile.write(data, to: file)
let restored = try SaveFile.read(file)
assert(restored.totalFocus == data.totalFocus && restored.garden.coins == 35)
var invalid = data
invalid.sessions.append(invalid.sessions[0])
do { _ = try invalid.validated(); fatalError("重复结算应被拒绝") } catch DataIssue.invalid { }
try Data("broken".utf8).write(to: file)
do { _ = try SaveFile.read(file); fatalError("损坏存档应被拒绝") } catch { }
print("PASS: pause/resume, capped countdown, single settlement, cumulative rewards, farm/kitchen/shop, habits, diary count, atomic save/restore, invalid data rejection")

for dish in Dish.allCases {
    assert(dish.isValid)
    assert(Dish.develop(method:dish.method,category:dish.category,ingredients:dish.ingredients)?.id == dish.id)
}
var cookingData = AppData()
let cakeBase = FoodBase.all.first { $0.id == "cake" }!
let custom = Dish.develop(base: cakeBase, additions: ["薄荷":1,"蜂蜜":1])!
assert(custom.isValid && !custom.isDiscovery)
assert(Dish.develop(base: cakeBase, additions: ["砂糖":-1]) == nil)
assert(Dish.develop(base: cakeBase, additions: ["未知食材":1]) == nil)
let beforeCooking = cookingData.garden.ingredients
assert(!cookingData.cook(custom) && cookingData.garden.ingredients == beforeCooking)
for (key,value) in custom.ingredients { cookingData.garden.ingredients[key] = value }
assert(cookingData.cook(custom))
assert(cookingData.garden.recipes[custom.id] == custom && cookingData.garden.crafts[custom.id] == 1)
assert(!cookingData.cook(custom))
assert(cookingData.stock(custom))
let full = try JSONEncoder().encode(cookingData)
let restoredCooking = try JSONDecoder().decode(AppData.self, from: full).validated()
assert(restoredCooking.garden.order?.dish == custom)
let improved = Dish.develop(base: cakeBase, additions: ["薄荷":1,"蜂蜜":1], practice: 3)!
assert(improved.quality > custom.quality)
let waterBefore = cookingData.garden.water
assert(cookingData.buyIngredient(.coffee, withWater:true))
assert(cookingData.garden.water == waterBefore-3 && cookingData.garden.ingredients["咖啡豆"] == 1)
var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppData())) as! [String:Any]
var legacyGarden = legacy["garden"] as! [String:Any]
legacyGarden.removeValue(forKey:"recipes"); legacyGarden.removeValue(forKey:"crafts")
legacyGarden["order"] = ["dish":"胡萝卜浓汤", "placedAt":0]
legacy["garden"] = legacyGarden
let migrated = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject:legacy)).validated()
assert(migrated.garden.order?.dish == Dish.soup && migrated.garden.recipes.isEmpty)
print("PASS: built-in discoveries, free combinations, ingredient consumption, recipe persistence, practice, market, legacy save migration")

func focus(_ seconds: Double, into data: inout AppData) {
    data.sessions.append(FocusSession(id: UUID(), title: "专注", kind: .stopwatch, date: start, seconds: seconds))
}
func rejected(_ data: AppData) {
    do { _ = try data.validated(); fatalError("无效存档应被拒绝") } catch DataIssue.invalid { } catch { fatalError("存档检查错误") }
}
func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}
assert(Money.text(0) == "0 铜纳特")
assert(Money.text(29) == "1 银西可")
assert(Money.text(493) == "1 金加隆")
assert(Money.text(493+29+1) == "1 金加隆 1 银西可 1 铜纳特")
assert(LevelProgress(seconds: 599).level == 1)
assert(LevelProgress(seconds: 600).level == 2 && LevelProgress(seconds: 600).experience == 0)
assert(LevelProgress.requirement(1) == 10 && LevelProgress.requirement(2) == 17 && LevelProgress.requirement(3) == 23)
let carried = LevelProgress(seconds: (10+17+4.5)*60)
assert(carried.level == 3 && carried.experience == 4.5 && carried.needed == 23)
for level in 2...100 { assert(LevelProgress.requirement(level) > LevelProgress.requirement(level-1)) }
var economy = AppData()
economy.keys = ["2026-10-28":999]
assert(economy.typingReward == 0 && !economy.redeemTyping())
economy.keys["2026-10-29"] = 2001
assert(economy.typingReward == 0)
economy.mouseClicks = ["2026-10-29":27000]
assert(economy.typingReward == 3 && economy.redeemTyping())
assert(economy.garden.coins == 3 && economy.levelProgress.experience == 0 && economy.totalFocus == 0)
assert(!economy.redeemTyping())
economy.keys["2026-10-29"] = 12000
assert(economy.typingReward == 0)
economy.keys["2026-10-29"] = 12001
assert(economy.redeemTyping() && economy.garden.coins == 4)
let typingRoundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(economy)).validated()
assert(typingRoundTrip.typingReward == 0)
var locked = AppData()
locked.garden.coins = 100_000
assert(!locked.upgrade(.soil) && !locked.embark(.fishing))
assert(locked.garden.coins == 100_000 && locked.garden.economy.journey == nil)
assert(!locked.embark(.adventure) && !locked.embark(.potions,recipe:"dew"))
assert(!locked.buyCosmetic(Cosmetic.all.first{$0.id == "travel"}!,at:date(5,1)))
focus(600, into:&locked)
locked.garden.coins = Upgrade.soil.price(0)-1
assert(!locked.upgrade(.soil) && locked.garden.rank(.soil) == 0)
locked.garden.coins += 1
assert(locked.upgrade(.soil) && locked.garden.coins == 0 && locked.harvestYield == 3)
assert(!locked.buySeeds() && !locked.buyIngredient(.milk))
assert(!locked.buyCosmetic(Cosmetic.all.first{$0.id == "travel"}!,at:date(5,1)))
var expanded = AppData()
focus(100_000, into:&expanded)
expanded.garden.coins = 100_000
let initialPlots = expanded.garden.plots.map(\.id)
for expected in [12,18] { assert(expanded.upgrade(.farmland) && expanded.garden.plots.count == expected) }
assert(!expanded.upgrade(.farmland) && expanded.garden.plots.prefix(6).map(\.id) == initialPlots)
assert(Set(expanded.garden.plots.map(\.id)).count == 18)
for expected in [3,5] { assert(expanded.upgrade(.storefront) && expanded.garden.capacity == expected) }
assert(!expanded.upgrade(.storefront))
_ = try expanded.validated()
var tools = expanded
assert(tools.upgrade(.watering) && tools.upgrade(.kitchen) && tools.upgrade(.soil))
let planted = tools.garden.plots[0].id
assert(tools.plant(.carrot, in:planted) && tools.garden.plots[0].duration == 540)
assert(tools.upgrade(.watering) && tools.garden.plots[0].duration == 540)
focus(539, into:&tools)
assert(!tools.harvest(planted))
focus(1, into:&tools)
let carrots = tools.garden.ingredients["胡萝卜",default:0]
assert(tools.harvest(planted) && tools.garden.ingredients["胡萝卜"] == carrots+3)
let friedRice = Dish.allCases.first{$0.id == "蛋炒饭"}!
for _ in 0..<2 {
    tools.garden.ingredients["米饭"] = 1; tools.garden.ingredients["鸡蛋"] = 1
    assert(tools.cook(tools.garden.recipes[friedRice.id] ?? friedRice))
    assert(tools.garden.recipes[friedRice.id]?.quality == friedRice.quality+5)
}
assert(tools.stock(friedRice))
let orderID = tools.garden.orders[0].id, frozenPrice = tools.garden.orders[0].price
assert(tools.garden.orders[0].dish.quality == friedRice.quality+5)
assert(tools.upgrade(.shop) && tools.garden.orders[0].price == frozenPrice)
focus(299, into:&tools)
assert(!tools.collectSale(orderID))
focus(1, into:&tools)
let beforeSale = tools.garden.coins
assert(tools.collectSale(orderID) && tools.garden.coins == beforeSale+frozenPrice)
assert(!tools.collectSale(orderID))
for _ in 0..<5 { tools.garden.dishes[friedRice.id,default:0] += 1; assert(tools.stock(friedRice)) }
assert(!tools.stock(friedRice) && tools.garden.orders.count == 5)
focus(300, into:&tools)
let orderIDs = tools.garden.orders.map(\.id)
for id in orderIDs { assert(tools.collectSale(id)); assert(!tools.collectSale(id)) }
assert(tools.garden.orders.isEmpty)
_ = try tools.validated()
var seasons = AppData()
focus(100_000, into:&seasons); seasons.garden.coins = 100_000
let autumn = Cosmetic.all.first{$0.id == "pumpkin"}!, winter = Cosmetic.all.first{$0.id == "snow"}!
for (month,day,available) in [(10,23,false),(10,24,true),(11,2,true),(11,3,false)] { assert(autumn.available(date(month,day)) == available) }
for (month,day,available) in [(12,19,false),(12,20,true),(1,5,true),(1,6,false)] { assert(winter.available(date(month,day)) == available) }
assert(winter.available(date(1,5,year:2027)))
let seasonalCoins = seasons.garden.coins
assert(!seasons.buyCosmetic(autumn,at:date(11,3)) && seasons.garden.coins == seasonalCoins)
assert(seasons.buyCosmetic(autumn,at:date(10,24)) && seasons.garden.coins == seasonalCoins-autumn.price)
assert(!seasons.buyCosmetic(autumn,at:date(10,25)))
assert(seasons.wear(autumn.id,slot:.head) && !seasons.wear(autumn.id,slot:.outfit))
let ownedSeason = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(seasons)).validated()
assert(ownedSeason.garden.economy.hat == autumn.id && ownedSeason.garden.economy.owned.contains(autumn.id))
assert(!autumn.available(date(5,1)))
let forgedCosmetic = Cosmetic(id:"travel",name:"旅行袍",slot:.outfit,price:-100,level:1)
let coinsBeforeForgery = seasons.garden.coins
assert(seasons.buyCosmetic(forgedCosmetic,at:date(5,1)) && seasons.garden.coins == coinsBeforeForgery-493)
var dressed=AppData()
assert(dressed.garden.economy.worn(.outfit) == "black")
assert(!dressed.wear("shirt",slot:.top) && !dressed.wear("unknown",slot:.head))
focus(100_000,into:&dressed);dressed.garden.coins=10_000
let combinations:[(ClothingSlot,String)] = [(.top,"shirt"),(.bottom,"jeans"),(.outer,"coat"),(.neck,"grayScarf"),(.wrist,"watch"),(.socks,"blackSocks"),(.head,"wizard"),(.face,"glasses"),(.shoes,"blackShoes")]
for (slot,id) in combinations {
    let item=Cosmetic.all.first{$0.id == id}!,before=dressed.garden.coins
    assert(dressed.buyCosmetic(item,at:date(5,1)) && dressed.garden.coins == before-item.price)
    assert(dressed.wear(id,slot:slot) && dressed.garden.economy.worn(slot) == id)
}
assert(dressed.garden.economy.worn(.outfit).isEmpty && dressed.garden.economy.outfit == "base")
assert(!dressed.wear("shirt",slot:.bottom) && !dressed.wear("glasses",slot:.head))
for (slot,id) in combinations {assert(dressed.garden.economy.worn(slot) == id)}
assert(dressed.wear("",slot:.neck) && dressed.garden.economy.worn(.neck).isEmpty)
assert(dressed.garden.economy.worn(.wrist) == "watch" && dressed.garden.economy.worn(.face) == "glasses")
assert(dressed.wear("grayScarf",slot:.neck))
let paired=try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(dressed)).validated()
for (slot,id) in combinations {assert(paired.garden.economy.worn(slot) == id)}
assert(dressed.wear("black",slot:.outfit))
assert(dressed.garden.economy.worn(.outfit) == "black" && dressed.garden.economy.worn(.top).isEmpty && dressed.garden.economy.worn(.bottom).isEmpty)
for (slot,id) in combinations where slot != .top && slot != .bottom {assert(dressed.garden.economy.worn(slot) == id)}
assert(dressed.wear("",slot:.outfit) && dressed.garden.economy.worn(.outfit).isEmpty)
assert(dressed.wear("shirt",slot:.top) && dressed.wear("jeans",slot:.bottom))
assert(dressed.buyCosmetic(Cosmetic.all.first{$0.id == "travel"}!,at:date(5,1)))
assert(dressed.wear("travel",slot:.outfit) && dressed.garden.economy.worn(.top).isEmpty && dressed.garden.economy.worn(.bottom).isEmpty)
assert(dressed.wear("shirt",slot:.top) && dressed.garden.economy.worn(.outfit).isEmpty)
for (slot,id) in combinations where slot != .bottom {assert(dressed.garden.economy.worn(slot) == id)}
for slot in ClothingSlot.allCases {assert(dressed.wear("",slot:slot) && dressed.garden.economy.worn(slot).isEmpty)}
assert(dressed.wear("black",slot:.outfit) && dressed.garden.economy.outfit.isEmpty)
_ = try dressed.validated()
var oldWardrobe=try JSONSerialization.jsonObject(with:JSONEncoder().encode(seasons)) as! [String:Any]
var oldWardrobeGarden=oldWardrobe["garden"] as! [String:Any]
var oldEconomy=oldWardrobeGarden["economy"] as! [String:Any]
oldEconomy.removeValue(forKey:"equipped");oldEconomy["outfit"]="travel"
oldWardrobeGarden["economy"]=oldEconomy;oldWardrobe["garden"]=oldWardrobeGarden
let restoredWardrobe=try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:oldWardrobe)).validated()
assert(restoredWardrobe.garden.economy.equipped == nil && restoredWardrobe.garden.economy.worn(.outfit) == "travel" && restoredWardrobe.garden.economy.worn(.head) == "pumpkin")
assert(ClothingSlot.allCases.allSatisfy{slot in Cosmetic.all.contains{$0.slot == slot}})
assert(Cosmetic.all.count == Set(Cosmetic.all.map(\.id)).count)
var journey = AppData()
focus((10+17)*60, into:&journey)
assert(journey.levelProgress.level == 3 && journey.embark(.fishing))
assert(!journey.embark(.fishing) && journey.collectJourney() == nil)
journey.timer = TimerRun(kind:.stopwatch,target:1,taskTitle:"专注",startedAt:start,resumedAt:start)
journey.timer!.pause(at:start.addingTimeInterval(899))
assert(journey.collectJourney() == nil && journey.timer!.elapsed(at:start.addingTimeInterval(3000)) == 899)
_ = journey.finishTimer(at:start.addingTimeInterval(3000))
assert(journey.collectJourney() == nil)
focus(1,into:&journey)
assert(journey.collectJourney() != nil && journey.collectJourney() == nil)
let fish = journey.garden.economy.finds.first{$0.value>0}!.key
let beforeFishSale = journey.garden.coins
assert(journey.sellFind(fish) && journey.garden.coins == beforeFishSale+journey.findPrice(fish))
assert(!journey.sellFind(fish))
focus(100_000,into:&journey)
assert(journey.upgrade(.rod) == false)
journey.garden.coins = 100_000
assert(journey.upgrade(.rod) && journey.embark(.fishing))
assert(journey.garden.economy.journey?.duration == 780)
focus(780,into:&journey);assert(journey.collectJourney() != nil)
assert(journey.upgrade(.wand) && journey.embark(.adventure))
focus(1200,into:&journey);assert(journey.collectJourney() != nil)
assert(journey.garden.economy.finds.values.contains(2))
let potionIngredientBefore = journey.garden.ingredients["薄荷",default:0]
assert(!journey.embark(.potions,recipe:"dew") && journey.garden.ingredients["薄荷",default:0] == potionIngredientBefore)
journey.garden.ingredients["薄荷"] = 1;journey.garden.economy.finds["月光草"] = 0
assert(!journey.embark(.potions,recipe:"dew") && journey.garden.ingredients["薄荷"] == 1)
journey.garden.economy.finds["月光草"] = 1
assert(journey.embark(.potions,recipe:"dew"))
assert(journey.garden.ingredients["薄荷"] == 0 && journey.garden.economy.finds["月光草"] == 0)
assert(!journey.embark(.potions,recipe:"dew"))
focus(900,into:&journey);assert(journey.collectJourney() != nil)
let potionWater = journey.garden.water
assert(journey.usePotion("dew") && journey.garden.water == potionWater+6 && !journey.usePotion("dew"))
journey.garden.economy.finds["seed"] = 1
let potionSeeds = journey.garden.seeds
assert(journey.usePotion("seed") && journey.garden.seeds == potionSeeds+3 && !journey.usePotion("seed"))
journey.garden.economy.finds["bloom"] = 1
assert(!journey.usePotion("bloom") && journey.garden.economy.finds["bloom"] == 1)
let potionPlot = journey.garden.plots[0].id
assert(journey.plant(.carrot,in:potionPlot) && journey.usePotion("bloom"))
assert(journey.garden.plots[0].progress(journey.totalFocus) == 0.5)
_ = try journey.validated()
var legacyV1 = try JSONSerialization.jsonObject(with:JSONEncoder().encode(AppData())) as! [String:Any]
var oldGarden = legacyV1["garden"] as! [String:Any]
oldGarden.removeValue(forKey:"economy");oldGarden["coins"] = 42
oldGarden["order"] = ["dish":"胡萝卜浓汤","placedAt":0]
legacyV1["version"] = 1;legacyV1["garden"] = oldGarden
let oldData = try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:legacyV1)).validated()
assert(oldData.version == 4 && oldData.garden.coins == 42*29 && oldData.garden.order?.price == 12*29)
try SaveFile.write(oldData,to:file)
let oldDataAgain = try SaveFile.read(file)
assert(oldDataAgain.garden.coins == 42*29)
var poisoned = AppData(); poisoned.garden.economy.upgrades["farmland"] = Int.max;rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.upgrades["storefront"] = Int.max;rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.upgrades["unknown"] = 1;rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.redeemedKeys = 1;rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.owned.insert("unknown");rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.hat = "pumpkin";rejected(poisoned)
poisoned = paired; poisoned.garden.economy.equipped?["unknown"]="shirt";rejected(poisoned)
poisoned = paired; poisoned.garden.economy.equipped?["bottom"]="shirt";rejected(poisoned)
poisoned = paired; poisoned.garden.economy.equipped?["head"]="wizard";rejected(poisoned)
poisoned = paired; poisoned.garden.economy.equipped?["top"]="unknown";rejected(poisoned)
poisoned = paired; poisoned.garden.economy.owned.remove("shirt");rejected(poisoned)
poisoned = paired; poisoned.garden.economy.outfit="";rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.expeditions = Int.max;rejected(poisoned)
poisoned = AppData(); poisoned.garden.plots[0].bonus = -1;rejected(poisoned)
poisoned = AppData(); poisoned.garden.plots[0].duration = 0;rejected(poisoned)
poisoned = AppData(); poisoned.garden.coins = -1;rejected(poisoned)
poisoned = AppData(); poisoned.keys["day"] = -1;rejected(poisoned)
poisoned = AppData(); poisoned.garden.ingredients["未知食材"] = 1;rejected(poisoned)
poisoned = AppData(); poisoned.timer = TimerRun(kind:.stopwatch,target:Double.greatestFiniteMagnitude,taskTitle:"专注",startedAt:start);rejected(poisoned)
poisoned = AppData(); poisoned.timer = TimerRun(kind:.stopwatch,target:1,taskTitle:"专注",startedAt:Date(timeIntervalSince1970:-Double.greatestFiniteMagnitude));rejected(poisoned)
poisoned = AppData(); poisoned.garden.economy.journey = Journey(kind:.fishing,startedAt:0,duration:900);rejected(poisoned)
poisoned = journey; poisoned.garden.economy.journey = Journey(kind:.potions,startedAt:0,duration:900,recipe:"unknown");rejected(poisoned)
poisoned = journey; poisoned.garden.economy.journey = Journey(kind:.fishing,startedAt:0,duration:300);rejected(poisoned)
poisoned = journey; poisoned.garden.order = ShopOrder(dish:.soup,placedAt:0,proceeds:-1);rejected(poisoned)
poisoned = journey; poisoned.garden.order = ShopOrder(dish:.soup,placedAt:0,proceeds:1)
poisoned.garden.economy.extraOrders = [poisoned.garden.order!];rejected(poisoned)
print("PASS: currency conversion, XP carry, single typing redemption, locked and insufficient purchases, expansion, frozen growth and sale prices, nonstacking kitchen bonuses, independent clothing slots, outfit conflicts, accessory preservation, seasonal ownership, legacy wardrobe decoding, journeys, potion consumption, v1 currency migration, malicious save rejection")

var fitted = AppData()
assert(fitted.garden.economy.adjustments == nil && fitted.garden.economy.adjustment(for:"glasses") == WearAdjustment())
fitted.garden.economy.owned = ["grayScarf","greenScarf","glasses"]
fitted.garden.economy.adjustments = ["grayScarf":WearAdjustment(x:-12,y:8,scale:110),"greenScarf":WearAdjustment(x:9,y:-6,scale:95),"glasses":WearAdjustment(x:2,y:-3,scale:101)]
assert(fitted.wear("grayScarf",slot:.neck))
let grayFit = fitted.garden.economy.adjustment(for:"grayScarf")
assert(fitted.wear("greenScarf",slot:.neck))
assert(fitted.garden.economy.adjustment(for:"grayScarf") == grayFit && fitted.garden.economy.adjustment(for:"greenScarf").scale == 95)
assert(fitted.wear("",slot:.neck) && fitted.wear("grayScarf",slot:.neck))
assert(fitted.garden.economy.adjustment(for:"grayScarf") == grayFit)
try SaveFile.write(fitted,to:file)
var fittedAgain = try SaveFile.read(file)
assert(fittedAgain.garden.economy.adjustments == fitted.garden.economy.adjustments)
fittedAgain.garden.economy.adjustments?.removeValue(forKey:"grayScarf")
assert(fittedAgain.garden.economy.adjustment(for:"grayScarf") == WearAdjustment())
assert(fittedAgain.garden.economy.adjustment(for:"glasses") == WearAdjustment(x:2,y:-3,scale:101))
try SaveFile.write(fittedAgain,to:file)
let resetFit = try SaveFile.read(file)
assert(resetFit.garden.economy.adjustment(for:"grayScarf") == WearAdjustment() && resetFit.garden.economy.adjustment(for:"greenScarf").scale == 95)
var beforeFits = try JSONSerialization.jsonObject(with:JSONEncoder().encode(fitted)) as! [String:Any]
var beforeFitsGarden = beforeFits["garden"] as! [String:Any]
var beforeFitsEconomy = beforeFitsGarden["economy"] as! [String:Any]
beforeFitsEconomy.removeValue(forKey:"adjustments");beforeFitsGarden["economy"] = beforeFitsEconomy;beforeFits["garden"] = beforeFitsGarden
let withoutFits = try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:beforeFits)).validated()
assert(withoutFits.garden.economy.adjustments == nil && withoutFits.garden.economy.adjustment(for:"glasses") == WearAdjustment())
for item in Cosmetic.all where item.slot.isAccessory {
    var boundaryFits = AppData()
    boundaryFits.garden.economy.adjustments = [item.id:WearAdjustment(x:-30,y:30,scale:75)]
    _ = try boundaryFits.validated()
    boundaryFits.garden.economy.adjustments?[item.id] = WearAdjustment(x:30,y:-30,scale:125)
    _ = try boundaryFits.validated()
}
for invalidFit in [WearAdjustment(scale:74),WearAdjustment(scale:126),WearAdjustment(x:-31),WearAdjustment(x:31),WearAdjustment(y:-31),WearAdjustment(y:31),WearAdjustment(x:Int.max),WearAdjustment(scale:Int.min)] {
    var invalidFits = AppData();invalidFits.garden.economy.adjustments = ["glasses":invalidFit];rejected(invalidFits)
}
for id in ["unknown","black","travel","shirt","sweater","trousers","jeans"] {
    var invalidFits = AppData();invalidFits.garden.economy.adjustments = [id:WearAdjustment()];rejected(invalidFits)
}
assert(Cosmetic.all.first{$0.asset == "TopSweater"}?.name == "炭灰毛衣")
assert(Cosmetic.all.first{$0.asset == "TopShirt"}?.name == "米白衬衫")
assert(Cosmetic.all.first{$0.asset == "SocksCream"}?.name == "奶油色短袜")
print("PASS: per-item accessory adjustment defaults, independent positions, wear/remove retention, persistence, single-item reset, old-save compatibility, safe boundary values and invalid adjustment rejection")

var typed = AppData()
typed.garden.cropSeeds = ["番茄":2,"柠檬":1]
let emptyPlot = typed.garden.plots[0].id
let waterAtPlant = typed.garden.water
assert(!typed.plant(.carrot,in:emptyPlot) && typed.garden.water == waterAtPlant)
assert(typed.plant(.lemon,in:emptyPlot) && typed.garden.cropSeeds["柠檬"] == 0 && typed.garden.cropSeeds["番茄"] == 2)
typed.garden.coins = 36
assert(typed.buySeeds(.pumpkin) && typed.garden.cropSeeds["南瓜"] == 3 && typed.garden.cropSeeds["番茄"] == 2 && typed.garden.coins == 0)
let tomatoSeeds = typed.garden.cropSeeds["番茄"]
typed.garden.seeds += 3
assert(typed.garden.seeds == 8 && typed.garden.cropSeeds["番茄"]! >= tomatoSeeds!)
var seedsJSON = try JSONSerialization.jsonObject(with:JSONEncoder().encode(typed)) as! [String:Any]
var seedsGarden = seedsJSON["garden"] as! [String:Any]
seedsGarden.removeValue(forKey:"cropSeeds");seedsGarden["seeds"] = 37;seedsJSON["garden"] = seedsGarden
let seedMigration = try JSONDecoder().decode(AppData.self,from:JSONSerialization.data(withJSONObject:seedsJSON)).validated()
assert(seedMigration.garden.seeds == 37 && seedMigration.garden.coins == typed.garden.coins)
let typedRoundTrip = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(typed)).validated()
assert(typedRoundTrip.garden.cropSeeds == typed.garden.cropSeeds)

var assembly = AppData()
assembly.garden.ingredients = ["大米":1,"鸡蛋":1]
let rice = Dish.develop(method:.boil,category:.main,ingredients:["大米":1])!
let fried = Dish.allCases.first{$0.id == "蛋炒饭"}!
assert(!assembly.canCook(fried) && !assembly.cook(fried))
let moneyBeforeCraft = assembly.garden.coins
assert(assembly.cook(rice) && assembly.garden.ingredients["米饭"] == 1 && assembly.garden.ingredients["大米"] == 0)
assert(assembly.garden.dishes[rice.id] == nil && assembly.garden.isDiscovered(rice))
assert(assembly.cook(fried) && assembly.garden.ingredients["米饭"] == 0 && assembly.garden.ingredients["鸡蛋"] == 0)
assert(assembly.garden.coins == moneyBeforeCraft && assembly.garden.dishes[fried.id] == 1 && assembly.garden.isDiscovered(fried))
assert(!assembly.cook(fried) && assembly.garden.dishes[fried.id] == 1)
assembly.garden.coins = Ingredient.cakeBase.purchasePrice
assert(assembly.buyIngredient(.cakeBase) && assembly.garden.ingredients["蛋糕胚"] == 1 && assembly.garden.coins == 0)
assembly.garden.ingredients["草莓"] = 1;assembly.garden.ingredients["牛奶"] = 1
let strawberryCake = Dish.allCases.first{$0.id == "草莓奶油蛋糕"}!
assert(assembly.cook(strawberryCake) && assembly.garden.ingredients["蛋糕胚"] == 0 && assembly.garden.coins == 0)
for ingredient in [Ingredient.noodles,.cakeBase,.bread] {
    let intermediate = Dish.allCases.first{$0.outputIngredient == ingredient}!
    assembly.garden.ingredients = intermediate.ingredients
    assert(assembly.cook(intermediate) && assembly.garden.ingredients[ingredient.rawValue] == 1)
}
assembly.garden.ingredients = [:]
assembly.garden.economy.finds["银鳞鱼"] = 1
let steamedFish = Dish.develop(method:.steam,category:.hot,ingredients:["银鳞鱼":1])!
assert(assembly.ingredientCount(.silverFish) == 1 && assembly.cook(steamedFish))
assert(assembly.ingredientCount(.silverFish) == 0 && !assembly.sellFind("银鳞鱼") && !assembly.cook(steamedFish))
let discoveryRoundTrip = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(assembly)).validated()
assert(discoveryRoundTrip.garden.isDiscovered(steamedFish) && discoveryRoundTrip.garden.recipes[steamedFish.id]?.method == .steam)
let undiscoveredSoup = Dish.allCases.first{$0.id == "奶油玉米汤"}!
assert(!AppData().garden.isDiscovered(undiscoveredSoup))

var oldCounter = AppData();oldCounter.keys = ["day":123456];oldCounter.garden.economy.redeemedKeys = 123;oldCounter.garden.coins = 321
let oldCounterMigration = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(oldCounter)).validated()
assert(oldCounterMigration.garden.coins == 321 && oldCounterMigration.consumedActions == 123000 && oldCounterMigration.typingReward == 0)
var combinedCounter = oldCounterMigration
combinedCounter.mouseClicks = ["day":9544]
assert(combinedCounter.totalActions == 133000 && combinedCounter.typingReward == 1 && combinedCounter.redeemTyping())
assert(combinedCounter.garden.coins == 322 && combinedCounter.typingReward == 0 && combinedCounter.garden.economy.redeemedKeys == 123)
combinedCounter.mouseClicks?["day",default:0] += 9999
assert(combinedCounter.typingReward == 0)
combinedCounter.mouseClicks?["day",default:0] += 1
assert(combinedCounter.redeemTyping() && combinedCounter.garden.coins == 323)
_ = try combinedCounter.validated()

let oldDiary = try JSONDecoder().decode(Diary.self,from:Data(#"{"text":"雨天读书","mood":"平静"}"#.utf8))
assert(oldDiary.text == "雨天读书" && oldDiary.mood == "平静" && oldDiary.moodSymbol == nil && oldDiary.moodImage == nil)
var moodData = AppData();moodData.diaries["day"] = Diary(text:"日记",mood:"开心",moodSymbol:"sun.max.fill",moodImage:Data([1,2,3]))
let moodRoundTrip = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(moodData)).validated()
assert(moodRoundTrip.diaries["day"] == moodData.diaries["day"])
moodData.diaries["day"]?.moodImage = Data(repeating:0,count:262145);rejected(moodData)
moodData.diaries["day"]?.moodImage = nil;moodData.diaries["day"]?.moodSymbol = String(repeating:"x",count:81);rejected(moodData)
var invalidStock = AppData();invalidStock.garden.cropSeeds = ["未知":1];rejected(invalidStock)
invalidStock = AppData();invalidStock.garden.cropSeeds = ["胡萝卜":-1];rejected(invalidStock)
invalidStock = AppData();invalidStock.garden.seeds = -1;rejected(invalidStock)
invalidStock = AppData();invalidStock.mouseClicks = ["day":-1];rejected(invalidStock)
invalidStock = AppData();invalidStock.garden.economy.redeemedActions = 1;rejected(invalidStock)
print("PASS: typed seed ownership and migration, raw-to-intermediate crafting, buyable intermediates, no repeat ingredient charges, fishing consumption, hidden recipe discovery state, combined input reward migration, diary mood compatibility and validation")

let previousFriedOrder = try JSONDecoder().decode(ShopOrder.self,from:Data(#"{"dish":"蛋炒饭","placedAt":0}"#.utf8))
assert(previousFriedOrder.dish.ingredients == ["大米":1,"鸡蛋":1] && previousFriedOrder.price == 17*29)
print("PASS: pending legacy recipe orders retain their original ingredient valuation")

var invalidCounterMigration = AppData()
invalidCounterMigration.keys = ["day":1000]
invalidCounterMigration.garden.economy.redeemedKeys = 1
invalidCounterMigration.garden.economy.redeemedActions = 999
rejected(invalidCounterMigration)
assert(Dish.allCases.first{$0.id == "蛋糕胚"}?.category == .dessert)
assert(Dish.allCases.first{$0.id == "面条"}?.baseID == "noodles")
print("PASS: legacy redeemed actions cannot be claimed twice, intermediate recipe categories match their food")
