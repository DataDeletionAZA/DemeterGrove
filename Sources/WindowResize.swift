import SwiftUI
import AppKit

struct ResizeEdges: OptionSet {
    let rawValue: Int
    static let left = Self(rawValue:1), right = Self(rawValue:2)
    static let bottom = Self(rawValue:4), top = Self(rawValue:8)
    static func hit(_ point:NSPoint,in bounds:NSRect) -> Self {
        guard bounds.contains(point) else { return [] }
        var edges:Self = []
        if point.x < bounds.minX+12 { edges.insert(.left) }
        if point.x > bounds.maxX-12 { edges.insert(.right) }
        if point.y < bounds.minY+12 { edges.insert(.bottom) }
        if point.y > bounds.maxY-12 { edges.insert(.top) }
        return edges
    }
    func frame(from original:NSRect,delta:NSPoint,minimum:NSSize,screen:NSRect) -> NSRect {
        var x=original.minX,y=original.minY,w=original.width,h=original.height
        if contains(.left) { x=max(screen.minX,min(original.minX+delta.x,original.maxX-minimum.width));w=original.maxX-x }
        if contains(.right) { w=min(screen.maxX-original.minX,max(minimum.width,original.width+delta.x)) }
        if contains(.bottom) { y=max(screen.minY,min(original.minY+delta.y,original.maxY-minimum.height));h=original.maxY-y }
        if contains(.top) { h=min(screen.maxY-original.minY,max(minimum.height,original.height+delta.y)) }
        return NSRect(x:x,y:y,width:w,height:h)
    }
}

struct WindowResizeBorder: NSViewRepresentable {
    var minimumContentSize = NSSize(width:420,height:360)
    var began: () -> Void = {}
    var ended: () -> Void = {}
    func makeNSView(context:Context) -> WindowResizeView { WindowResizeView() }
    func updateNSView(_ view:WindowResizeView,context:Context) { view.began=began;view.ended=ended;view.minimumContentSize=minimumContentSize }
}

final class WindowResizeView:NSView {
    var minimumContentSize = NSSize(width:420,height:360)
    var began: () -> Void = {}
    var ended: () -> Void = {}
    private var edges:ResizeEdges = []
    private var start=NSPoint.zero
    private var original=NSRect.zero
    override func hitTest(_ point:NSPoint) -> NSView? {
        guard !isHidden, window?.styleMask.contains(.resizable) == true,
              !ResizeEdges.hit(convert(point,from:superview),in:bounds).isEmpty else {return nil}
        return self
    }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool {true}
    override func resetCursorRects() {
        addCursorRect(NSRect(x:0,y:0,width:12,height:bounds.height),cursor:.resizeLeftRight)
        addCursorRect(NSRect(x:bounds.width-12,y:0,width:12,height:bounds.height),cursor:.resizeLeftRight)
        addCursorRect(NSRect(x:12,y:0,width:max(0,bounds.width-24),height:12),cursor:.resizeUpDown)
        addCursorRect(NSRect(x:12,y:bounds.height-12,width:max(0,bounds.width-24),height:12),cursor:.resizeUpDown)
    }
    override func mouseDown(with event:NSEvent) {
        guard let window else {return}
        edges=ResizeEdges.hit(convert(event.locationInWindow,from:nil),in:bounds)
        guard !edges.isEmpty else {return}
        start=NSEvent.mouseLocation;original=window.frame;began()
    }
    override func mouseDragged(with event:NSEvent) {
        guard let window,!edges.isEmpty else {return}
        let point=NSEvent.mouseLocation,area=window.screen?.visibleFrame ?? original
        let contentMinimum=window.frameRect(forContentRect:NSRect(origin:.zero,size:minimumContentSize)).size
        let minimum=NSSize(width:min(area.width,max(contentMinimum.width,window.minSize.width)),height:min(area.height,max(contentMinimum.height,window.minSize.height)))
        let frame=edges.frame(from:original,delta:NSPoint(x:point.x-start.x,y:point.y-start.y),minimum:minimum,screen:area)
        window.setFrame(frame,display:true)
    }
    override func mouseUp(with event:NSEvent) {
        guard !edges.isEmpty else {return}
        edges=[];ended();window?.invalidateCursorRects(for:self)
    }
}
