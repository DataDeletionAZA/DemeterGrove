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
    var data = AppData()
    finish(&data,Double(minutes * 60))
    check(data.garden.coins == minutes * 2,"whole focus pays per minute")
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
oldFocus.sessions = [FocusSession(id:UUID(),title:"专注",kind:.stopwatch,date:epoch,seconds:36059)]
let oldLoaded = try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(oldFocus)).validated()
check(oldLoaded.garden.coins == 321,"loading historical focus pays nothing")
finish(&oldFocus,1)
check(oldFocus.garden.coins == 323,"only newly completed cumulative minute pays")

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
for crop in Crop.marketCrops {
    var data = AppData()
    let count = data.garden.cropSeeds[crop.rawValue,default:0]
    data.garden.coins = EconomyBalance.seedPacketPrice(crop)
    check(data.buySeeds(crop) && data.garden.coins == 0 && data.garden.cropSeeds[crop.rawValue] == count + 3,"seed packet price and quantity")
    data.garden.water = 1
    check(data.exchangeSeed(crop) && data.garden.water == 0 && data.garden.cropSeeds[crop.rawValue] == count + 4,"one water buys one seed")
    check(!data.exchangeSeed(crop),"zero water cannot buy seeds")
}
var recovery = AppData()
recovery.garden.ingredients = [:]
recovery.garden.cropSeeds = [:]
recovery.garden.water = 0
finish(&recovery,9 * 60)
check(recovery.garden.coins == 18 && recovery.buySeeds(.carrot),"zero assets can recover by focus")

let fried = Dish.allCases.first { $0.id == "蛋炒饭" }!
var shop = AppData()
shop.garden.ingredients = [:]
shop.garden.coins = 14
check(shop.buyIngredient(.cookedRice) && shop.buyIngredient(.egg) && shop.garden.coins == 0,"fried rice purchased ingredients cost fourteen copper")
check(shop.salePrice(fried) == 27,"ordinary fried rice sale is twenty-seven copper")
check(shop.cook(fried) && shop.stock(fried),"cook and stock purchased ingredients")
let frozen = shop.garden.orders[0]
check(frozen.price == 27 && !shop.stock(fried),"one inventory unit can only be stocked once")
shop.garden.economy.upgrades[Upgrade.shop.rawValue] = 3
shop.garden.economy.upgrades[Upgrade.kitchen.rawValue] = 3
check(shop.garden.orders[0].price == 27,"existing order remains frozen after upgrades")
check(!shop.collectSale(frozen.id),"sale requires focus")
finish(&shop,300)
check(shop.collectSale(frozen.id) && shop.garden.coins == 37,"sale and focus income settle once")
check(!shop.collectSale(frozen.id) && shop.garden.coins == 37,"repeated collect cannot mint coins")
for dish in Dish.allCases where dish.outputIngredient == nil {
    let cost = dish.ingredients.reduce(0) { $0 + Ingredient(rawValue:$1.key)!.purchasePrice * $1.value }
    let price = AppData().salePrice(dish)
    check(price > cost && (9...18).contains(price - cost),"built-in bought ingredients have bounded positive margin")
}
var allTools = AppData()
allTools.garden.coins = 100_000
allTools.sessions = [FocusSession(id:UUID(),title:"专注",kind:.stopwatch,date:epoch,seconds:100_000)]
for upgrade in Upgrade.allCases {
    for rank in 0..<upgrade.limit {
        let price = upgrade.price(rank), before = allTools.garden.coins
        check(allTools.upgrade(upgrade) && allTools.garden.coins == before - price,"upgrade copper charge")
    }
    let before = allTools.garden.coins
    check(!allTools.upgrade(upgrade) && allTools.garden.coins == before,"capped upgrades cannot charge")
}
check(100_000 - allTools.garden.coins == 9600,"all upgrades cost nine thousand six hundred copper")

let legacyJSON = Data(#"{"id":"legacy-dish","name":"旧料理","category":"热菜","baseID":"soup","ingredients":{"胡萝卜":1},"sprite":5,"quality":65}"#.utf8)
let legacyDish = try JSONDecoder().decode(Dish.self,from:legacyJSON)
let legacyOrder = ShopOrder(dish:legacyDish,placedAt:0)
check(legacyOrder.price == 406 && AppData().salePrice(legacyDish) == 17,"unknown old recipe reprices new listings but old order retains silver basis")
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
