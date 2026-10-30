import AppKit

enum PetMenuSide { case left, right, above }
enum PetPlacement {
    static func constrain(_ frame: NSRect, to screen: NSRect) -> NSRect {
        var result = frame
        result.origin.x = max(screen.minX, min(frame.minX, screen.maxX-frame.width))
        result.origin.y = max(screen.minY, min(frame.minY, screen.maxY-frame.height))
        return result
    }
    static func screen(for frame: NSRect, screens: [NSRect], pointer: NSPoint? = nil) -> NSRect {
        if let pointer, let hit = screens.first(where: { $0.contains(pointer) }) { return hit }
        let overlapping = screens.filter { $0.intersects(frame) }
        if let hit = overlapping.max(by: { a,b in
            let x = a.intersection(frame), y = b.intersection(frame)
            return x.width*x.height < y.width*y.height
        }) { return hit }
        return screens.min(by: { a,b in
            hypot(a.midX-frame.midX,a.midY-frame.midY) < hypot(b.midX-frame.midX,b.midY-frame.midY)
        }) ?? NSRect(x:0,y:0,width:1024,height:768)
    }
    static func facingRight(pet: NSRect, screen: NSRect, previous: Bool) -> Bool {
        if pet.midX < screen.midX - 36 { return true }
        if pet.midX > screen.midX + 36 { return false }
        return previous
    }
    static func menu(pet: NSRect, size: NSSize, screen: NSRect, previous: PetMenuSide?) -> (NSPoint, PetMenuSide) {
        let left = pet.minX - screen.minX - 16, right = screen.maxX - pet.maxX - 16
        let side: PetMenuSide
        if let previous, (previous == .left && left >= size.width) || (previous == .right && right >= size.width) ||
            (previous == .above && screen.maxY - pet.maxY >= size.height + 16) { side = previous }
        else if max(left,right) >= size.width { side = left >= right ? .left : .right }
        else { side = .above }
        let x = side == .left ? pet.minX - size.width - 8 : side == .right ? pet.maxX + 8 : pet.midX - size.width / 2
        let y = side == .above ? pet.maxY + 8 : pet.maxY - size.height
        return (NSPoint(x: max(screen.minX+8,min(x,screen.maxX-size.width-8)), y: max(screen.minY+8,min(y,screen.maxY-size.height-8))),side)
    }
}
