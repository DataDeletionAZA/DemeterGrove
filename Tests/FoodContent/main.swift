import Foundation

let now=Date(timeIntervalSince1970:1_800_000_000)
assert(Crop.allCases.count == 25 && Crop.marketCrops.count == 24)
assert(FoodContent.recipes.count == 24 && Dish.allCases.count == 57)
assert(Set(Dish.allCases.map(\.id)).count == Dish.allCases.count)
assert(Set(FoodContent.recipes.map(\.sprite)).count == FoodContent.recipes.count)
assert(FoodContent.recipes.allSatisfy { FoodContent.spriteKeys[$0.sprite] != nil })
assert(FoodCategory.allCases.allSatisfy { category in FoodContent.recipes.contains{$0.category == category} })

for crop in Crop.allCases {
    assert(Ingredient(rawValue:crop.harvestName) != nil)
    assert(Dish.allCases.contains{$0.ingredients[crop.harvestName] != nil})
    assert(EconomyBalance.seedPacketPrice(crop)>0 && (600...1500).contains(crop.seconds))
    var data=AppData()
    data.garden.cropSeeds=[crop.rawValue:1];data.garden.water=1;data.garden.ingredients=[:]
    let id=data.garden.plots[0].id
    assert(data.plant(crop,in:id,at:now))
    assert(data.garden.plots[0].growthStage(0) == 0)
    assert(data.garden.plots[0].growthStage(crop.seconds*0.2) == 1)
    assert(data.garden.plots[0].growthStage(crop.seconds*0.6) == 2)
    assert(data.garden.plots[0].growthStage(crop.seconds) == 3)
    assert(!data.harvest(id,at:now))
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:crop.seconds)]
    assert(data.harvest(id,at:now))
    assert(data.garden.plots[0].crop == nil && data.garden.ingredients[crop.harvestName,default:0]>0)
    assert(data.garden.cropSeeds[crop.rawValue] == 0 && data.garden.water == 0)
    _ = try data.validated(at:now)
}

for recipe in Dish.allCases {
    assert(recipe.isValid,recipe.id)
    let intent:CookingIntent = recipe.outputIngredient != nil ? .process:recipe.category == .drink ? .drink:recipe.category == .dessert ? .dessert:.dish
    assert(intent.methods(ingredients:recipe.ingredients).contains(recipe.method),recipe.id)
    assert(intent.develop(method:recipe.method,ingredients:recipe.ingredients)?.id == recipe.id,recipe.id)
    var data=AppData()
    assert(!data.garden.isDiscovered(recipe))
    data.garden.ingredients=recipe.ingredients
    assert(data.cook(recipe,natural:12),recipe.id)
    assert(data.garden.isDiscovered(recipe))
    assert(data.garden.ingredients.filter{$0.value>0}.count == (recipe.outputIngredient == nil ? 0:1))
    if let output=recipe.outputIngredient { assert(data.ingredientCount(output) == 1) }
    _ = try data.validated(at:now)
    let roundTrip=try JSONDecoder().decode(AppData.self,from:JSONEncoder().encode(data))
    assert(roundTrip.garden.isDiscovered(recipe))
}

for name in FoodContent.processedSprites.keys {
    assert(Dish.allCases.contains{$0.outputIngredient?.rawValue == name})
    assert(Dish.allCases.contains{$0.outputIngredient == nil && $0.ingredients[name] != nil})
}

let loreKeys = Crop.allCases.map{"crop:"+$0.rawValue} + Ingredient.allCases.map{"ingredient:"+$0.rawValue} +
    Dish.allCases.map{"dish:"+$0.id} + NatureCatalog.fish.map{"fish:"+$0.id} + NatureCatalog.baits.map{"bait:"+$0.id} +
    NatureCatalog.ranchSpecies.map{"animal:"+$0.id} + NatureCatalog.ranchSpecies.map{"product:"+$0.productID} +
    NatureCatalog.forage.map{"forage:"+$0.id} + NatureCatalog.wildlife.map{"wildlife:"+$0.id} +
    Mineral.all.map{"mineral:"+$0.id} + CraftedGear.all.map{"gear:"+$0.id} + FishingRod.all.map{"rod:"+$0.id} +
    Potion.all.map{"potion:"+$0.id} + Companion.all.map{"companion:"+$0.id} + Cosmetic.all.map{"clothing:"+$0.id} +
    ["water","feed:feed_bag","fishing:waterweed","fishing:driftwood","fishing:shell","fishing:river_pebble"]
for key in loreKeys {
    guard let text=ItemLore.text(for:key) else { fatalError("Missing item lore: "+key) }
    assert((5...120).contains(text.count),key)
}
assert(ItemLore.text(for:"fish:unknown") == nil)
assert(ItemLore.text(for:"ingredient:unknown") == nil)
assert(ItemLore.text(for:"seed:苹果") == ItemLore.text(for:"crop:苹果"))
assert(ItemLore.text(for:"mining:quartz") == ItemLore.text(for:"mineral:quartz"))

let resources=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Game/Nature")
for (crop,key) in FoodContent.cropSpriteKeys {
    var images=Set<Data>()
    for stage in 0...4 {
        let image=try Data(contentsOf:resources.appendingPathComponent("crop_\(key)_\(stage).png"))
        assert(image.starts(with:[137,80,78,71,13,10,26,10]),crop.rawValue)
        images.insert(image)
    }
    assert(images.count == 5,crop.rawValue)
}
for key in FoodContent.spriteKeys.values {
    let image=try Data(contentsOf:resources.appendingPathComponent(key+".png"))
    assert(image.starts(with:[137,80,78,71,13,10,26,10]))
}
print("PASS: 25 crop growth/harvest paths, 57 reachable recipes, processing chains, discovery/save round trips, complete item lore, and 87 distinct sprite assets")
