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
                Button { selection = item.0 } label: { Text(item.1).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity) }
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
                case "计时器", "专注", "记录专注", "timer", "专注与提醒":
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
                case "农场", "种子柜", "seed-cabinet":
                    poly([(10,11),(22,11),(26,18),(27,27),(23,30),(8,30),(5,26),(7,17)],outline)
                    poly([(10,13),(21,13),(24,19),(25,26),(22,28),(9,28),(7,25),(9,18)],paper)
                    poly([(10,14),(14,14),(11,24),(11,28),(9,28),(7,25)],cream)
                    rect(9,10,15,3,gold);rect(10,10,12,1,bright)
                    poly([(15,12),(10,8),(9,4),(13,5),(17,9),(18,3),(23,2),(22,7),(18,12)],green)
                    rect(18,5,1,6,lightGreen);rect(11,6,2,2,lightGreen)
                    rect(15,18,2,7,gold);poly([(15,22),(12,19),(12,17),(15,18),(17,21),(19,17),(22,17),(20,21),(17,24)],green)
                case "carrot", "胡萝卜":
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
                    poly([(9,11),(24,11),(27,16),(27,25),(23,29),(9,29),(5,25),(5,16)],outline)
                    rect(6,14,20,3,gold);rect(8,12,16,2,bright)
                    poly([(7,17),(25,17),(25,24),(22,27),(10,27),(7,24)],glass)
                    poly([(9,22),(24,22),(23,26),(11,26)],green);rect(8,18,2,6,cream)
                    rect(2,16,3,7,gold);rect(27,16,3,7,gold);rect(2,17,1,4,bright);rect(29,17,1,4,bright)
                    poly([(20,15),(22,5),(21,3),(23,1),(26,3),(26,6),(23,15)],outline)
                    poly([(21,14),(24,5),(23,3),(24,2),(25,4),(24,7),(22,14)],bright)
                    rect(11,4,2,3,glass);rect(10,7,2,3,glass);rect(15,2,2,3,glass)
                case "书房", "study":
                    rect(4,19,25,10,outline);rect(5,20,22,2,gold);rect(7,23,20,3,cream);rect(6,27,22,1,green)
                    rect(6,12,12,8,outline);rect(7,13,10,6,glass);rect(8,15,8,4,purple)
                    rect(8,10,8,3,gold);rect(9,10,6,1,bright);rect(8,14,2,3,cream)
                    poly([(14,14),(18,5),(24,2),(28,2),(27,7),(22,13),(18,15)],outline)
                    poly([(16,12),(19,6),(24,3),(27,3),(25,7),(21,11)],cream)
                    poly([(13,18),(15,13),(24,5),(18,13)],gold)
                case "牧场":
                    poly([(3,13),(16,3),(29,13),(27,16),(26,29),(6,29),(5,16)],outline)
                    poly([(5,13),(16,5),(27,13),(26,14),(16,8),(6,15)],green)
                    rect(7,15,18,12,paper);rect(8,16,16,1,cream);rect(10,19,12,9,outline)
                    rect(11,20,10,7,gold);rect(15,20,2,7,outline)
                    poly([(11,20),(12,20),(20,26),(20,27),(19,27),(11,21)],cream)
                    poly([(20,20),(21,20),(21,21),(13,27),(11,27)],cream)
                    rect(13,11,6,5,outline);rect(14,12,4,3,bright)
                case "酒馆", "酒馆与装备", "tavern":
                    rect(20,11,9,14,outline);rect(21,13,6,10,gold);rect(23,15,3,6,outline)
                    poly([(5,8),(22,8),(23,12),(23,26),(20,29),(7,29),(4,26),(4,12)],outline)
                    rect(6,11,15,15,gold);rect(7,13,3,12,cream);rect(12,13,2,12,paper);rect(18,13,2,12,paper)
                    rect(5,11,17,2,glass);rect(5,24,17,3,glass);rect(6,25,15,1,cream)
                    poly([(5,10),(5,6),(8,6),(9,3),(14,3),(16,5),(20,5),(22,8),(21,11),(17,11),(16,14),(13,14),(12,10)],cream)
                    rect(9,4,4,2,bright);rect(6,7,3,2,bright)
                case "锻造室", "forge":
                    poly([(3,17),(29,17),(26,22),(21,23),(20,26),(24,28),(24,30),(8,30),(8,28),(12,26),(11,22),(6,21)],outline)
                    poly([(5,18),(27,18),(25,20),(20,21),(18,26),(22,28),(10,28),(14,26),(13,21),(7,20)],glass)
                    rect(6,18,19,1,cream);rect(13,23,5,3,purple);rect(10,28,12,1,gold)
                    poly([(11,16),(13,17),(23,5),(21,3)],outline);poly([(12,15),(13,15),(22,5),(21,5)],gold)
                    poly([(8,4),(12,1),(21,8),(21,10),(17,13),(8,6)],outline)
                    poly([(10,4),(12,3),(19,9),(17,11),(10,6)],glass);poly([(10,4),(12,3),(17,7),(16,8)],cream)
                case "成长", "growth", "sparkles":
                    rect(4,24,24,5,outline);rect(5,25,7,3,paper);rect(13,20,8,8,outline);rect(14,21,6,7,gold)
                    rect(21,15,7,13,outline);rect(22,16,5,12,paper);rect(5,25,7,1,bright);rect(14,21,6,1,bright);rect(22,16,5,1,bright)
                    rect(11,10,2,14,gold);poly([(11,17),(5,14),(3,9),(8,9),(12,13),(15,7),(21,5),(20,11),(16,15)],green)
                    poly([(6,10),(11,14),(11,16),(5,12)],lightGreen);poly([(13,13),(19,7),(18,11),(14,15)],lightGreen)
                    rect(25,3,2,6,bright);rect(23,5,6,2,bright)
                case "炼金室", "熬制魔药", "flask", "alchemy":
                    poly([(12,2),(21,2),(21,6),(20,7),(20,14),(28,25),(27,29),(5,29),(4,25),(13,14),(13,7),(12,6)],outline)
                    rect(13,3,7,3,gold);rect(14,3,5,1,bright);rect(15,7,3,8,glass)
                    poly([(14,15),(19,15),(25,24),(25,27),(7,27),(7,24)],glass)
                    poly([(11,20),(22,20),(25,25),(24,27),(8,27),(7,25)],purple)
                    rect(11,20,11,2,lightPurple);rect(10,18,2,7,cream);rect(16,24,2,2,cream)
                    rect(25,7,2,4,gold);rect(24,8,4,2,bright);rect(7,12,2,2,lightPurple)
                case "地图", "户外地图", "map", "worldmap":
                    poly([(3,5),(11,3),(21,6),(29,3),(29,26),(21,29),(11,26),(3,29)],outline)
                    poly([(5,7),(11,5),(20,8),(27,6),(27,24),(21,27),(11,24),(5,26)],paper)
                    poly([(5,7),(11,5),(11,24),(5,26)],cream);poly([(21,8),(27,6),(27,24),(21,27)],cream)
                    poly([(6,14),(9,10),(13,12),(17,10),(22,14),(26,12),(25,16),(21,17),(17,14),(12,16)],green)
                    poly([(14,7),(16,8),(15,13),(17,17),(15,23),(13,22),(15,17),(13,13)],glass)
                    rect(22,20,3,3,purple);rect(21,21,5,1,lightPurple);rect(10,6,1,17,gold);rect(20,8,1,18,gold)
                case "衣柜", "tshirt":
                    rect(5,3,23,27,outline);rect(6,4,21,24,gold);rect(8,6,17,20,green);rect(9,7,15,1,lightGreen)
                    rect(16,5,1,22,outline);rect(13,15,2,3,bright);rect(19,15,2,3,bright)
                    rect(7,28,3,3,gold);rect(23,28,3,3,gold);rect(6,4,21,1,bright);rect(6,6,1,20,paper)
                case "库存", "inventory", "archivebox":
                    poly([(4,8),(16,3),(29,9),(29,25),(16,30),(4,24)],outline)
                    poly([(6,9),(16,5),(26,9),(16,13)],cream);poly([(6,11),(15,15),(15,27),(6,23)],gold)
                    poly([(17,15),(27,11),(27,24),(17,27)],paper);poly([(11,7),(22,12),(22,16),(20,17),(20,13),(9,8)],green)
                    rect(8,18,4,3,cream);rect(18,23,2,2,gold)
                case "矿洞":
                    poly([(3,28),(4,16),(9,7),(17,2),(25,10),(29,20),(29,29)],outline)
                    poly([(5,27),(6,17),(10,9),(17,4),(23,11),(27,21),(27,27)],glass)
                    poly([(10,27),(10,20),(14,13),(19,13),(23,20),(23,27)],outline)
                    poly([(6,18),(10,11),(12,13),(8,21)],cream);poly([(21,10),(24,15),(22,16),(19,12)],purple)
                    rect(14,21,5,6,gold);rect(15,22,3,4,bright);rect(15,19,3,2,outline)
                case "首页", "小院", "home":
                    poly([(3,15),(16,3),(29,15),(26,17),(26,29),(6,29),(6,17)],outline)
                    poly([(5,14),(16,5),(27,14),(25,15),(16,8),(7,16)],green)
                    rect(8,16,16,11,paper);rect(9,16,6,1,cream);rect(16,20,6,8,outline);rect(17,21,4,7,gold)
                    rect(10,18,4,5,outline);rect(11,19,2,3,bright);rect(20,24,1,1,bright);rect(21,4,3,5,gold)
                case "采买", "market", "cart":
                    poly([(3,13),(29,13),(26,28),(7,28)],outline);poly([(5,15),(27,15),(24,26),(9,26)],gold)
                    rect(6,16,20,2,cream);rect(8,22,17,2,paper);rect(11,18,2,8,paper);rect(20,18,2,8,paper)
                    poly([(8,13),(12,4),(14,4),(10,13)],outline);poly([(23,13),(19,4),(21,4),(26,13)],outline)
                    rect(12,3,9,2,gold);rect(13,3,7,1,bright)
                case "配方册", "recipes":
                    poly([(3,6),(14,7),(16,9),(19,7),(29,6),(29,27),(18,28),(16,30),(13,28),(3,27)],outline)
                    poly([(5,8),(13,9),(15,11),(15,27),(12,26),(5,25)],cream);poly([(17,11),(20,9),(27,8),(27,25),(20,26),(17,27)],paper)
                    rect(7,12,5,1,gold);rect(7,16,6,1,gold);rect(7,20,5,1,gold)
                    poly([(19,18),(20,14),(23,12),(25,15),(25,19),(23,21),(20,21)],green);rect(21,13,2,2,lightGreen)
                case "商店", "storefront":
                    rect(5,12,22,18,outline);rect(7,14,18,14,paper);rect(8,16,10,9,outline)
                    rect(9,17,8,6,glass);rect(10,17,1,6,cream);rect(9,24,8,2,gold)
                    rect(20,16,4,12,outline);rect(21,17,2,11,green);rect(21,23,1,1,bright)
                    poly([(3,12),(7,4),(25,4),(29,12),(29,15),(3,15)],outline)
                    poly([(5,12),(8,6),(24,6),(27,12),(27,13),(5,13)],cream)
                    poly([(10,6),(13,6),(12,13),(8,13)],green);poly([(18,6),(21,6),(24,13),(20,13)],green)
                    rect(8,5,16,1,bright);rect(4,14,24,2,gold)
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
    var backTitle = "返回上一级"
    var back: (() -> Void)? = nil
    var close: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            if let back {
                Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width:44,height:40).contentShape(Rectangle()) }
                    .buttonStyle(.plain).foregroundStyle(Palette.goldLight).help(backTitle).accessibilityLabel(backTitle)
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
