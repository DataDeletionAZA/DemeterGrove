import AppKit

let screens = [NSRect(x:0,y:24,width:1440,height:876), NSRect(x:-1920,y:0,width:1920,height:1080), NSRect(x:0,y:900,width:1280,height:800)]
for screen in screens {
    for x in stride(from:screen.minX-900,through:screen.maxX+900,by:300) {
        for y in stride(from:screen.minY-600,through:screen.maxY+600,by:300) {
            let clipped = PetPlacement.constrain(NSRect(x:x,y:y,width:200,height:292),to:screen)
            assert(screen.contains(clipped))
            assert(PetPlacement.constrain(clipped,to:screen) == clipped)
            for size in [NSSize(width:320,height:590), NSSize(width:720,height:650)] {
                let width = min(size.width,max(clipped.minX-screen.minX-16,screen.maxX-clipped.maxX-16))
                let fitted = NSSize(width:width,height:min(size.height,screen.height-16))
                let placement = PetPlacement.menu(pet:clipped,size:fitted,screen:screen,previous:nil)
                let menu = NSRect(origin:placement.0,size:fitted)
                assert(screen.contains(menu))
                assert(!menu.intersects(clipped))
                assert(PetPlacement.menu(pet:clipped,size:fitted,screen:screen,previous:placement.1).1 == placement.1)
            }
        }
    }
}
assert(PetPlacement.screen(for:NSRect(x:-1100,y:100,width:200,height:292),screens:screens) == screens[1])
assert(PetPlacement.screen(for:NSRect(x:500,y:100,width:200,height:292),screens:screens,pointer:NSPoint(x:-100,y:500)) == screens[1])
assert(PetPlacement.screen(for:NSRect(x:5000,y:200,width:200,height:292),screens:[screens[0]]) == screens[0])
assert(PetPlacement.screen(for:NSRect(x:200,y:850,width:200,height:292),screens:screens) == screens[2])
print("PASS: screen edges, disconnected displays, screen handoff and attached placement")
