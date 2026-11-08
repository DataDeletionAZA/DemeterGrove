import Foundation

let places=WorldMapPlace.all
assert(Set(places.map(\.id)).count == places.count)
assert(places.count == 11)
for place in places {
    assert(place.point.x>0 && place.point.x<1 && place.point.y>0 && place.point.y<1)
    assert(place.level>=1)
    assert(!place.canEnter(level:place.level-1))
    if place.route == nil {assert(!place.canEnter(level:1000))}
    else {assert(place.canEnter(level:place.level))}
}
assert(places.first{$0.id == "courtyard"}?.point.x == 0.40)
assert(places.first{$0.id == "courtyard"}?.point.y == 0.35)
assert(places.allSatisfy{$0.route != nil && !$0.activities.isEmpty})
assert(places.first{$0.id == "polar"}!.activities.map{$0.1}.contains("钓鱼/polar_coast"))
assert(places.first{$0.id == "sea"}!.activities.count == 2)
print("PASS: map marker bounds, unique places, destination routes and locked terrain")
