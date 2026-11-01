import SwiftUI
import AppKit

struct PixelFrame: InsettableShape {
    var step: CGFloat = 2
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let s = min(step, min(r.width, r.height) / 5)
        let x = r.minX, y = r.minY, w = r.maxX, h = r.maxY
        let points = [CGPoint(x: x + 2*s, y: y), CGPoint(x: w - 2*s, y: y), CGPoint(x: w - 2*s, y: y+s),
                      CGPoint(x: w-s, y: y+s), CGPoint(x: w-s, y: y+2*s), CGPoint(x: w, y: y+2*s),
                      CGPoint(x: w, y: h-2*s), CGPoint(x: w-s, y: h-2*s), CGPoint(x: w-s, y: h-s),
                      CGPoint(x: w-2*s, y: h-s), CGPoint(x: w-2*s, y: h), CGPoint(x: x+2*s, y: h),
                      CGPoint(x: x+2*s, y: h-s), CGPoint(x: x+s, y: h-s), CGPoint(x: x+s, y: h-2*s),
                      CGPoint(x: x, y: h-2*s), CGPoint(x: x, y: y+2*s), CGPoint(x: x+s, y: y+2*s),
                      CGPoint(x: x+s, y: y+s), CGPoint(x: x+2*s, y: y+s)]
        var p = Path(); p.addLines(points); p.closeSubpath(); return p
    }
    func inset(by amount: CGFloat) -> PixelFrame { var copy = self; copy.insetAmount += amount; return copy }
}

struct MagicSurface: ViewModifier {
    var color: Color = Palette.card
    var strong = false
    func body(content: Content) -> some View {
        content.background(PixelFrame().fill(color))
            .overlay(PixelFrame().strokeBorder(strong ? Palette.gold : Palette.line, lineWidth: 1))
            .overlay(PixelFrame().inset(by: 3).strokeBorder(strong ? Palette.gold.opacity(0.33) : Palette.line.opacity(0.28), lineWidth: 1))
    }
}
extension View {
    func magicSurface(_ color: Color = Palette.card, strong: Bool = false) -> some View { modifier(MagicSurface(color: color, strong: strong)) }
    func magicControls() -> some View {
        self.background(WindowScrollSkin().frame(width:0,height:0)).font(.system(size: 13)).buttonStyle(PixelButtonStyle()).toggleStyle(PixelToggleStyle())
            .textFieldStyle(PixelTextFieldStyle()).tint(Palette.gold).preferredColorScheme(.dark)
    }
}

private struct CompactSceneControlsKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var compactSceneControls: Bool {
        get { self[CompactSceneControlsKey.self] }
        set { self[CompactSceneControlsKey.self] = newValue }
    }
}

struct PixelButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.compactSceneControls) private var compact
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: compact ? 12 : 13)).foregroundStyle(primary ? Palette.goldLight : Palette.ink)
            .padding(.horizontal, compact ? 10 : 12).padding(.vertical, compact ? 7 : 9)
            .background(PixelFrame(step: 2).fill(configuration.isPressed ? Palette.paper : primary ? Palette.moss : Palette.control))
            .overlay(PixelFrame(step: 2).strokeBorder(primary ? Palette.gold : Palette.line, lineWidth: 1))
            .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(configuration.isPressed ? 0 : 0.35)).frame(height: 2).padding(.horizontal, 4) }
            .offset(y: configuration.isPressed ? 1 : 0).opacity(enabled ? 1 : 0.36)
    }
}

struct PixelTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.textFieldStyle(.plain).font(.system(size: 13)).padding(9).foregroundStyle(Palette.ink)
            .background(Palette.paper).overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
    }
}

struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 9) {
                ZStack {
                    Rectangle().fill(Palette.paper).frame(width: 16, height: 16)
                        .overlay(Rectangle().stroke(configuration.isOn ? Palette.gold : Palette.line, lineWidth: 1))
                    if configuration.isOn { PixelIcon(name: "check", size: 12) }
                }
                configuration.label
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

struct PixelTabs<Value: Hashable>: View {
    @Binding var selection: Value
    var items: [(Value, String)]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button { selection = item.0 } label: { Text(item.1).frame(maxWidth: .infinity) }
                    .buttonStyle(PixelButtonStyle(primary: selection == item.0))
                    .accessibilityAddTraits(selection == item.0 ? [.isSelected] : [])
            }
        }
    }
}

struct PixelSelect<Value: Hashable>: View {
    @Binding var selection: Value
    var items: [(Value, String)]
    @State private var showing = false
    @State private var hovered: Int?
    @FocusState private var focused: Int?
    private var label: String { items.first { $0.0 == selection }?.1 ?? "选择" }
    var body: some View {
        Button { showing.toggle() } label: {
            HStack {
                Text(label).lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down").font(.system(size: 9))
            }.frame(maxWidth: .infinity)
        }.buttonStyle(PixelButtonStyle()).accessibilityValue(label)
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                ScrollViewReader { reader in
                    PixelScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                Button { selection = item.0; showing = false } label: {
                                    HStack(spacing: 8) {
                                        Text(item.1).lineLimit(2).multilineTextAlignment(.leading)
                                        Spacer(minLength: 8)
                                        if selection == item.0 { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(PixelButtonStyle(primary: selection == item.0 || hovered == index || focused == index))
                                    .focused($focused, equals: index).id(index)
                                    .onHover { hovered = $0 ? index : nil }
                                    .accessibilityAddTraits(selection == item.0 ? [.isSelected] : [])
                            }
                        }.padding(8)
                    }.frame(width: 240, height: min(330, CGFloat(items.count)*40+16))
                        .onAppear { focused = items.firstIndex { $0.0 == selection }; if let focused { reader.scrollTo(focused) } }
                        .onChange(of: focused) { _, value in if let value { reader.scrollTo(value) } }
                        .onMoveCommand { direction in
                            guard !items.isEmpty else { return }
                            if direction == .down { focused = min(items.count-1,(focused ?? -1)+1) }
                            if direction == .up { focused = max(0,(focused ?? 1)-1) }
                        }
                        .onExitCommand { showing = false }
                }.magicSurface(Palette.paper, strong: true).magicControls()
            }
    }
}

struct PixelStepper: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var body: some View {
        HStack(spacing: 10) {
            Text(title).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Button("−") { value = max(range.lowerBound, value - 1) }.disabled(value <= range.lowerBound).accessibilityLabel("减少" + title)
            Text("\(value)").font(.system(size: 17, weight: .medium)).frame(minWidth: 30)
            Button("＋") { value = min(range.upperBound, value + 1) }.disabled(value >= range.upperBound).accessibilityLabel("增加" + title)
            Text("分钟").foregroundStyle(Palette.muted)
        }.font(.system(size: 13))
    }
}

struct PixelProgress: View {
    var value: Double
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.paper)
                Rectangle().fill(Palette.sage).frame(width: geometry.size.width * min(1, max(0, value)))
            }.overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
        }.frame(height: 5).accessibilityLabel("进度").accessibilityValue("\(Int(min(1, max(0, value)) * 100))%")
    }
}

struct PixelIcon: View {
    var name: String
    var size: CGFloat = 28
    var body: some View {
        Group {
            if let image=GameImages.interfaceIcon(name:name) {
                Image(nsImage:image).resizable().interpolation(.none).scaledToFit()
            } else {
        Canvas { context, bounds in
            context.withCGContext { c in
                c.setShouldAntialias(false)
                c.scaleBy(x: bounds.width / 32, y: bounds.height / 32)
                let outline = NSColor(red: 0.09, green: 0.07, blue: 0.13, alpha: 1)
                let gold = NSColor(red: 0.65, green: 0.51, blue: 0.29, alpha: 1)
                let bright = NSColor(red: 0.91, green: 0.80, blue: 0.53, alpha: 1)
                let cream = NSColor(red: 0.80, green: 0.72, blue: 0.54, alpha: 1)
                let paper = NSColor(red: 0.64, green: 0.57, blue: 0.43, alpha: 1)
                let purple = NSColor(red: 0.48, green: 0.33, blue: 0.59, alpha: 1)
                let lightPurple = NSColor(red: 0.68, green: 0.52, blue: 0.77, alpha: 1)
                let green = NSColor(red: 0.30, green: 0.43, blue: 0.32, alpha: 1)
                let lightGreen = NSColor(red: 0.56, green: 0.67, blue: 0.42, alpha: 1)
                let glass = NSColor(red: 0.46, green: 0.55, blue: 0.59, alpha: 1)
                func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
                    c.setFillColor(color.cgColor); c.fill(CGRect(x: x, y: y, width: w, height: h))
                }
                func poly(_ points: [(CGFloat, CGFloat)], _ color: NSColor) {
                    c.beginPath(); c.move(to: CGPoint(x: points[0].0, y: points[0].1))
                    for p in points.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
                    c.closePath(); c.setFillColor(color.cgColor); c.fillPath()
                }
                func scroll() {
                    rect(6, 4, 20, 24, outline); rect(7, 5, 18, 22, paper); rect(9, 5, 15, 21, cream)
                    rect(4, 3, 23, 5, gold); rect(5, 3, 21, 2, bright); rect(5, 6, 2, 3, outline)
                    rect(7, 25, 21, 4, gold); rect(8, 25, 19, 1, bright); rect(25, 26, 2, 2, outline)
                }
                switch name {
                case "桌宠":
                    rect(8,8,16,16,outline);rect(10,11,12,11,cream)
                    rect(8,7,16,7,green);rect(11,4,10,5,green);rect(6,12,20,3,gold)
                    rect(12,16,2,2,outline);rect(19,16,2,2,outline);rect(14,21,5,1,gold)
                    rect(6,24,20,6,outline);rect(8,25,16,4,green);rect(14,25,5,4,purple)
                case "close":
                    for i in 0..<12 { rect(CGFloat(10+i), CGFloat(10+i), 2, 2, cream); rect(CGFloat(21-i), CGFloat(10+i), 2, 2, cream) }
                case "check":
                    poly([(5,16),(8,13),(13,18),(24,7),(27,10),(13,24)], lightGreen)
                    poly([(8,14),(13,19),(25,8),(26,10),(13,22)], bright)
                case "down": poly([(9,12),(23,12),(16,19)], cream)
                case "计时器", "timer", "专注与提醒":
                    rect(7, 3, 18, 3, outline); rect(8, 3, 16, 2, bright); rect(10, 5, 12, 2, gold)
                    poly([(10,7),(22,7),(21,11),(18,15),(18,17),(22,23),(22,26),(10,26),(10,23),(14,17),(14,15),(10,10)], glass)
                    poly([(12,7),(20,7),(19,11),(16,14),(13,10)], cream)
                    poly([(12,24),(16,18),(20,24)], bright)
                    rect(11,8,1,3,NSColor.white.withAlphaComponent(0.7)); rect(15,14,2,5,bright)
                    rect(7,26,18,3,outline);rect(8,26,16,1,bright);rect(9,27,14,2,gold)
                    rect(7,6,1,20,gold);rect(24,6,1,20,gold)
                case "日记", "book.closed", "存档":
                    rect(5,3,23,26,outline);rect(7,4,19,24,green);rect(6,4,3,24,gold)
                    rect(10,5,14,1,lightGreen);rect(24,6,1,20,outline);rect(10,25,14,2,cream)
                    rect(10,27,14,1,paper);rect(10,7,2,2,bright);rect(21,7,2,2,bright)
                    rect(10,22,2,2,bright);rect(21,22,2,2,bright)
                    poly([(16,10),(20,15),(16,20),(12,15)],gold);poly([(16,12),(18,15),(16,18),(14,15)],purple)
                    rect(6,7,3,1,bright);rect(6,23,3,1,bright);rect(25,14,4,4,gold)
                case "任务", "待办", "checklist", "表达与提示词":
                    scroll();rect(12,11,8,1,gold);rect(12,15,10,1,gold);rect(12,19,6,1,gold)
                    rect(9,11,1,1,outline);rect(9,15,1,1,outline);rect(9,19,1,1,outline)
                    poly([(25,10),(28,8),(27,19),(19,26),(20,21)],glass);rect(20,24,2,3,outline)
                case "日程", "calendar":
                    scroll();rect(10,9,13,3,purple);rect(11,3,2,5,outline);rect(20,3,2,5,outline)
                    rect(11,3,1,4,bright);rect(20,3,1,4,bright)
                    for y in [15,19,23] { for x in [11,15,19] { rect(CGFloat(x),CGFloat(y),2,2,gold) } }
                    rect(14,18,4,4,purple);rect(15,19,2,2,lightPurple)
                case "四象限", "square.grid.2x2":
                    for (x,y,color) in [(CGFloat(4),CGFloat(4),purple),(18,4,green),(4,18,gold),(18,18,glass)] {
                        rect(x,y,11,11,outline);rect(x+1,y+1,9,9,color);rect(x+2,y+2,7,1,cream);rect(x+2,y+3,1,5,cream)
                        rect(x+8,y+3,1,6,outline.withAlphaComponent(0.4))
                    }
                case "农场", "carrot", "胡萝卜":
                    poly([(16,10),(23,13),(20,22),(7,29),(9,20)],outline)
                    poly([(16,12),(21,14),(18,22),(9,27),(11,20)],NSColor(red:0.68,green:0.36,blue:0.20,alpha:1))
                    poly([(16,13),(18,14),(11,24),(10,25)],NSColor(red:0.88,green:0.56,blue:0.30,alpha:1))
                    poly([(19,12),(17,4),(20,3),(21,9),(25,3),(28,5),(23,11)],green)
                    rect(19,4,1,6,lightGreen);rect(24,5,1,5,lightGreen);rect(12,21,3,1,gold)
                case "小麦":
                    rect(15,8,2,21,gold)
                    for y in [8,13,18] {
                        poly([(15,CGFloat(y+5)),(10,CGFloat(y+2)),(10,CGFloat(y-2)),(14,CGFloat(y)),(16,CGFloat(y+4))],gold)
                        poly([(17,CGFloat(y+5)),(22,CGFloat(y+2)),(22,CGFloat(y-2)),(18,CGFloat(y)),(16,CGFloat(y+4))],cream)
                        rect(11,CGFloat(y),1,2,bright);rect(19,CGFloat(y),1,2,bright)
                    }
                    poly([(16,3),(19,7),(16,11),(14,7)],bright)
                case "番茄":
                    poly([(7,13),(11,9),(22,9),(27,14),(27,22),(22,28),(11,28),(6,23),(5,18)],outline)
                    poly([(8,14),(12,11),(22,11),(25,15),(25,22),(21,26),(12,26),(8,22),(7,18)],NSColor(red:0.65,green:0.27,blue:0.24,alpha:1))
                    poly([(10,14),(13,12),(18,12),(15,15),(11,19),(9,19)],NSColor(red:0.83,green:0.42,blue:0.32,alpha:1))
                    poly([(15,11),(11,7),(16,9),(17,4),(19,9),(24,8),(20,12),(16,14)],green)
                    rect(17,5,1,5,lightGreen);rect(11,15,2,2,cream)
                case "习惯", "leaf", "幼苗":
                    poly([(5,26),(8,14),(13,7),(25,4),(26,16),(20,24),(10,27)],outline)
                    poly([(7,25),(10,14),(15,9),(24,6),(24,16),(18,23)],green)
                    poly([(9,24),(16,16),(23,8),(24,10),(17,18),(10,26)],lightGreen)
                    rect(13,13,1,5,lightGreen);rect(17,18,5,1,lightGreen);rect(6,25,3,4,gold)
                case "厨房", "frying.pan":
                    poly([(7,12),(25,12),(28,19),(26,25),(22,28),(10,28),(6,24),(4,18)],outline)
                    poly([(8,14),(24,14),(26,19),(24,24),(21,26),(11,26),(8,23),(6,18)],glass)
                    poly([(9,17),(23,17),(24,23),(21,26),(11,26)],NSColor(red:0.25,green:0.28,blue:0.34,alpha:1))
                    rect(7,12,18,3,gold);rect(9,12,14,2,purple);rect(11,12,9,1,lightPurple)
                    rect(3,16,3,6,gold);rect(26,16,3,6,gold);rect(9,27,3,3,outline);rect(22,27,3,3,outline)
                    rect(12,5,2,4,glass);rect(11,3,2,3,glass);rect(20,7,2,3,glass);rect(21,4,2,3,glass)
                case "商店", "storefront":
                    poly([(4,12),(7,7),(25,7),(28,12),(28,27),(4,27)],outline)
                    poly([(5,12),(8,8),(24,8),(27,12),(27,25),(5,25)],NSColor(red:0.39,green:0.25,blue:0.21,alpha:1))
                    rect(6,11,20,2,gold);rect(5,16,22,2,outline);rect(7,8,2,17,gold);rect(23,8,2,17,gold)
                    rect(7,9,1,15,bright);rect(23,9,1,15,bright);rect(13,14,6,7,gold);rect(14,15,4,5,bright);rect(15,17,2,2,outline)
                    rect(10,10,12,1,paper);rect(10,22,12,1,outline.withAlphaComponent(0.4))
                case "统计", "chart.bar":
                    scroll();rect(10,21,3,3,green);rect(15,17,3,7,purple);rect(20,12,3,12,gold)
                    rect(10,21,2,1,lightGreen);rect(15,17,2,1,lightPurple);rect(20,12,2,1,bright)
                case "设置", "settings", "slider.horizontal.3", "通用":
                    poly([(12,3),(20,3),(21,7),(25,8),(29,12),(29,20),(25,24),(21,25),(20,29),(12,29),(11,25),(7,24),(3,20),(3,12),(7,8),(11,7)],outline)
                    poly([(13,4),(19,4),(20,8),(24,9),(28,13),(28,19),(24,23),(20,24),(19,28),(13,28),(12,24),(8,23),(4,19),(4,13),(8,9),(12,8)],gold)
                    rect(12,10,8,12,paper);rect(10,12,12,8,paper);rect(13,12,6,8,outline);rect(12,13,8,6,outline)
                    rect(14,14,4,4,purple);rect(13,5,6,1,bright);rect(5,13,1,6,bright)
                default:
                    rect(12,3,8,4,gold);rect(13,4,6,2,bright);rect(13,7,6,7,glass)
                    poly([(13,12),(19,12),(25,20),(24,27),(21,29),(11,29),(8,26),(7,20)],outline)
                    poly([(13,14),(19,14),(23,20),(22,26),(20,27),(12,27),(10,25),(9,20)],glass)
                    poly([(10,21),(22,21),(21,26),(12,26)],purple);rect(12,21,8,1,lightPurple)
                    rect(11,18,2,5,NSColor.white.withAlphaComponent(0.65));rect(14,8,1,5,cream)
                }
            }
            }
        }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct MagicHeader: View {
    var title: String
    var metadata = ""
    var draggable = true
    var back: (() -> Void)? = nil
    var close: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            if let back {
                Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width:44,height:40).contentShape(Rectangle()) }
                    .buttonStyle(.plain).foregroundStyle(Palette.goldLight).help("返回上一级").accessibilityLabel("返回上一级")
            }
            HStack(spacing: 10) {
                PixelIcon(name: title, size: 24)
                Text(title).font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.goldLight)
                if !metadata.isEmpty {Text(metadata).font(.caption).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)}
                Spacer(minLength:0)
            }.contentShape(Rectangle()).overlay { if draggable { WindowDragArea() } }
            Button(action: close) { PixelIcon(name: "close", size: 16).frame(width:40,height:40).contentShape(Rectangle()) }.buttonStyle(.plain).help("关闭").accessibilityLabel("关闭")
        }.padding(.horizontal, 16).frame(height: 48)
            .background(Palette.paper).overlay(alignment: .bottom) { Rectangle().fill(Palette.gold.opacity(0.6)).frame(height: 1).padding(.horizontal, 10) }
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView { WindowDragView() }
    func updateNSView(_ view: WindowDragView, context: Context) { }
}
final class WindowDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

final class MagicPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
