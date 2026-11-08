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
assert(SceneNavigation.rooms == ["书房","农场","厨房","商店","炼金室"])
assert(SceneNavigation.neighbors(of:"首页") == nil)
assert(SceneNavigation.neighbors(of:"其他") == nil)
assert(SceneNavigation.neighbors(of:"书房")!.0 == "炼金室")
assert(SceneNavigation.neighbors(of:"商店")!.1 == "炼金室")
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
    assert(data.collectJourney(.potions) == nil)
    data.sessions[0].seconds+=899
    assert(data.collectJourney(.potions) == nil)
    data.sessions[0].seconds+=1
    assert(data.collectJourney(.potions) != nil && data.garden.economy.finds[potion.id] == 1)
    assert(data.collectJourney(.potions) == nil && data.garden.economy.finds[potion.id] == 1)
}
let journeyDate=Date(timeIntervalSince1970:1_800_000_000)
func journeyFixture() -> AppData {
    var data=AppData()
    data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:journeyDate,seconds:100000)]
    data.garden.ingredients["薄荷"]=2
    data.garden.economy.finds["月光草"]=2
    return data
}
for order:[JourneyKind] in [[.fishing,.adventure,.potions],[.potions,.adventure,.fishing]] {
    var data=journeyFixture()
    for kind in order { assert(data.embark(kind,recipe:kind == .potions ? "dew":nil,at:journeyDate)) }
    assert(data.garden.economy.activeJourneys.count == 3)
    let original=data.garden.economy.activeJourneys
    let ingredients=data.garden.ingredients,finds=data.garden.economy.finds
    for kind in order { assert(!data.embark(kind,recipe:kind == .potions ? "dew":nil,at:journeyDate)) }
    assert(data.garden.ingredients == ingredients && data.garden.economy.finds == finds)
    assert(data.collectJourney(.fishing,at:journeyDate) == nil)
    data.sessions[0].seconds+=900
    assert(!data.embark(.fishing,at:journeyDate) && !data.embark(.potions,recipe:"dew",at:journeyDate))
    assert(data.collectJourney(.fishing,at:journeyDate) != nil)
    assert(data.collectJourney(.fishing,at:journeyDate) == nil)
    assert(data.garden.economy.trip(.adventure)?.startedAt == original.first{$0.kind == .adventure}?.startedAt)
    assert(data.collectJourney(.adventure,at:journeyDate) == nil)
    assert(!data.embark(.adventure,at:journeyDate))
    assert(data.collectJourney(.potions,at:journeyDate) != nil && data.collectJourney(.potions,at:journeyDate) == nil)
    assert(data.garden.economy.finds["dew"] == 1 && data.garden.economy.expeditions == 2)
    assert(data.embark(.fishing,at:journeyDate))
    data.sessions[0].seconds+=300
    assert(data.collectJourney(.adventure,at:journeyDate) != nil && data.collectJourney(.adventure,at:journeyDate) == nil)
    assert(data.garden.economy.activeJourneys.count == 1 && data.garden.economy.trip(.fishing)?.progress(data.totalFocus) == 1.0/3)
    _ = try data.validated(at:journeyDate)
}
var liveJourney=journeyFixture()
liveJourney.timer=TimerRun(kind:.stopwatch,target:1,taskTitle:"阅读",startedAt:journeyDate,resumedAt:journeyDate)
let embarkDate=journeyDate.addingTimeInterval(125.25)
assert(liveJourney.embark(.fishing,at:embarkDate) && liveJourney.embark(.adventure,at:embarkDate))
assert(liveJourney.garden.economy.trip(.fishing)?.startedAt == 100125.25)
let collectionDate=embarkDate.addingTimeInterval(900)
assert(liveJourney.collectJourney(.fishing,at:collectionDate.addingTimeInterval(-0.25)) == nil)
assert(liveJourney.collectJourney(.fishing,at:collectionDate) != nil && liveJourney.collectJourney(.fishing,at:collectionDate) == nil)
let adventureProgress=liveJourney.garden.economy.trip(.adventure)!.progress(liveJourney.gameFocus(at:collectionDate))
liveJourney.timer!.pause(at:collectionDate)
assert(liveJourney.garden.economy.trip(.adventure)?.progress(liveJourney.gameFocus(at:collectionDate.addingTimeInterval(500))) == adventureProgress)
_ = liveJourney.finishTimer(at:collectionDate.addingTimeInterval(500))
assert(liveJourney.garden.economy.trip(.adventure)?.progress(liveJourney.totalFocus) == adventureProgress)
liveJourney.timer=TimerRun(kind:.rest,target:300,taskTitle:"休息",startedAt:collectionDate,resumedAt:collectionDate)
assert(liveJourney.collectJourney(.adventure,at:collectionDate.addingTimeInterval(300)) == nil)
_ = liveJourney.finishTimer(at:collectionDate.addingTimeInterval(300))
_ = try liveJourney.validated(at:collectionDate.addingTimeInterval(500))
let journeySaveFolder=FileManager.default.temporaryDirectory.appendingPathComponent("daygarden-journeys-\(UUID().uuidString)")
try FileManager.default.createDirectory(at:journeySaveFolder,withIntermediateDirectories:true)
defer {try? FileManager.default.removeItem(at:journeySaveFolder)}
let journeySave=journeySaveFolder.appendingPathComponent("garden.json")
for kind in JourneyKind.allCases {
    var legacy=journeyFixture()
    legacy.garden.economy.journey=Journey(kind:kind,startedAt:legacy.totalFocus-450,duration:kind == .adventure ? 1200:900,recipe:kind == .potions ? "dew":nil)
    try JSONEncoder().encode(legacy).write(to:journeySave)
    var restored=try SaveFile.read(journeySave)
    let trip=restored.garden.economy.trip(kind)!
    assert(restored.garden.ingredients == legacy.garden.ingredients && restored.garden.economy.finds == legacy.garden.economy.finds)
    assert(restored.garden.economy.journey == nil && restored.garden.economy.activeJourneys.count == 1)
    assert(trip.startedAt == legacy.totalFocus-450 && trip.duration == legacy.garden.economy.journey!.duration && trip.recipe == legacy.garden.economy.journey!.recipe)
    assert(restored.collectJourney(kind,at:journeyDate) == nil)
    restored.sessions[0].seconds+=trip.duration-450
    try SaveFile.write(restored,to:journeySave)
    restored=try SaveFile.read(journeySave)
    assert(restored.collectJourney(kind,at:journeyDate) != nil)
    let finds=restored.garden.economy.finds
    try SaveFile.write(restored,to:journeySave)
    restored=try SaveFile.read(journeySave)
    assert(restored.garden.economy.activeJourneys.isEmpty && restored.collectJourney(kind,at:journeyDate) == nil)
    assert(restored.garden.economy.finds == finds && restored.garden.economy.expeditions == 1)
}
var simultaneous=journeyFixture()
assert(simultaneous.embark(.fishing,at:journeyDate) && simultaneous.embark(.adventure,at:journeyDate) && simultaneous.embark(.potions,recipe:"dew",at:journeyDate))
try SaveFile.write(simultaneous,to:journeySave)
simultaneous=try SaveFile.read(journeySave)
assert(simultaneous.garden.economy.activeJourneys.count == 3)
assert(simultaneous.garden.economy.activeJourneys.allSatisfy{$0.startedAt == 100000})
simultaneous.sessions[0].seconds+=900
assert(simultaneous.collectJourney(.potions,at:journeyDate) != nil && simultaneous.collectJourney(.fishing,at:journeyDate) != nil)
try SaveFile.write(simultaneous,to:journeySave)
simultaneous=try SaveFile.read(journeySave)
assert(simultaneous.garden.economy.activeJourneys.count == 1 && simultaneous.garden.economy.trip(.adventure)?.duration == 1200)
assert(simultaneous.collectJourney(.potions,at:journeyDate) == nil && simultaneous.collectJourney(.fishing,at:journeyDate) == nil)
assert(simultaneous.embark(.fishing,at:journeyDate))
let savedTrip=simultaneous.garden.economy.trip(.fishing)!
simultaneous.garden.economy.activeJourneys.append(savedTrip)
assert((try? simultaneous.validated(at:journeyDate)) == nil)
print("PASS: independent fishing/adventure/potion runs, same-kind exclusion, separate one-time collection, exact legacy progress migration, new save reload and duplicate-kind rejection")

var mismatch=PotionSelection()
assert(mismatch.add("薄荷",kind:.material,available:1))
assert(mismatch.add("月光草",kind:.ingredient,available:1))
assert(!mismatch.matches(Potion.all[0]))
print("PASS: scene bounds, reciprocal routes, potion staging/cancel, exact recipe matching, single stock deduction and focus-gated collection")

assert(SceneNavigation.canonical("地图") == "首页")
assert(SceneNavigation.canonical("小院") == "首页")
assert(SceneNavigation.canonical("熬制魔药") == "炼金室")
assert(SceneNavigation.title("熬制魔药") == "炼金室")
for room in SceneNavigation.rooms+["任务","习惯","日记","日程","计时器","首页"] {assert(SceneNavigation.parent(of:room) == nil)}
for route in SceneNavigation.wilds {assert(SceneNavigation.parent(of:route) == "户外地图")}
assert(SceneNavigation.parent(of:"户外地图") == "首页")
assert(!SceneNavigation.wilds.contains("熬制魔药"))
for width:CGFloat in [320,460,760,1200] {
    for height:CGFloat in [280,360,420,800] {
        let viewport=CGSize(width:width,height:height)
        let dialog=SceneSizing.dialog(preferred:CGSize(width:550,height:460),viewport:viewport)
        assert(dialog.width<=width && dialog.height<=height)
        assert(dialog.height>=240)
    }
}
for progress in stride(from:0.0,through:1.0,by:0.02) {
    let pose=ShopCustomerPose(progress:progress)
    assert(pose.foot.x-0.065>0 && pose.foot.x+0.065<1)
    assert(pose.foot.y-0.195>0 && pose.foot.y<1)
}
assert(ShopCustomerPose(progress:0).behindCounter)
assert(!ShopCustomerPose(progress:1).behindCounter)
print("PASS: fixed parent routes, alchemy aliases, bounded dialog and customer feet/depth")

var navigation = SceneNavigation.Context()
for route in ["任务", "待办", "四象限", "习惯", "日程", "日记", "计时器", "专注"] {
    navigation.enter(route,from:"书房")
    assert(navigation.parent(of:route) == "书房")
    assert(navigation.parent(of:"书房") == nil)
    navigation.enter("书房")
    assert(navigation.parent(of:route) == nil)
    navigation.enter(route)
    assert(navigation.parent(of:route) == nil)
}
for source in ["菜单", "首页", "厨房", "商店"] {
    navigation.enter("任务",from:source)
    assert(navigation.parent(of:"任务") == nil)
}
navigation.enter("习惯",from:"书房")
assert(navigation.parent(of:"任务") == nil)
navigation.enter("任务")
assert(navigation.parent(of:"习惯") == nil)
for route in ["成长", "农场", "户外地图"] + SceneNavigation.wilds {
    navigation.enter(route,from:"书房")
    assert(navigation.parent(of:route) == SceneNavigation.parent(of:route))
}
print("PASS: study content entry context, aliases, direct-entry reset and fixed parent preservation")

for viewportWidth:CGFloat in [240,460,1000,1800,2600] {
    let width=SceneSizing.canvasWidth(viewportWidth:viewportWidth)
    for viewportHeight:CGFloat in [240,420,680,1080] {
        let fullHeight=SceneSizing.height(width:width,viewportHeight:viewportHeight,hasSidebar:false)
        let fullFit=SceneSizing.fitted(in:CGSize(width:width,height:fullHeight))
        assert(fullFit.width<=width && fullFit.height<=fullHeight)
        assert(fullHeight>=SceneSizing.height(width:width,viewportHeight:viewportHeight))
    }
}
assert(SceneSizing.stockColumns(width:80) == 1)
assert(SceneSizing.stockColumns(width:230) == 2)
assert(SceneSizing.stockColumns(width:330) == 3)
assert(SceneSizing.stockColumns(width:440) == 4)
assert(SceneSizing.stockColumns(width:1000) == 4)
print("PASS: full-width courtyard bounds and one-to-four stock columns")

for available in [CGSize(width:1400,height:900),CGSize(width:600,height:800),CGSize(width:1200,height:420)] {
    let window=SceneSizing.initialWindow(available:available)
    assert(window.width<=available.width && window.height<=available.height)
    assert(abs(window.width/window.height-1000.0/680.0)<0.0001)
}
let initialWindow=SceneSizing.initialWindow(available:CGSize(width:1400,height:900))
assert(initialWindow.width == 1000 && initialWindow.height == 680)
print("PASS: initial scene window retains landscape ratio within available screen space")
