import Foundation

let now = Date()
let soup = Dish.soup
let cake = Dish.allCases.first { $0.outputIngredient == nil && $0.id != soup.id }!
func fixture(_ count: Int = 20, slots: Int = 1) -> AppData {
    var data = AppData()
    data.garden.dishes = [soup.id: count]
    data.garden.economy.upgrades[Upgrade.storefront.rawValue] = (slots - 1) / 2
    return data
}
func focus(_ value: Double, in data: inout AppData) {
    data.sessions = value == 0 ? [] : [FocusSession(id: UUID(), title: "阅读", kind: .stopwatch, date: now, seconds: value)]
}
func quantity(_ data: AppData) -> Int {
    data.garden.dishes.values.reduce(0, +) + data.garden.orders.count + data.garden.sales
}
func money(_ data: AppData) -> Int { data.garden.coins + data.garden.autoShopState.receivables }

var basic = fixture()
assert(basic.toggleAutoShopDish(soup.id, at: now))
assert(basic.setAutoShop(enabled: true, at: now))
let price = basic.garden.orders[0].price
assert(basic.garden.orders[0].placedAt == 0 && basic.garden.dishes[soup.id] == 19)
assert(basic.garden.coins == 0)
assert(basic.advanceAutoShop(to: 299))
assert(basic.garden.sales == 0 && basic.garden.autoShopState.receivables == 0)
focus(300, in: &basic)
assert(basic.advanceAutoShop(to: 300))
assert(basic.garden.sales == 1 && basic.garden.autoShopState.receivables == price)
assert(basic.garden.autoShopState.receipts.count == 1 && basic.garden.autoShopState.receipts[0].amount == price)
assert(basic.garden.autoShopState.receipts[0].name == soup.name && basic.garden.autoShopState.receipts[0].count == 1)
assert(basic.garden.orders[0].placedAt == 300 && basic.garden.dishes[soup.id] == 18)
assert(quantity(basic) == 20)
assert(basic.collectShopProceeds(at: now) == price)
assert(basic.collectShopProceeds(at: now) == 0 && basic.garden.coins == price)
assert(basic.garden.autoShopState.receipts.isEmpty)
assert(quantity(basic) == 20)

var paused = fixture()
paused.timer = TimerRun(kind: .stopwatch, target: 1800, taskTitle: "阅读", startedAt: now, resumedAt: now)
assert(paused.toggleAutoShopDish(soup.id, at: now))
assert(paused.setAutoShop(enabled: true, at: now))
paused.timer?.pause(at: now.addingTimeInterval(180))
paused.advanceAutoShop(to: paused.gameFocus(at: now.addingTimeInterval(10000)))
assert(paused.garden.sales == 0 && paused.garden.orders[0].placedAt == 0)
paused.timer = TimerRun(kind: .rest, target: 1200, taskTitle: "休息", startedAt: now, resumedAt: now)
paused.advanceAutoShop(to: paused.gameFocus(at: now.addingTimeInterval(10000)))
assert(paused.garden.sales == 0)

var disabled = fixture(2)
assert(disabled.stock(soup, at: now))
disabled.advanceAutoShop(to: 0)
focus(300, in: &disabled)
disabled.advanceAutoShop(to: 300)
assert(disabled.garden.orders.isEmpty && disabled.garden.dishes[soup.id] == 1)
assert(disabled.garden.autoShopState.receivables == disabled.salePrice(soup))
assert(disabled.garden.sales == 1 && !disabled.garden.autoShopState.enabled)

var legacy = fixture(4)
legacy.garden.order = ShopOrder(dish: soup, placedAt: 0, proceeds: 1234)
focus(900, in: &legacy)
legacy.advanceAutoShop(to: 900)
assert(legacy.garden.orders.isEmpty && legacy.garden.autoShopState.receivables == 1234)
assert(legacy.setAutoShop(enabled: true, at: now))
assert(legacy.toggleAutoShopDish(soup.id, at: now))
assert(legacy.garden.orders[0].placedAt == 900 && legacy.garden.sales == 1)
assert(!legacy.advanceAutoShop(to: 900))
assert(legacy.collectShopProceeds(at: now) == 1234)
assert(legacy.collectShopProceeds(at: now) == 0)

var priority = fixture(2, slots: 3)
priority.garden.dishes[cake.id] = 4
assert(priority.toggleAutoShopDish(cake.id, at: now))
assert(priority.toggleAutoShopDish(soup.id, at: now))
assert(!priority.toggleAutoShopDish("不存在的料理", at: now))
assert(priority.setAutoShop(enabled: true, at: now))
assert(priority.garden.orders.allSatisfy { $0.dish.id == cake.id })
focus(300, in: &priority)
priority.advanceAutoShop(to: 300)
assert(priority.garden.orders.map(\.dish.id) == [cake.id, soup.id, soup.id])
assert(priority.garden.dishes.values.reduce(0,+) == 0 && quantity(priority) == 6)
let selectedOrder = priority.garden.orders.first { $0.dish.id == soup.id }!
assert(priority.stopRestockingAndUnstock(selectedOrder.id, at: now))
assert(!priority.garden.autoShopState.dishIDs.contains(soup.id))
assert(priority.garden.dishes[soup.id] == 1)
priority.advanceAutoShop(to: 300)
assert(priority.garden.orders.count == 2)

// Compare a long jump with frequent updates, including staggered shelf deadlines and mixed frozen prices.
var jump = fixture(200_000, slots: 5)
jump.garden.dishes[cake.id] = 123
jump.garden.economy.autoShop = AutoShopState(enabled: true, dishIDs: [cake.id, soup.id], lastAdvancedFocus: 0)
jump.garden.dishes[soup.id, default: 0] -= 3
jump.garden.order = ShopOrder(dish: soup, placedAt: 0, proceeds: 91)
jump.garden.economy.extraOrders = [ShopOrder(dish: soup, placedAt: 60, proceeds: 92), ShopOrder(dish: soup, placedAt: 180, proceeds: 93)]
jump.advanceAutoShop(to: 180)
var stepped = jump
let count = quantity(jump)
jump.advanceAutoShop(to: 1_000_000)
for time in stride(from: 181, through: 1_000_000, by: 113) { stepped.advanceAutoShop(to: Double(time)) }
stepped.advanceAutoShop(to: 1_000_000)
assert(jump.garden.sales == stepped.garden.sales)
assert(jump.garden.autoShopState.receivables == stepped.garden.autoShopState.receivables)
assert(jump.garden.dishes == stepped.garden.dishes)
assert(jump.garden.orders.map(\.placedAt).sorted() == stepped.garden.orders.map(\.placedAt).sorted())
assert(jump.garden.autoShopState.receipts.reduce(0,{$0+$1.amount}) == jump.garden.autoShopState.receivables)
assert(jump.garden.autoShopState.receipts.reduce(0,{$0+$1.count}) == jump.garden.autoShopState.soldCount)
assert(quantity(jump) == count && quantity(stepped) == count)

var huge = fixture(1_000_000_000, slots: 5)
assert(huge.toggleAutoShopDish(soup.id, at: now))
assert(huge.setAutoShop(enabled: true, at: now))
huge.advanceAutoShop(to: 300_000_000)
assert(huge.garden.sales == 5_000_000 && quantity(huge) == 1_000_000_000)
assert(huge.garden.autoShopState.receivables == 5_000_000 * huge.salePrice(soup))

var frozen = fixture(1)
assert(frozen.stock(soup, at: now))
let frozenPrice = frozen.garden.orders[0].price
frozen.advanceAutoShop(to: 0)
frozen.garden.economy.upgrades[Upgrade.shop.rawValue] = 3
focus(300, in: &frozen)
frozen.advanceAutoShop(to: 300)
assert(frozen.collectShopProceeds(at: now) == frozenPrice)
assert(frozen.garden.coins == frozenPrice)

var fresh = fixture(1)
assert(fresh.toggleAutoShopDish(soup.id, at: now))
assert(fresh.setAutoShop(enabled: true, at: now))
fresh.advanceAutoShop(to: 900)
assert(fresh.garden.orders.isEmpty && fresh.garden.sales == 1)
fresh.advanceAutoShop(to: 1200)
fresh.garden.dishes[soup.id] = 1
fresh.advanceAutoShop(to: 1200)
assert(fresh.garden.orders[0].placedAt == 1200 && fresh.garden.sales == 1)
fresh.advanceAutoShop(to: 1499)
assert(fresh.garden.sales == 1)
fresh.advanceAutoShop(to: 1500)
assert(fresh.garden.sales == 2 && fresh.garden.orders.isEmpty)

var capped = fixture(1)
assert(capped.stock(soup, at: now))
capped.garden.economy.autoShop = AutoShopState(receivables: AutoShopState.moneyLimit - 1, soldCount: 1, lastAdvancedFocus: 0)
capped.advanceAutoShop(to: 300)
assert(capped.garden.orders.count == 1 && capped.garden.sales == 0)
assert(capped.garden.autoShopState.receivables == AutoShopState.moneyLimit - 1)
capped.garden.coins = AutoShopState.moneyLimit
focus(300, in: &capped)
assert(capped.collectShopProceeds(at: now) == 0 && capped.garden.orders.count == 1)
capped.garden.coins = 0
assert(capped.collectShopProceeds(at: now) == AutoShopState.moneyLimit - 1)
capped.advanceAutoShop(to: 300)
assert(capped.garden.orders.isEmpty && capped.garden.sales == 1)

var noRaw = AppData()
noRaw.garden.ingredients[soup.ingredients.keys.first!, default: 0] = 100
let raw = noRaw.garden.ingredients
assert(!noRaw.toggleAutoShopDish(soup.id, at: now))
assert(noRaw.setAutoShop(enabled: true, at: now))
noRaw.advanceAutoShop(to: 100_000)
assert(noRaw.garden.orders.isEmpty && noRaw.garden.ingredients == raw && noRaw.garden.coins == 0)

let encoded = try JSONEncoder().encode(basic)
let decoded = try JSONDecoder().decode(AppData.self, from: encoded)
assert(decoded.garden.autoShopState == basic.garden.autoShopState)
assert(decoded.garden.autoShopState.isValid(in: decoded.garden, focus: decoded.gameFocus(at: now)))
var oldObject = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
var oldGarden = oldObject["garden"] as! [String: Any]
var oldEconomy = oldGarden["economy"] as! [String: Any]
oldEconomy.removeValue(forKey: "autoShop")
oldGarden["economy"] = oldEconomy
oldObject["garden"] = oldGarden
let oldData = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: oldObject))
assert(oldData.garden.economy.autoShop == nil && !oldData.garden.autoShopState.enabled)
var invalid = decoded.garden.autoShopState
invalid.dishIDs.append(soup.id)
assert(!invalid.isValid(in: decoded.garden, focus: 300))
invalid = decoded.garden.autoShopState
invalid.receivables = -1
assert(!invalid.isValid(in: decoded.garden, focus: 300))
print("PASS: automatic shop timing, pauses/rest, old orders, priorities, unstock, frozen proceeds, large batches and conservation")

var batches=fixture(0)
var lowBatch=soup,highBatch=soup
lowBatch.recipeID=soup.id;lowBatch.quality=35;lowBatch.id=Dish.batchID(recipeID:soup.id,quality:35)
highBatch.recipeID=soup.id;highBatch.quality=95;highBatch.id=Dish.batchID(recipeID:soup.id,quality:95)
batches.garden.recipes[soup.id]=soup
batches.garden.recipes[lowBatch.id]=lowBatch;batches.garden.recipes[highBatch.id]=highBatch
batches.garden.dishes=[lowBatch.id:2,highBatch.id:3]
assert(batches.toggleAutoShopDish(highBatch.id,at:now))
assert(batches.garden.autoShopState.dishIDs == [soup.id])
assert(batches.setAutoShop(enabled:true,at:now))
assert(batches.garden.orders[0].dish.id == lowBatch.id)
focus(300,in:&batches);batches.advanceAutoShop(to:300)
assert(batches.garden.orders[0].dish.id == lowBatch.id)
focus(600,in:&batches);batches.advanceAutoShop(to:600)
assert(batches.garden.orders[0].dish.id == highBatch.id)
assert(batches.garden.orders[0].price == batches.salePrice(highBatch))
assert(batches.stopRestockingAndUnstock(batches.garden.orders[0].id,at:now))
assert(batches.garden.autoShopState.dishIDs.isEmpty && batches.garden.dishes[highBatch.id] == 3)
var oldBatchSetting=fixture(0)
oldBatchSetting.garden.recipes[soup.id]=soup
oldBatchSetting.garden.recipes[lowBatch.id]=lowBatch;oldBatchSetting.garden.recipes[highBatch.id]=highBatch
oldBatchSetting.garden.dishes=[highBatch.id:1]
oldBatchSetting.garden.economy.autoShop=AutoShopState(enabled:true,dishIDs:[lowBatch.id,highBatch.id])
oldBatchSetting.advanceAutoShop(to:0)
assert(oldBatchSetting.garden.autoShopState.dishIDs == [soup.id])
assert(oldBatchSetting.garden.orders.first?.dish.id == highBatch.id)
_ = try oldBatchSetting.validated(at:now)

var mixed=fixture(50,slots:3)
mixed.garden.economy.expedition=ExpeditionState(gear:["copper_sickle":1])
assert(mixed.stockEquipment("copper_sickle",at:now))
assert(mixed.toggleAutoShopDish(soup.id,at:now))
assert(mixed.setAutoShop(enabled:true,at:now))
assert(mixed.garden.shopOrderCount == 3)
var mixedSteps=mixed
mixed.advanceAutoShop(to:3000)
for time in stride(from:1,through:3000,by:59) {mixedSteps.advanceAutoShop(to:Double(time))}
mixedSteps.advanceAutoShop(to:3000)
assert(mixed.garden.autoShopState.receivables == mixedSteps.garden.autoShopState.receivables)
assert(mixed.garden.autoShopState.soldCount == mixedSteps.garden.autoShopState.soldCount)
assert(mixed.garden.dishes == mixedSteps.garden.dishes)
assert(mixed.garden.orders.map(\.placedAt) == mixedSteps.garden.orders.map(\.placedAt))
print("PASS: recipe restocking across quality batches, deterministic quality order, legacy batch setting migration, mixed equipment/dish timing and frozen quality prices")
