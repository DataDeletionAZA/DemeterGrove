import Foundation

let now=Date()
func fixture(_ potion:Potion)->AppData {
    var data=AppData()
    let seconds=Double((1..<8).reduce(0){$0+LevelProgress.requirement($1)}*60)
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:seconds)]
    data.garden.ingredients=[potion.ingredient:10]
    return data
}
func finish(_ data:inout AppData,_ potion:Potion) {
    data.sessions.append(FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:now,seconds:900))
    precondition(data.collectJourney(.potions,at:now) != nil)
    precondition(data.collectJourney(.potions,at:now) == nil)
}
func encoded<T:Encodable>(_ value:T)throws->Data {
    let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
    return try encoder.encode(value)
}

for potion in Potion.all {
    let forageID=potion.forageID!
    var selection=PotionSelection()
    assert(selection.add(forageID,kind:.material,available:1))
    assert(!selection.add(potion.material,kind:.material,available:1))
    assert(selection.count(potion.material,kind:.material) == 1 && selection.count(forageID,kind:.material) == 1)
    assert(selection.add(potion.ingredient,kind:.ingredient,available:1) && selection.matches(potion))

    var legacy=fixture(potion)
    legacy.garden.economy.finds[potion.material]=1
    assert(legacy.potionMaterialCount(potion.material) == 1)
    assert(legacy.embark(.potions,recipe:potion.id,at:now))
    assert(legacy.garden.ingredients[potion.ingredient] == 9 && legacy.garden.economy.finds[potion.material] == 0)
    assert(legacy.garden.economy.expedition == nil)
    finish(&legacy,potion)
    assert(legacy.garden.economy.finds[potion.id] == 1)

    var modern=fixture(potion)
    modern.garden.economy.expedition=ExpeditionState(inventory:[forageID:1])
    assert(modern.potionMaterialNames == [potion.material])
    assert(modern.embark(.potions,recipe:potion.id,at:now))
    assert(modern.expeditionState.inventory[forageID] == 0 && modern.garden.ingredients[potion.ingredient] == 9)
    assert(modern.garden.economy.finds[potion.material] == nil && modern.garden.economy.finds[forageID] == nil)
    assert(!modern.embark(.potions,recipe:potion.id,at:now))
    assert(modern.expeditionState.inventory[forageID] == 0 && modern.garden.ingredients[potion.ingredient] == 9)
    finish(&modern,potion)
    assert(modern.garden.economy.finds[potion.id] == 1)
    assert(!modern.sellForage(forageID,count:1))
    _ = try modern.validated(at:now)

    var mixed=fixture(potion)
    mixed.garden.economy.finds[potion.material]=2
    mixed.garden.economy.finds[forageID]=1
    mixed.garden.economy.expedition=ExpeditionState(inventory:[forageID:3])
    assert(mixed.potionMaterialCount(potion.material) == 6 && mixed.potionMaterialCount(forageID) == 6)
    assert(mixed.potionMaterialNames == [potion.material])
    for index in 0..<6 {
        assert(mixed.embark(.potions,recipe:potion.id,at:now))
        assert(mixed.potionMaterialCount(potion.material) == 5-index)
        if index == 0 {assert(mixed.garden.economy.finds[potion.material] == 1 && mixed.expeditionState.inventory[forageID] == 3)}
        if index == 2 {assert(mixed.garden.economy.finds[forageID] == 0 && mixed.expeditionState.inventory[forageID] == 3)}
        finish(&mixed,potion)
    }
    assert(mixed.garden.economy.finds[potion.id] == 6 && mixed.garden.ingredients[potion.ingredient] == 4)
    assert(!mixed.embark(.potions,recipe:potion.id,at:now))
    assert(mixed.expeditionState.inventory[forageID] == 0)
    _ = try mixed.validated(at:now)

    var missing=fixture(potion)
    missing.garden.ingredients[potion.ingredient]=0
    missing.garden.economy.expedition=ExpeditionState(inventory:[forageID:1])
    let before=try encoded(missing)
    assert(!missing.embark(.potions,recipe:potion.id,at:now))
    let after=try encoded(missing)
    assert(before == after)
    missing.garden.ingredients[potion.ingredient]=1
    assert(missing.sellForage(forageID,count:1))
    assert(!missing.embark(.potions,recipe:potion.id,at:now))
    assert(missing.garden.ingredients[potion.ingredient] == 1)
}

let bloom=Potion.all.first{$0.id == "bloom"}!
var processing=fixture(bloom)
processing.garden.ingredients[bloom.ingredient]=0
processing.garden.economy.expedition=ExpeditionState(inventory:["wild_strawberry":1,"star_sand":1,"bilberry":1])
assert(processing.prepareForage("wild_strawberry",count:1))
assert(processing.expeditionState.inventory["wild_strawberry"] == 0 && processing.garden.ingredients["草莓"] == 1)
assert(!processing.prepareForage("wild_strawberry",count:1))
assert(!processing.prepareForage("star_sand",count:1))
assert(processing.expeditionState.inventory["bilberry"] == 1)
assert(processing.embark(.potions,recipe:bloom.id,at:now))
assert(processing.garden.ingredients["草莓"] == 0 && processing.expeditionState.inventory["star_sand"] == 0)
finish(&processing,bloom)
assert(processing.garden.economy.finds[bloom.id] == 1)
let coins=processing.garden.coins
let bilberry=NatureCatalog.forage.first{$0.id == "bilberry"}!
assert(processing.sellForage(bilberry.id,count:1))
assert(processing.expeditionState.inventory[bilberry.id] == 0 && processing.garden.coins == coins+bilberry.salePrice)
assert(!processing.sellForage(bilberry.id,count:1) && !processing.prepareForage(bilberry.id,count:1))
_ = try processing.validated(at:now)
print("PASS: all potion recipes share legacy and expedition materials, consume exactly one source, preserve failed actions, and never duplicate processed/sold/brewed items")
