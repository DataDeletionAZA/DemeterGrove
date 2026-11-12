import Foundation

let epoch = Date(timeIntervalSince1970: 1_800_000_000)
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
@discardableResult
func finish(_ data: inout AppData, _ seconds: Double, kind: TimerKind = .stopwatch) -> UUID {
    let timer = TimerRun(kind:kind,target:seconds,taskTitle:"专注",startedAt:epoch,resumedAt:epoch)
    data.timer = timer
    check(data.finishTimer(at:epoch.addingTimeInterval(seconds)) != nil,"completed timer")
    return timer.id
}

check(Money.sickle == 29 && Money.galleon == 29 * 17,"currency ratios")
for minutes in [30,60,120] {
    for rank in 0...Upgrade.watering.limit {
        var data = AppData()
        data.garden.economy.upgrades[Upgrade.watering.rawValue] = rank
        let waterBefore = data.garden.water
        finish(&data,Double(minutes * 60))
        check(data.garden.coins == minutes * 2,"whole focus pays per minute")
        check(data.garden.water - waterBefore == minutes / 5 * (1 + rank),"watering rank earns extra dew for every completed five-minute block")
    }
}
var split = AppData()
for seconds in [20.0,39,1,59,1,60] { finish(&split,seconds) }
check(split.totalFocus == 180 && split.garden.coins == 6,"fractional minutes carry across timers")
let balance = split.garden.coins
finish(&split,600,kind:.rest)
check(split.garden.coins == balance && split.totalFocus == 180,"rest has no focus income")
let lastID = finish(&split,60)
let afterFinish = split.garden.coins
check(split.finishTimer(at:epoch.addingTimeInterval(61)) == nil && split.garden.coins == afterFinish,"repeat finish pays nothing")
var duplicate = TimerRun(kind:.stopwatch,target:60,taskTitle:"专注",startedAt:epoch,resumedAt:epoch)
duplicate.id = lastID
split.timer = duplicate
check(split.finishTimer(at:epoch.addingTimeInterval(60))?.seconds == 0 && split.garden.coins == afterFinish,"duplicate timer ID pays nothing")
var oldFocus = AppData()
oldFocus.garden.coins = 321
oldFocus.garden.water = 19
oldFocus.garden.economy.upgrades[Upgrade.watering.rawValue] = 2
oldFocus.sessions = [FocusSession(id:UUID(),title:"专注",kind:.stopwatch,date:epoch,seconds:35999)]
let oldLoaded = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(oldFocus)).validated()
check(oldLoaded.garden.coins == 321 && oldLoaded.garden.water == 19,"loading historical focus pays nothing")
finish(&oldFocus,1)
check(oldFocus.garden.coins == 323 && oldFocus.garden.water == 22,"only newly completed cumulative minute and dew block pay")
finish(&oldFocus,299)
finish(&oldFocus,600,kind:.rest)
check(oldFocus.garden.water == 22,"partial blocks and rest do not pay dew")
finish(&oldFocus,1)
check(oldFocus.garden.water == 25,"partial focus carries into a later dew reward")
for available in 0...4 {
    var fullWater=AppData()
    fullWater.garden.water=1_000_000_000-available
    fullWater.garden.economy.upgrades[Upgrade.watering.rawValue]=3
    fullWater.timer=TimerRun(kind:.stopwatch,target:300,taskTitle:"专注",startedAt:epoch,resumedAt:epoch)
    let result=fullWater.finishTimer(at:epoch.addingTimeInterval(300))
    check(result?.water == available && fullWater.garden.water == 1_000_000_000,"dew reward fits remaining storage")
    check(fullWater.totalFocus == 300 && fullWater.garden.coins == 10,"full dew storage preserves focus reward")
    _ = try fullWater.validated()
}

for ingredient in Ingredient.allCases {
    var data = AppData()
    data.garden.coins = ingredient.purchasePrice - 1
    let count = data.ingredientCount(ingredient)
    let waterPrice = EconomyBalance.ingredientWaterPrice(ingredient)
    data.garden.water = waterPrice - 1
    check(!data.buyIngredient(ingredient,withWater:true) && data.ingredientCount(ingredient) == count,"water purchase requires full quote")
    data.garden.water += 1
    check(data.buyIngredient(ingredient,withWater:true) && data.garden.water == 0 && data.ingredientCount(ingredient) == count + 1,"water price rounds copper cost upward")
    data.garden.ingredients[ingredient.rawValue] = count
    check(!data.buyIngredient(ingredient) && data.ingredientCount(ingredient) == count,"cannot buy below price")
    data.garden.coins += 1
    check(data.buyIngredient(ingredient) && data.garden.coins == 0 && data.ingredientCount(ingredient) == count + 1,"ingredient charges copper quote once")
}
check(EconomyBalance.seedPacketPrice(.carrot) == 4 && EconomyBalance.seedPacketPrice(.wheat) == 6 && EconomyBalance.seedPacketPrice(.mushroom) == 7 && EconomyBalance.seedPacketPrice(.pumpkin) == 8,"single seed copper prices")
check(EconomyBalance.seedWaterPrice(crop:.carrot) == 1 && EconomyBalance.seedWaterPrice(crop:.dirigiblePlum) == 2,"seed dew prices follow their copper tiers")
for crop in Crop.marketCrops {
    var data = AppData()
    let count = data.garden.cropSeeds[crop.rawValue,default:0]
    let price = EconomyBalance.seedPacketPrice(crop), seeds = data.garden.cropSeeds, water = data.garden.water
    data.garden.coins = price - 1
    check(!data.buySeeds(crop) && data.garden.coins == price - 1 && data.garden.cropSeeds == seeds && data.garden.water == water,"insufficient seed purchase leaves assets unchanged")
    data.garden.coins = price
    check(data.buySeeds(crop) && data.garden.coins == 0 && data.garden.cropSeeds[crop.rawValue] == count + 1 && data.garden.water == water,"exact copper balance buys one seed")
    check(!data.buySeeds(crop) && data.garden.coins == 0 && data.garden.cropSeeds[crop.rawValue] == count + 1,"empty balance cannot repeat seed purchase")
    data.garden.coins = price
    check(data.buySeeds(crop) && data.garden.coins == 0 && data.garden.cropSeeds[crop.rawValue] == count + 2,"each additional seed purchase adds one")
    let waterPrice = EconomyBalance.seedWaterPrice(crop:crop)
    data.garden.water = waterPrice - 1
    check(!data.exchangeSeed(crop) && data.garden.water == waterPrice - 1,"seed exchange requires the full dew quote")
    data.garden.water += 1
    check(data.exchangeSeed(crop) && data.garden.water == 0 && data.garden.cropSeeds[crop.rawValue] == count + 3,"quoted dew buys one seed")
    check(!data.exchangeSeed(crop),"zero water cannot buy seeds")
}
var recovery = AppData()
recovery.garden.ingredients = [:]
recovery.garden.cropSeeds = [:]
recovery.garden.water = 0
finish(&recovery,2 * 60)
check(recovery.garden.coins == 4 && recovery.buySeeds(.carrot) && recovery.garden.coins == 0 && recovery.garden.cropSeeds["胡萝卜"] == 1,"zero assets can recover by focus")

let fried = Dish.allCases.first { $0.id == "蛋炒饭" }!
var shop = AppData()
shop.garden.ingredients = [:]
shop.garden.coins = 14
check(shop.buyIngredient(.cookedRice) && shop.buyIngredient(.egg) && shop.garden.coins == 0,"fried rice purchased ingredients cost fourteen copper")
check(shop.salePrice(fried) == 23,"standard fried rice lists for twenty-three copper")
check(shop.cook(fried,natural:16),"cook purchased ingredients")
let cooked=shop.garden.economy.kitchenResult!.output!
check(shop.stock(cooked),"stock produced quality batch")
let frozen = shop.garden.orders[0]
check(frozen.price == 24 && !shop.stock(cooked),"one inventory unit can only be stocked once")
shop.garden.economy.upgrades[Upgrade.shop.rawValue] = 3
shop.garden.economy.upgrades[Upgrade.kitchen.rawValue] = 3
check(shop.garden.orders[0].price == 24,"existing order remains frozen after upgrades")
check(!shop.collectSale(frozen.id),"sale requires focus")
finish(&shop,300)
check(shop.collectSale(frozen.id) && shop.garden.coins == 34,"sale and focus income settle once")
check(!shop.collectSale(frozen.id) && shop.garden.coins == 34,"repeated collect cannot mint coins")

func ingredientCost(_ recipe: Dish) -> Int {
    recipe.ingredients.reduce(0) { $0 + Ingredient(rawValue:$1.key)!.purchasePrice * $1.value }
}
func saleProceeds(_ dish: Dish, in data: AppData) -> [Int] {
    (1...20).compactMap { face in
        var attempt = data
        attempt.garden.ingredients = dish.ingredients
        check(attempt.cook(dish,natural:face),"\(dish.name) accepts all twenty rolls")
        return attempt.garden.economy.kitchenResult?.output.map { attempt.salePrice($0) }
    }
}
for dish in Dish.allCases where dish.outputIngredient == nil {
    let cost = ingredientCost(dish)
    let fresh = saleProceeds(dish,in:AppData())
    check(fresh.count == 19 && fresh.first! < fresh.last!,"quality meaningfully changes sale proceeds and critical failures never sell")
    let freshHourlyMargin = Double(fresh.reduce(0,+) - 20 * cost) / 19 * 12
    check((50...100).contains(freshHourlyMargin),"\(dish.name) earns a bounded positive early margin after ingredient losses")
    var fullShop = AppData()
    fullShop.garden.economy.upgrades = [Upgrade.shop.rawValue:3,Upgrade.kitchen.rawValue:3,Upgrade.storefront.rawValue:2]
    fullShop.garden.crafts[dish.canonicalID] = 10
    let mature = saleProceeds(dish,in:fullShop)
    let matureHourlyMargin = Double(mature.reduce(0,+) - 20 * cost) / 19 * Double(fullShop.garden.capacity * 12)
    check((500...800).contains(matureHourlyMargin),"\(dish.name) earns a bounded margin with a full shop and maxed upgrades")
}
for recipe in Dish.allCases {
    guard let ingredient = recipe.outputIngredient else { continue }
    let processingCost = Double(ingredientCost(recipe) * 20) / 19
    let savings = Double(ingredient.purchasePrice) - processingCost
    check((1...2).contains(savings),"\(recipe.name) saves copper even with failed rolls and keeps prepared ingredients affordable")
}
var allTools = AppData()
allTools.garden.coins = 100_000
allTools.sessions = [FocusSession(id:UUID(),title:"专注",kind:.stopwatch,date:epoch,seconds:100_000)]
var totalUpgradeCost = 0
for upgrade in Upgrade.allCases {
    for rank in 0..<upgrade.limit {
        let price = upgrade.price(rank), before = allTools.garden.coins
        totalUpgradeCost += price
        check(allTools.upgrade(upgrade) && allTools.garden.coins == before - price,"upgrade copper charge")
    }
    let before = allTools.garden.coins
    check(!allTools.upgrade(upgrade) && allTools.garden.coins == before,"capped upgrades cannot charge")
}
check(100_000 - allTools.garden.coins == totalUpgradeCost,"all upgrades charge their displayed prices")

let legacyJSON = Data(#"{"id":"legacy-dish","name":"旧料理","category":"热菜","baseID":"soup","ingredients":{"胡萝卜":1},"sprite":5,"quality":65}"#.utf8)
let legacyDish = try JSONDecoder().decode(Dish.self,from:legacyJSON)
let legacyOrder = ShopOrder(dish:legacyDish,placedAt:0)
check(legacyOrder.price == 406 && AppData().salePrice(legacyDish) == 14,"unknown old recipe reprices new listings but old order retains silver basis")
let explicitOrder = ShopOrder(dish:fried,placedAt:0,proceeds:987)
check(explicitOrder.price == 987,"explicit old order proceeds preserved")
var assets = AppData()
assets.garden.coins = 123456
assets.garden.cropSeeds = ["南瓜":17]
assets.garden.ingredients = ["金纹鱼":23]
assets.garden.dishes = [fried.id:9]
assets.garden.recipes = [fried.id:fried]
assets.garden.economy.owned = ["travel","focusSuit"]
assets.garden.economy.upgrades = [Upgrade.storefront.rawValue:1]
assets.garden.economy.outfit = "travel"
assets.garden.order = explicitOrder
assets.garden.economy.extraOrders = [legacyOrder]
let restored = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(assets)).validated()
check(restored.garden.coins == 123456 && restored.garden.cropSeeds == assets.garden.cropSeeds && restored.garden.ingredients == assets.garden.ingredients && restored.garden.dishes == assets.garden.dishes,"balances and inventory preserved")
check(restored.garden.economy.owned == assets.garden.economy.owned && restored.garden.economy.outfit == "travel" && restored.garden.economy.upgrades == assets.garden.economy.upgrades,"ownership and upgrades preserved")
check(restored.garden.orders.map(\.price) == [987,406],"old orders round-trip with preserved proceeds")
for ingredient in [Ingredient.silverFish,.moonFish,.goldFish] {
    check(AppData().findPrice(ingredient.rawValue) < ingredient.purchasePrice,"find cash resale below ingredient purchase price")
}
var input = AppData()
input.keys = ["2030-01-01":9999]
check(input.typingReward == 0,"input threshold")
input.keys["2030-01-01"] = 10000
check(input.redeemTyping() && input.garden.coins == 1 && !input.redeemTyping(),"ten thousand inputs redeem one copper once")
print("PASS: \(checks) economy checks")
