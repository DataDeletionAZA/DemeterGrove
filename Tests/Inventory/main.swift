import Foundation

var data=AppData()
data.garden.ingredients=[Ingredient.carrot.rawValue:3,Ingredient.milk.rawValue:2,Ingredient.cookedRice.rawValue:4,Ingredient.silverFish.rawValue:1]
data.garden.cropSeeds=[Crop.starlightCarrot.rawValue:2]
data.garden.economy.finds=[Ingredient.silverFish.rawValue:3,"月光草":5,"dew":2,"星砂":0]
data.garden.economy.owned=["travel","flowers"]
data.garden.water=7
data.garden.coins=123456
let soup=Dish.allCases.first{$0.id == "胡萝卜浓汤"}!
data.garden.dishes=[soup.id:2]
let snapshot=try JSONEncoder().encode(data)
let entries=data.inventory
assert(Set(entries.map(\.id)).count == entries.count)
assert(entries.first{$0.id == "ingredient:胡萝卜"}?.category == .crop)
assert(entries.first{$0.id == "ingredient:牛奶"}?.category == .ingredient)
assert(entries.first{$0.id == "ingredient:米饭"}?.category == .prepared)
assert(entries.first{$0.id == "ingredient:银鳞鱼"}?.count == 4)
assert(!entries.contains{$0.id == "find:银鳞鱼"})
assert(entries.first{$0.category == .seed}?.count == 2)
assert(entries.first{$0.category == .dish}?.count == 2)
assert(entries.first{$0.id == "find:月光草"}?.category == .material)
assert(entries.first{$0.id == "find:dew"}?.name == Potion.all.first{$0.id == "dew"}?.name)
assert(entries.first{$0.id == "water"}?.count == 7)
assert(data.inventory(category:.clothing,search:"").count == 2)
assert(entries.first{$0.id == "clothing:travel"}?.count == 1)
assert(!entries.contains{$0.count<=0})
assert(data.inventory(category:.all,search:" 胡萝卜 ").count == 3)
assert(data.inventory(category:.seed,search:"胡萝卜").count == 1)
assert(data.inventory(category:.material,search:"胡萝卜").isEmpty)
assert(data.inventory(category:.all,search:" ").count == entries.count)
let decoded=try JSONDecoder().decode(AppData.self,from:snapshot)
assert(decoded.inventory == entries)
assert(data.garden.coins == 123456 && data.garden.economy.finds["月光草"] == 5)

let coins=data.garden.coins,sales=data.garden.sales
assert(data.stock(soup))
let primary=data.garden.orders[0]
assert(data.garden.dishes[soup.id] == 1)
assert(data.unstock(primary.id))
assert(data.garden.orders.isEmpty && data.garden.dishes[soup.id] == 2)
assert(!data.unstock(primary.id) && data.garden.dishes[soup.id] == 2)
assert(data.garden.coins == coins && data.garden.sales == sales)
assert(data.stock(soup))
let pending=data.garden.orders[0]
data.garden.economy.extraOrders=[ShopOrder(dish:soup,placedAt:data.totalFocus,proceeds:123)]
let extra=data.garden.economy.extraOrders[0]
assert(data.unstock(extra.id))
assert(data.garden.orders.map(\.id) == [pending.id])
assert(data.garden.orders[0].price == pending.price)
assert(data.garden.dishes[soup.id] == 2)
data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:Date(),seconds:300)]
assert(!data.unstock(pending.id))
assert(data.garden.orders[0].id == pending.id && data.garden.dishes[soup.id] == 2)
assert(data.collectSale(pending.id))
assert(!data.unstock(pending.id))
assert(data.garden.coins == coins+pending.price && data.garden.sales == sales+1)
print("PASS: inventory categories/search/combined quantities/roundtrip and pending-only stock withdrawal with unchanged prices")
