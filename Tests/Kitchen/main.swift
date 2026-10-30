import Foundation

var selection=KitchenSelection()
assert(!selection.add(.milk,available:0))
assert(selection.add(.milk,available:2))
assert(selection.add(.milk,available:2))
assert(!selection.add(.milk,available:2))
let first=selection.portions[0]
selection.remove(first.id)
assert(selection.counts == ["牛奶":1])
assert(selection.add(.tea,available:1))
assert(selection.portions.last!.slot == first.slot)
for ingredient in [Ingredient.honey,.lemon,.mint,.cocoa] {assert(selection.add(ingredient,available:1))}
assert(selection.portions.count == 6 && !selection.add(.egg,available:1))
selection.clear()
assert(selection.counts.isEmpty)

let milkTea=["牛奶":1,"茶叶":1]
assert(!CookingIntent.drink.methods(ingredients:milkTea).contains(.fry))
assert(CookingIntent.dish.methods(ingredients:milkTea).isEmpty)
assert(CookingIntent.drink.develop(method:.brew,ingredients:milkTea)?.id == "奶茶")
assert(CookingIntent.drink.develop(method:.fry,ingredients:milkTea) == nil)
assert(CookingIntent.process.methods(ingredients:["茶叶":1]) == [.fry])
let roasted=CookingIntent.process.develop(method:.fry,ingredients:["茶叶":1])!
assert(roasted.isValid && roasted.outputIngredient == .roastedTea)
assert(CookingIntent.drink.methods(ingredients:["焙炒茶叶":1,"牛奶":1]).contains(.brew))
assert(CookingIntent.process.develop(method:.boil,ingredients:["大米":1])?.outputIngredient == .cookedRice)
assert(CookingIntent.process.develop(method:.mix,ingredients:["小麦":1,"鸡蛋":1])?.outputIngredient == .noodles)
assert(CookingIntent.dish.develop(method:.boil,ingredients:["大米":1])?.outputIngredient == nil)
assert(CookingIntent.dish.develop(method:.fry,ingredients:["米饭":1,"鸡蛋":1])?.id == "蛋炒饭")
assert(CookingIntent.dessert.develop(method:.boil,ingredients:["牛奶":1,"鸡蛋":1,"砂糖":1])?.id == "牛奶布丁")
assert(CookingIntent.dessert.methods(ingredients:["银鳞鱼":1]).isEmpty)
assert(CookingIntent.process.methods(ingredients:["砂糖":1]).isEmpty)
assert(CookingIntent.drink.methods(ingredients:["未知":1]).isEmpty)
assert(CookingIntent.drink.methods(ingredients:["牛奶":-1]).isEmpty)

for intent in CookingIntent.allCases {
    for ingredients in [["牛奶":1,"茶叶":1],["草莓":1,"牛奶":1],["番茄":1,"鸡蛋":1],["茶叶":1],["大米":1],["蛋糕胚":1,"草莓":1]] {
        for method in intent.methods(ingredients:ingredients) {
            let dish=intent.develop(method:method,ingredients:ingredients)!
            assert(dish.isValid && dish.price>0)
            assert(intent.develop(method:method,ingredients:ingredients,practice:4)!.quality >= dish.quality)
        }
    }
}
for known in Dish.allCases {
    let intent:CookingIntent=known.outputIngredient != nil ? .process : known.category == .drink ? .drink : known.category == .dessert ? .dessert:.dish
    assert(intent.develop(method:known.method,ingredients:known.ingredients)?.id == known.id)
}
var data=AppData()
data.garden.ingredients=["牛奶":2,"茶叶":1]
let tea=CookingIntent.drink.develop(method:.brew,ingredients:milkTea)!
assert(data.cook(tea))
assert(data.ingredientCount(.milk) == 1 && data.ingredientCount(.tea) == 0)
let afterCooking=data.garden.ingredients
assert(!data.cook(tea) && data.garden.ingredients == afterCooking)
data.garden.ingredients["茶叶"]=1
assert(data.cook(roasted) && data.ingredientCount(.tea) == 0 && data.ingredientCount(.roastedTea) == 1)
assert(data.garden.recipes[tea.id] != nil && data.garden.recipes[roasted.id] != nil)

let oldDish=Data(#"{"id":"legacy-dish","name":"旧料理","category":"热菜","baseID":"soup","ingredients":{"胡萝卜":1},"sprite":5,"quality":65,"sweetness":20,"aroma":30,"texture":40}"#.utf8)
let decoded=try JSONDecoder().decode(Dish.self,from:oldDish)
assert(decoded.isValid && decoded.quality == 65)
let encoded=try JSONEncoder().encode(decoded)
assert(!String(data:encoded,encoding:.utf8)!.contains("sweetness"))
let roundTrip=try JSONDecoder().decode(Dish.self,from:JSONEncoder().encode(roasted))
assert(roundTrip == roasted)

assert(IngredientDrop.height(age:0) == -100)
assert(IngredientDrop.height(age:0.17)>IngredientDrop.height(age:0))
assert(abs(IngredientDrop.height(age:0.34)) < 0.0001)
assert(IngredientDrop.height(age:0.42)<0)
assert(IngredientDrop.height(age:0.64) == 0 && IngredientDrop.height(age:10) == 0)

var garden=AppData()
let seedBefore=garden.garden.cropSeeds
let waterBefore=garden.garden.water
let emptyPlot=garden.garden.plots.first!.id
assert(!garden.plant(.carrot,in:UUID()) && garden.garden.cropSeeds == seedBefore && garden.garden.water == waterBefore)
assert(garden.plant(.carrot,in:emptyPlot))
assert(garden.garden.cropSeeds["胡萝卜"] == seedBefore["胡萝卜"]!-1 && garden.garden.water == waterBefore-1)
let plantedSeeds=garden.garden.cropSeeds
assert(!garden.plant(.carrot,in:emptyPlot) && garden.garden.cropSeeds == plantedSeeds)
garden.garden.water=0
assert(!garden.plant(.wheat,in:garden.garden.plots[1].id) && garden.garden.cropSeeds == plantedSeeds)
print("PASS: kitchen portions, stock limits, intent/method rules, processing outputs, old dishes, falling motion, and atomic planting")
