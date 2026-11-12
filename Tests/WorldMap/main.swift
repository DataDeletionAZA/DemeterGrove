import CoreGraphics

let places = WorldMapPlace.all
assert(Set(places.map(\.id)).count == places.count)
assert(places.count == 16)
var catalogLevels = ["首页": 1]
for location in FishingLocation.all { catalogLevels["钓鱼/" + location.id] = location.level }
for location in ExpeditionLocation.all { catalogLevels["探险/" + location.id] = location.level }
for area in MineLayer.areas { catalogLevels["矿洞/" + area] = MineLayer.layers(in: area).first!.level }

let activities = places.flatMap(\.activities)
let routes = activities.map(\.route)
assert(routes.count == Set(routes).count && Set(routes) == Set(catalogLevels.keys))
for place in places {
    assert(place.point.x > 0 && place.point.x < 1 && place.point.y > 0 && place.point.y < 1)
    assert(!place.activities.isEmpty)
    let minimum = place.activities.compactMap { catalogLevels[$0.route] }.min()!
    assert(place.level == minimum && minimum >= 1)
    assert(!place.canEnter(level: minimum - 1) && place.canEnter(level: minimum))
    for activity in place.activities {
        let level = catalogLevels[activity.route]!
        assert(activity.level == level && activity.requirement == "等级 \(level)")
        assert(!activity.canEnter(level: level - 1) && activity.canEnter(level: level))
    }
    for size in [CGSize(width: 180, height: 120), CGSize(width: 450, height: 300), CGSize(width: 850, height: 580)] {
        let frame = place.popupFrame(in: size)
        assert(frame.width > 0 && frame.height > 0 && CGRect(origin: .zero, size: size).contains(frame))
    }
}

let home = places.first { $0.id == "courtyard" }!
assert(home.name == "小屋" && home.point == CGPoint(x: 0.40, y: 0.35) && home.activities.first?.route == "首页")
for (id, point, levels, routes) in [
    ("reed_marsh", CGPoint(x: 0.39, y: 0.69), [8, 8], ["钓鱼/reed_marsh", "探险/marsh"]),
    ("reef", CGPoint(x: 0.90, y: 0.61), [28, 28, 28], ["钓鱼/coral_lagoon", "探险/reef", "矿洞/潮汐矿窟"]),
    ("highland", CGPoint(x: 0.64, y: 0.16), [29, 35, 35], ["矿洞/高地矿洞", "钓鱼/mist_highland", "探险/highland"]),
    ("ruins", CGPoint(x: 0.17, y: 0.36), [32, 40], ["矿洞/遗迹矿井", "探险/ruins"]),
    ("abyss", CGPoint(x: 0.94, y: 0.40), [45], ["钓鱼/abyss"])
] {
    let place = places.first { $0.id == id }!
    assert(place.point == point && place.activities.map(\.route) == routes && place.activities.compactMap(\.level) == levels)
    assert(place.activities.filter { $0.canEnter(level: levels[0]) }.map(\.route) == zip(routes, levels).filter { $0.1 == levels[0] }.map(\.0))
}
let unavailable = WorldMapActivity("地点", "钓鱼/invalid")
assert(unavailable.level == nil && !unavailable.canEnter(level: Int.max))
print("PASS: 16 map places, exact catalog routes and level gates, independent activity unlocks, and bounded activity menus")
