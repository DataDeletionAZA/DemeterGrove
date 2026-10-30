import SwiftUI
import AppKit

enum GameImages {
    static let backgrounds: [String:NSImage] = ["Garden", "Kitchen", "Shop", "Lake", "Forest", "Laboratory", "Courtyard", "Study"].reduce(into: [:]) { result, name in
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Game"), let image = NSImage(contentsOf: url) { result[name] = image }
    }
    static let sprites: [String:[NSImage]] = {
        guard let boundsURL = Bundle.main.url(forResource: "Bounds", withExtension: "json", subdirectory: "Game"),
              let data = try? Data(contentsOf: boundsURL), let bounds = try? JSONDecoder().decode([String:[[Int]]].self, from: data) else { return [:] }
        return bounds.reduce(into: [:]) { result, entry in
            guard let url = Bundle.main.url(forResource: entry.key, withExtension: "png", subdirectory: "Game"),
                  let source = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            result[entry.key] = entry.value.compactMap { box in
                guard box.count == 4, box[0] >= 0, box[1] >= 0, box[2] <= source.width, box[3] <= source.height else { return nil }
                return source.cropping(to: CGRect(x:box[0],y:box[1],width:box[2]-box[0],height:box[3]-box[1])).map {
                    NSImage(cgImage:$0,size:NSSize(width:$0.width,height:$0.height))
                }
            }
        }
    }()

    static let shelfFoods: [NSImage] = (sprites["Foods"] ?? []).compactMap { image in
        guard let source = image.cgImage(forProposedRect:nil,context:nil,hints:nil),
              let canvas = CGContext(data:nil,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,
                                     space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let scale = min(60.0/Double(source.width),60.0/Double(source.height))
        let width = Double(source.width)*scale, height = Double(source.height)*scale
        canvas.interpolationQuality = .none
        canvas.draw(source,in:CGRect(x:(64-width)/2,y:(64-height)/2,width:width,height:height))
        return canvas.makeImage().map { NSImage(cgImage:$0,size:NSSize(width:64,height:64)) }
    }

}

struct GameSprite: View {
    var sheet = "Items"
    var index: Int
    var size: CGFloat
    var body: some View {
        Group {
            if let sprites = sheet == "Shelf" ? GameImages.shelfFoods : GameImages.sprites[sheet], sprites.indices.contains(index) {
                Image(nsImage: sprites[index]).resizable().interpolation(.none).scaledToFit()
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct DisplayGlass: View {
    var body: some View {
        Canvas { context,size in
            let glass = CGRect(x:size.width*0.102,y:size.height*0.492,width:size.width*0.410,height:size.height*0.055)
            context.clip(to:Path(glass))
            context.fill(Path(glass),with:.color(Color(red:0.75,green:0.84,blue:0.88).opacity(0.12)))
            for x in [0.19,0.39] {
                var reflection=Path()
                reflection.move(to:CGPoint(x:size.width*x,y:glass.maxY))
                reflection.addLine(to:CGPoint(x:size.width*(x+0.035),y:glass.maxY))
                reflection.addLine(to:CGPoint(x:size.width*(x+0.08),y:glass.minY))
                reflection.addLine(to:CGPoint(x:size.width*(x+0.045),y:glass.minY))
                reflection.closeSubpath()
                context.fill(reflection,with:.color(.white.opacity(0.12)))
            }
            context.fill(Path(CGRect(x:size.width*0.322,y:glass.minY,width:size.width*0.009,height:glass.height)),with:.color(Color(red:0.52,green:0.34,blue:0.18)))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct IngredientArt: View {
    var name: String
    var size: CGFloat = 48
    private var slot: (String, Int) {
        switch name {
        case "胡萝卜": return ("Items",2)
        case "小麦": return ("Items",3)
        case "番茄": return ("Items",4)
        case "咖啡豆": return ("Bases",13)
        case "焙炒茶叶": return ("Ingredients",13)
        case "米饭":return ("Bases",0)
        case "面条":return ("Bases",1)
        case "面包":return ("Bases",2)
        case "蛋糕胚":return ("Bases",7)
        case "银鳞鱼","月光鱼","金纹鱼":return ("Equipment",8)
        default:
            let names = ["土豆","黄瓜","卷心菜","蘑菇","玉米","南瓜","草莓","薄荷","柠檬","大米","鸡蛋","牛奶","蜂蜜","茶叶","砂糖","可可","咖啡豆"]
            return ("Ingredients", min(15, names.firstIndex(of: name) ?? 0))
        }
    }
    var body: some View {
        if let crop = Crop(rawValue:name) { PlantArt(crop:crop,stage:4,size:size) }
        else { GameSprite(sheet: slot.0, index: slot.1, size: size) }
    }
}

struct PlantArt: View {
    var crop: Crop
    var stage: Int
    var size: CGFloat
    private var slot: (String, Int) {
        let index = Crop.allCases.firstIndex(of:crop.artCrop)!
        return (["PlantsA","PlantsB","PlantsC"][index/4], (index%4)*5)
    }
    var body: some View {
        Group {
        if stage == 4 { GameSprite(sheet:slot.0,index:slot.1+4,size:size) }
        else if let images = GameImages.sprites[slot.0], images.indices.contains(slot.1+stage) {
            let mature = images[slot.1+3].size
            let scale = size / max(mature.width,mature.height)
            let image = images[slot.1+stage]
            Image(nsImage:image).resizable().interpolation(.none)
                .frame(width:image.size.width*scale,height:image.size.height*scale)
                .frame(width:size,height:size,alignment:.bottom)
                .accessibilityHidden(true)
        }
        }.hueRotation(.degrees(crop == .starlightCarrot ? 65 : 0))
    }
}

struct HarvestEffect: View {
    var crop: Crop
    var date: Date
    var size: CGFloat
    var count = 2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval:0.05)) { timeline in
            let age = timeline.date.timeIntervalSince(date)
            if age >= 0 && age < 1.4 {
                VStack(spacing:2) {
                    PlantArt(crop:crop,stage:4,size:size)
                    Text("+\(count)").font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.goldLight)
                }.offset(y:reduceMotion ? 0 : -age*22).opacity(min(1,(1.4-age)*3))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct RoomBackdrop: View {
    var name: String
    var body: some View {
        if let image = GameImages.backgrounds[name] { Image(nsImage: image).resizable().interpolation(.none).scaledToFit() }
    }
}

struct SceneParticles: View {
    var steam = false
    var burst: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince1970
                if steam {
                    for i in 0..<7 {
                        let p = (time * 0.4 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.5 + sin(p*6 + Double(i))*0.18)
                        let y = size.height * (1-p)
                        context.fill(Path(ellipseIn: CGRect(x:x,y:y,width:4+p*5,height:3+p*4)), with:.color(.white.opacity((1-p)*0.38)))
                    }
                } else if let burst {
                    let age = timeline.date.timeIntervalSince(burst)
                    if age >= 0 && age < 1.4 {
                        for i in 0..<14 {
                            let angle = Double(i)*Double.pi/7
                            let x = size.width/2 + cos(angle)*age*size.width*0.35
                            let y = size.height/2 + sin(angle)*age*size.height*0.3 - age*12
                            context.fill(Path(CGRect(x:x,y:y,width:3,height:3)),with:.color(Palette.goldLight.opacity(1-age/1.4)))
                        }
                    }
                } else {
                    for i in 0..<7 {
                        let x = size.width * (0.06 + Double(i)*0.145) + sin(time*0.5+Double(i))*5
                        let y = size.height * (0.14 + Double((i*7)%11)/15) + cos(time*0.6+Double(i))*4
                        context.fill(Path(CGRect(x:x,y:y,width:2,height:2)),with:.color(Palette.goldLight.opacity(0.3+sin(time+Double(i))*0.2)))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ObjectButton<Content: View>: View {
    var label: String
    var action: () -> Void
    var embeddedInBackdrop = false
    var caption: String? = nil
    @ViewBuilder var content: Content
    @State private var hovered = false
    @State private var focused=false
    var body: some View {
        Button {
            if NSApp.keyWindow?.firstResponder is ObjectKeyboardView {NSApp.keyWindow?.makeFirstResponder(nil)}
            focused=false
            action()
        } label: {content.contentShape(Rectangle())}
            .buttonStyle(ObjectButtonStyle(hovered:hovered,embeddedInBackdrop:embeddedInBackdrop))
            .focusable(false)
            .focusEffectDisabled()
            .background(ObjectKeyboardFocus(focused:$focused,action:action))
            .overlay {if focused {PixelFrame().stroke(Palette.goldLight,lineWidth:1).allowsHitTesting(false)}}
            .overlay(alignment:.bottom) {
                if let caption, hovered || focused {
                    Text(caption).font(.system(size:12,weight:.medium)).foregroundStyle(Palette.goldLight)
                        .padding(.horizontal,9).padding(.vertical,5).background(Palette.paper,in:PixelFrame())
                        .offset(y:18).allowsHitTesting(false)
                }
            }
            .onHover { hovered = $0 }.help(label).accessibilityLabel(label)
    }
}

private struct ObjectKeyboardFocus:NSViewRepresentable {
    @Environment(\.isEnabled) private var enabled
    @Binding var focused:Bool
    var action:()->Void
    func makeNSView(context:Context)->ObjectKeyboardView {ObjectKeyboardView()}
    func updateNSView(_ view:ObjectKeyboardView,context:Context) {
        view.changed={focused=$0};view.action=action;view.enabled=enabled
        if !enabled,view.window?.firstResponder === view {view.window?.makeFirstResponder(nil)}
    }
}

private final class ObjectKeyboardView:NSView {
    private static let tabMonitor:Any?=NSEvent.addLocalMonitorForEvents(matching:.keyDown) {event in
        guard event.keyCode == 48,let window=event.window,
              window.firstResponder === window || window.firstResponder === window.contentView,
              let target=window.contentView?.nextValidKeyView as? ObjectKeyboardView,target.enabled else{return event}
        return window.makeFirstResponder(target) ? nil:event
    }
    var changed:(Bool)->Void={_ in}
    var action:()->Void={}
    var enabled=true
    override var acceptsFirstResponder:Bool {enabled}
    override var canBecomeKeyView:Bool {enabled}
    override func hitTest(_ point:NSPoint)->NSView? {nil}
    override func viewDidMoveToWindow() {super.viewDidMoveToWindow();_=Self.tabMonitor;DispatchQueue.main.async {[weak self] in self?.window?.recalculateKeyViewLoop()}}
    override func becomeFirstResponder()->Bool {guard enabled else{return false};changed(true);scrollToVisible(bounds);return true}
    override func resignFirstResponder()->Bool {changed(false);return true}
    override func keyDown(with event:NSEvent) {
        guard enabled else{return}
        if [36,49,76].contains(event.keyCode) {if !event.isARepeat {action()}}
        else if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {window?.selectPreviousKeyView(self)}
            else {window?.selectNextKeyView(self)}
        } else {super.keyDown(with:event)}
    }
}

private struct ObjectButtonStyle: ButtonStyle {
    var hovered: Bool
    var embeddedInBackdrop: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.19 : hovered ? 0.10 : 0)
            .scaleEffect(embeddedInBackdrop || reduceMotion ? 1 : configuration.isPressed ? 1.015 : hovered ? 1.035 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct SceneObjectArtwork: View {
    var object: SceneObject
    var sceneSize: CGSize
    var body: some View {
        let target = object.target
        let w = sceneSize.width, h = sceneSize.height
        Color.clear.overlay {
            if let image = GameImages.backgrounds[object.room] {
                Image(nsImage: image).resizable().interpolation(.none)
                    .frame(width: w, height: h)
                    .mask(object.outline.applying(CGAffineTransform(scaleX: w / 1536, y: h / 1024)))
                    .offset(x: w * (0.5 - target.x), y: h * (0.5 - target.y))
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
