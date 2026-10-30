import Foundation

for viewportWidth:CGFloat in [240,380,800,1500,2600] {
    let width=SceneSizing.canvasWidth(viewportWidth:viewportWidth)
    assert(width>0 && width<viewportWidth)
    assert(SceneSizing.canvasWidth(viewportWidth:viewportWidth,availableWidth:width-20)<=width-20)
    for viewportHeight:CGFloat in [240,420,680,1080] {
        let height=SceneSizing.height(width:width,viewportHeight:viewportHeight)
        let side=SceneSizing.sidebar(width:width)
        let area=CGSize(width:width-side-SceneSizing.gap,height:height)
        let fit=SceneSizing.fitted(in:area)
        assert(height<=max(120,viewportHeight-SceneSizing.verticalReserve) && height.isFinite)
        assert(fit.width<=area.width+0.001 && fit.height<=area.height+0.001)
        assert(abs(fit.width/fit.height-1.5)<0.0001)
        assert(abs(fit.height-height)<0.0001)
    }
}
assert(SceneSizing.sidebar(width:1500)>SceneSizing.sidebar(width:500))
assert(SceneNavigation.rooms == ["书房","农场","厨房","商店"])
assert(SceneNavigation.neighbors(of:"首页") == nil)
assert(SceneNavigation.neighbors(of:"其他") == nil)
assert(SceneNavigation.neighbors(of:"书房")!.0 == "商店")
assert(SceneNavigation.neighbors(of:"商店")!.1 == "书房")
for group in [SceneNavigation.rooms,SceneNavigation.wilds] {
    for scene in group {
        let (previous,next)=SceneNavigation.neighbors(of:scene)!
        assert(SceneNavigation.neighbors(of:previous)!.1 == scene)
        assert(SceneNavigation.neighbors(of:next)!.0 == scene)
    }
}

for potion in Potion.all {
    var data=AppData()
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:Date(),seconds:100000)]
    data.garden.ingredients=[potion.ingredient:2]
    data.garden.economy.finds=[potion.material:2]
    let ingredientStock=data.garden.ingredients,materialStock=data.garden.economy.finds
    var selection=PotionSelection()
    assert(!selection.add(potion.ingredient,kind:.ingredient,available:0))
    assert(selection.add(potion.ingredient,kind:.ingredient,available:2))
    assert(selection.add(potion.material,kind:.material,available:2))
    assert(selection.matches(potion))
    assert(!selection.add("其他",kind:.material,available:1))
    selection.remove(selection.portions.first!.id)
    assert(!selection.matches(potion))
    assert(selection.add(potion.ingredient,kind:.ingredient,available:2))
    assert(selection.portions.last!.slot == 0)
    selection.clear()
    assert(data.garden.ingredients == ingredientStock && data.garden.economy.finds == materialStock)
    assert(data.embark(.potions,recipe:potion.id))
    assert(data.garden.ingredients[potion.ingredient] == 1 && data.garden.economy.finds[potion.material] == 1)
    assert(!data.embark(.potions,recipe:potion.id))
    assert(data.garden.ingredients[potion.ingredient] == 1 && data.garden.economy.finds[potion.material] == 1)
    assert(data.collectJourney() == nil)
    data.sessions[0].seconds+=899
    assert(data.collectJourney() == nil)
    data.sessions[0].seconds+=1
    assert(data.collectJourney() != nil && data.garden.economy.finds[potion.id] == 1)
    assert(data.collectJourney() == nil && data.garden.economy.finds[potion.id] == 1)
}
var mismatch=PotionSelection()
assert(mismatch.add("薄荷",kind:.material,available:1))
assert(mismatch.add("月光草",kind:.ingredient,available:1))
assert(!mismatch.matches(Potion.all[0]))
print("PASS: scene bounds, reciprocal routes, potion staging/cancel, exact recipe matching, single stock deduction and focus-gated collection")
