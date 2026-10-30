import SwiftUI
import AppKit

private struct SceneViewportKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 800, height: 600)
}
extension EnvironmentValues {
    var sceneViewport: CGSize {
        get { self[SceneViewportKey.self] }
        set { self[SceneViewportKey.self] = newValue }
    }
}

struct PixelScrollView<Content: View>: View {
    var axes: Axis.Set
    var showsIndicators: Bool
    var content: Content
    init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content.background(ScrollSkin(axes: axes, visible: showsIndicators).frame(width: 0, height: 0))
        }
    }
}

private struct ScrollSkin: NSViewRepresentable {
    var axes: Axis.Set
    var visible: Bool
    func makeNSView(context: Context) -> ScrollSkinView { ScrollSkinView() }
    func updateNSView(_ view: ScrollSkinView, context: Context) {
        view.axes = axes; view.visible = visible
        DispatchQueue.main.async { [weak view] in view?.install() }
    }
}
private final class ScrollSkinView: NSView {
    var axes: Axis.Set = .vertical
    var visible = true
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); DispatchQueue.main.async { [weak self] in self?.install() } }
    override func layout() { super.layout(); install() }
    func install() {
        guard let scroll = enclosingScrollView else { return }
        if scroll.scrollerStyle != .legacy { scroll.scrollerStyle = .legacy }
        if !scroll.autohidesScrollers { scroll.autohidesScrollers = true }
        for horizontal in [false, true] {
            let enabled = visible && axes.contains(horizontal ? .horizontal : .vertical)
            if horizontal, scroll.hasHorizontalScroller != enabled { scroll.hasHorizontalScroller = enabled }
            if !horizontal, scroll.hasVerticalScroller != enabled { scroll.hasVerticalScroller = enabled }
            let old = horizontal ? scroll.horizontalScroller : scroll.verticalScroller
            guard enabled, !(old is PixelScroller) else { continue }
            let bar = PixelScroller(frame: old?.frame ?? (horizontal ? NSRect(x: 0,y: 0,width: 100,height: 14) : NSRect(x: 0,y: 0,width: 14,height: 100)))
            bar.scrollerStyle = .legacy
            if horizontal { scroll.horizontalScroller = bar } else { scroll.verticalScroller = bar }
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
}
struct WindowScrollSkin: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowScrollSkinView { WindowScrollSkinView() }
    func updateNSView(_ view: WindowScrollSkinView, context: Context) { view.schedule() }
}
final class WindowScrollSkinView: NSView {
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); schedule() }
    func schedule() { DispatchQueue.main.async { [weak self] in if let root=self?.window?.contentView { self?.style(root) } } }
    private func style(_ view:NSView) {
        if let scroll=view as? NSScrollView {
            if scroll.scrollerStyle != .legacy { scroll.scrollerStyle = .legacy }
            for horizontal in [false,true] {
                guard let old=horizontal ? scroll.horizontalScroller:scroll.verticalScroller, !(old is PixelScroller) else { continue }
                let bar=PixelScroller(frame:old.frame);bar.scrollerStyle = .legacy
                if horizontal {scroll.horizontalScroller=bar} else {scroll.verticalScroller=bar}
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
        for child in view.subviews {style(child)}
    }
}

final class PixelScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { false }
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        NSColor(Palette.paper).setFill(); bounds.fill()
        let vertical = bounds.height > bounds.width
        let track = bounds.insetBy(dx: vertical ? 5 : 1, dy: vertical ? 1 : 5)
        NSColor(Palette.line).setFill(); track.fill()
    }
    override func drawKnob() {
        let vertical = bounds.height > bounds.width
        let knob = rect(for: .knob).insetBy(dx: vertical ? 3 : 1, dy: vertical ? 1 : 3)
        NSColor(Palette.moss).setFill(); knob.fill()
        NSColor(Palette.gold).setStroke(); NSBezierPath(rect: knob.insetBy(dx:0.5,dy:0.5)).stroke()
        NSColor(Palette.goldLight).setFill()
        let grip = vertical ? NSRect(x:knob.minX+2,y:knob.midY-1,width:max(1,knob.width-4),height:2) : NSRect(x:knob.midX-1,y:knob.minY+2,width:2,height:max(1,knob.height-4))
        grip.fill()
    }
}

struct PixelSlider: View {
    @Binding var value: Double
    var bounds: ClosedRange<Double>
    var step: Double
    @Environment(\.isEnabled) private var enabled
    @FocusState private var focused: Bool
    init(value: Binding<Double>, in bounds: ClosedRange<Double>, step: Double = 1) {
        _value = value; self.bounds = bounds; self.step = step
    }
    private var fraction: CGFloat { CGFloat((value-bounds.lowerBound)/max(1,bounds.upperBound-bounds.lowerBound)) }
    private func set(_ candidate: Double) { value = min(bounds.upperBound,max(bounds.lowerBound,(candidate/step).rounded()*step)) }
    var body: some View {
        GeometryReader { geo in
            let travel = max(1,geo.size.width-14)
            ZStack(alignment: .leading) {
                PixelFrame(step:1).fill(Palette.paper).frame(height:6).overlay(PixelFrame(step:1).stroke(Palette.line,lineWidth:1).frame(height:6))
                Rectangle().fill(Palette.moss).frame(width:14+travel*min(1,max(0,fraction)),height:4)
                PixelFrame(step:1).fill(Palette.gold).frame(width:14,height:18)
                    .overlay(PixelFrame(step:1).stroke(focused ? Palette.goldLight:Palette.line,lineWidth:1))
                    .offset(x:travel*min(1,max(0,fraction)))
            }.frame(height:22).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance:0).onChanged { event in
                    guard enabled else { return }; focused = true
                    set(bounds.lowerBound + Double(min(1,max(0,(event.location.x-7)/travel)))*(bounds.upperBound-bounds.lowerBound))
                })
        }.frame(height:22).focusable().focused($focused).focusEffectDisabled()
            .onMoveCommand { direction in
                guard enabled else { return }
                if direction == .right || direction == .up { set(value+step) }
                if direction == .left || direction == .down { set(value-step) }
            }
            .accessibilityValue(String(Int(value)))
            .accessibilityAdjustableAction { direction in
                guard enabled else { return }
                if direction == .increment { set(value+step) }
                if direction == .decrement { set(value-step) }
            }.opacity(enabled ? 1 : 0.4)
    }
}
