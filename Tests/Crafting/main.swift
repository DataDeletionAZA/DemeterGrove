import Foundation

let soup=Dish.soup
func fixture(_ recipe:Dish)->AppData {
    var data=AppData();data.garden.ingredients=recipe.ingredients;return data
}
func roundTrip(_ data:AppData)throws->AppData {try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(data)).validated()}
func invalid(_ data:AppData) {do {_ = try data.validated();fatalError("invalid crafting save accepted")} catch {}}
for modifier in -6...6 {
    let rolls=(1...20).map{CraftRoll(natural:$0,modifier:modifier)}
    assert(rolls.allSatisfy(\.isValid))
    assert(rolls[0].criticalFailure && rolls[0].quality == 0 && !rolls[0].succeeded)
    assert(rolls[19].criticalSuccess && rolls[19].quality == 100 && rolls[19].succeeded)
    assert(zip(rolls,rolls.dropFirst()).allSatisfy{$0.quality <= $1.quality})
}
assert(!CraftRoll(natural:0,modifier:0).isValid && !CraftRoll(natural:21,modifier:0).isValid)
assert(!CraftRoll(natural:5,modifier:7).isValid)
var failed=fixture(soup)
let untouched=failed.garden.ingredients
for natural in [0,21,Int.min,Int.max] {assert(!failed.cook(soup,natural:natural) && failed.garden.ingredients == untouched)}
assert(failed.cook(soup,natural:1))
assert(failed.garden.ingredients.values.allSatisfy{$0 == 0})
assert(failed.garden.dishes.isEmpty && !failed.garden.isDiscovered(soup))
assert(failed.garden.economy.kitchenResult!.output == nil)
let failedReload=try roundTrip(failed)
assert(failedReload.garden.economy.kitchenResult == failed.garden.economy.kitchenResult)
assert(!failed.cook(soup,natural:20))

var batches=fixture(soup)
assert(batches.cook(soup,natural:2))
let rough=batches.garden.economy.kitchenResult!.output!
assert(rough.quality == 15 && rough.recipeID == soup.id && batches.garden.dishes[rough.id] == 1)
assert(batches.garden.ingredients.values.allSatisfy{$0 == 0} && batches.garden.isDiscovered(soup))
assert(batches.stock(rough))
let frozen=batches.garden.orders.first!
batches.garden.ingredients=soup.ingredients
assert(batches.cook(soup,natural:20))
let master=batches.garden.economy.kitchenResult!.output!
assert(master.quality == 100 && master.id != rough.id)
assert(batches.garden.recipes[rough.id]?.quality == 15 && batches.garden.recipes[master.id]?.quality == 100)
assert(batches.garden.orders.first!.id == frozen.id && batches.garden.orders.first!.dish == frozen.dish && batches.garden.orders.first!.price == frozen.price)
assert(batches.garden.recipeMenu.filter{$0.canonicalID == soup.id}.count == 1)
assert(batches.renameRecipe(soup.id,to:"晚餐浓汤"))
assert(batches.garden.recipes[rough.id]?.name == "晚餐浓汤" && batches.garden.recipes[master.id]?.name == "晚餐浓汤")
assert(batches.garden.orders.first!.id == frozen.id && batches.garden.orders.first!.dish == frozen.dish && batches.garden.orders.first!.price == frozen.price)
assert(batches.garden.economy.kitchenResult!.output!.name == "晚餐浓汤")
let saved=try roundTrip(batches)
for _ in 0..<3 {
    let again=try roundTrip(saved)
    assert(again.garden.economy.kitchenResult == saved.garden.economy.kitchenResult && again.garden.dishes == saved.garden.dishes)
}
var corrupt=saved
corrupt.garden.economy.kitchenResult!.output!.quality=35
invalid(corrupt)
corrupt=saved
corrupt.garden.recipes[master.id]!.ingredients=["未知":1]
invalid(corrupt)
corrupt=saved
corrupt.garden.recipes.removeValue(forKey:soup.id)
invalid(corrupt)

let odd=Dish.develop(method:.boil,category:.hot,ingredients:["蜂蜜":1,"鱼肉":1])!
let goodModifier=AppData().cookingModifier(soup),badModifier=AppData().cookingModifier(odd)
assert(goodModifier>badModifier)
let goodOdds=(1...20).filter{CraftRoll(natural:$0,modifier:goodModifier).succeeded}.count
let badOdds=(1...20).filter{CraftRoll(natural:$0,modifier:badModifier).succeeded}.count
assert(goodOdds>badOdds)
var lucky=fixture(odd)
assert(lucky.cook(odd,natural:20) && lucky.garden.economy.kitchenResult!.output!.quality == 100)
for recipe in Dish.allCases where recipe.outputIngredient != nil {
    var processed=fixture(recipe)
    assert(processed.cook(recipe,natural:2))
    assert(processed.garden.economy.kitchenResult!.output!.quality == 15)
    assert(processed.ingredientCount(recipe.outputIngredient!) == 1 && processed.garden.dishes.isEmpty)
    _ = try roundTrip(processed)
}
print("PASS: d20 boundaries, catastrophic loss, consumed ordinary failure, quality batches, frozen orders, recipe naming, result replay, invalid saves, material compatibility and intermediate production")

var mismatched=fixture(soup)
var changed=soup;changed.ingredients=["金纹鱼":6]
mismatched.garden.recipes[soup.id]=changed
let original=mismatched.garden.ingredients
assert(!mismatched.canCook(soup) && !mismatched.cook(soup,natural:20) && mismatched.garden.ingredients == original)
for (name,oldSprite,newSprite) in [("清蒸银鳞鱼",7,49),("柠檬月光鱼",8,50),("香煎金纹鱼",6,51)] {
    var dish=Dish.allCases.first{$0.id == name}!
    dish.sprite=oldSprite
    let decoded=try JSONDecoder().decode(Dish.self,from:JSONEncoder().encode(dish))
    assert(decoded.sprite == newSprite && decoded.ingredients == dish.ingredients && decoded.quality == dish.quality)
}
