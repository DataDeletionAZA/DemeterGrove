import SwiftUI
import AppKit

struct ThemeLabel: View {
    var title: String
    var systemImage: String
    init(_ title: String, systemImage: String) { self.title=title; self.systemImage=systemImage }
    var body: some View {
        Label {Text(title)} icon: {ThemeSymbol(systemName:systemImage)}
    }
}

struct ThemeSurface: View {
    var color: Color
    var strong = false
    var appearance: AppTheme? = nil
    private var theme: AppTheme { appearance ?? ThemeAppearance.shared.theme }
    var body: some View {
        let colors = ThemeColors(theme)
        let shape = PixelFrame(theme:theme)
        ZStack {
            shape.fill(color)
            switch theme {
            case .original:
                shape.strokeBorder(strong ? colors.gold : colors.line,lineWidth:1)
                shape.inset(by:3).strokeBorder(strong ? colors.gold.opacity(0.33) : colors.line.opacity(0.28),lineWidth:1)
            case .y2k:
                shape.strokeBorder(colors.line,lineWidth:1)
                shape.inset(by:1).strokeBorder(LinearGradient(colors:[.white,.white.opacity(0.15),colors.line.opacity(0.5)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1)
                if strong {
                    HStack(spacing:3) {
                        ForEach(0..<3) { _ in Rectangle().fill(colors.gold).frame(width:12,height:3) }
                        Spacer()
                    }.padding(8).frame(maxHeight:.infinity,alignment:.top)
                }
            case .liquidGlass:
                shape.strokeBorder(.white.opacity(0.48),lineWidth:0.5)
            case .christmas:
                shape.strokeBorder(colors.line.opacity(0.7),lineWidth:0.7)
                shape.inset(by:4).strokeBorder(colors.line.opacity(0.3),style:StrokeStyle(lineWidth:0.6,dash:[2,4]))
                if strong {
                    HolidaySprig().frame(width:58,height:30).padding(.trailing,9)
                        .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topTrailing)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ThemeButtonSurface: ViewModifier {
    var primary: Bool
    var pressed: Bool
    private var theme: AppTheme { ThemeAppearance.shared.theme }
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        switch theme {
        case .liquidGlass:
            if #available(macOS 26.0, *), !reduceTransparency {
                content.glassEffect(primary ? .regular.tint(Color.accentColor.opacity(0.16)).interactive() : .regular.interactive(), in:.capsule)
            } else {
                content.background(primary ? Palette.moss : Palette.control,in:Capsule())
            }
        case .y2k:
            content.background {
                PixelFrame().fill(LinearGradient(stops:[
                    .init(color:primary ? Color(red:0.78,green:0.88,blue:1) : .white,location:0),
                    .init(color:primary ? Palette.moss : Palette.control,location:0.48),
                    .init(color:primary ? Color(red:0.59,green:0.71,blue:0.87) : Color(red:0.68,green:0.73,blue:0.81),location:0.51),
                    .init(color:primary ? Palette.moss : Palette.card,location:1)
                ],startPoint:pressed ? .bottom:.top,endPoint:pressed ? .top:.bottom))
                PixelFrame().strokeBorder(Palette.line,lineWidth:1)
                PixelFrame().inset(by:2).strokeBorder(.white.opacity(0.75),lineWidth:0.7)
            }
        case .christmas:
            content.background {
                PixelFrame().fill(primary ? Color(red:0.54,green:0.16,blue:0.21) : Palette.card)
                    .shadow(color:.black.opacity(pressed ? 0:0.12),radius:0,x:0,y:2)
                PixelFrame().inset(by:3).strokeBorder(primary ? Color(red:0.87,green:0.73,blue:0.48) : Palette.line,style:StrokeStyle(lineWidth:0.7,dash:[3,3]))
            }
        case .original:
            content.background {
                PixelFrame(step:2).fill(pressed ? Palette.paper : primary ? Palette.moss : Palette.control)
                    .overlay(PixelFrame(step:2).strokeBorder(primary ? Palette.gold : Palette.line,lineWidth:1))
            }.overlay(alignment:.bottom) {
                Rectangle().fill(.black.opacity(pressed ? 0:0.35)).frame(height:2).padding(.horizontal,4)
            }
        }
    }
}

struct ThemeHeaderSurface: View {
    var body: some View {
        ZStack(alignment:.bottom) {
            Palette.paper
            switch ThemeAppearance.shared.theme {
            case .y2k:
                LinearGradient(stops:[.init(color:.white,location:0),.init(color:Palette.paper,location:0.5),.init(color:Palette.control,location:0.51),.init(color:Palette.card,location:1)],startPoint:.top,endPoint:.bottom)
                Rectangle().fill(Palette.line).frame(height:1)
            case .christmas:
                Rectangle().fill(Palette.card)
                GeometryReader { proxy in
                    HStack {
                        HolidaySprig().frame(width:proxy.size.height < 60 ? 36:68,height:proxy.size.height < 60 ? 16:30)
                        Spacer()
                        HolidaySprig().scaleEffect(x:-1,y:1).frame(width:proxy.size.height < 60 ? 36:68,height:proxy.size.height < 60 ? 16:30)
                    }.padding(.horizontal,55).frame(maxHeight:.infinity,alignment:.bottom).opacity(0.9)
                }
                Rectangle().fill(Palette.gold.opacity(0.35)).frame(height:1)
            case .liquidGlass:
                LinearGradient(colors:[.white.opacity(0.45),.clear],startPoint:.top,endPoint:.bottom)
            case .original:
                Rectangle().fill(Palette.gold.opacity(0.6)).frame(height:1).padding(.horizontal,10)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ThemeNavigationSurface: ViewModifier {
    var theme: AppTheme = ThemeAppearance.shared.theme
    var framed = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if theme == .liquidGlass, #available(macOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular,in:.rect(cornerRadius:24))
        } else {
            content.background {
                if theme == .original && !framed { Palette.paper }
                else if theme == .original {ThemeSurface(color:Palette.card,strong:true)}
                else {ThemeSurface(color:ThemeColors(theme).card,appearance:theme)}
            }
        }
    }
}

struct ThemeToolbarSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content:Content) -> some View {
        if ThemeAppearance.shared.theme == .liquidGlass, #available(macOS 26.0,*), !reduceTransparency {
            content.glassEffect(.regular.interactive(),in:.circle)
        } else { content }
    }
}

struct ThemeMenuButtonStyle: ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        if ThemeAppearance.shared.theme == .liquidGlass {
            configuration.label.padding(.horizontal,12).padding(.vertical,9)
                .background(.white.opacity(configuration.isPressed ? 0.7:0.28),in:RoundedRectangle(cornerRadius:14))
                .contentShape(Rectangle())
        } else {PixelButtonStyle().makeBody(configuration:configuration)}
    }
}

struct HolidaySprig: View {
    var body: some View {
        Canvas { context,size in
            context.scaleBy(x:size.width/100,y:size.height/44)
            func leaf(_ x:CGFloat,_ y:CGFloat,_ angle:Double,_ dark:Bool) {
                var leafContext=context
                leafContext.translateBy(x:x,y:y); leafContext.rotate(by:.degrees(angle))
                var p=Path()
                p.move(to:.zero); p.addQuadCurve(to:CGPoint(x:29,y:0),control:CGPoint(x:16,y:-15))
                p.addQuadCurve(to:.zero,control:CGPoint(x:16,y:15))
                leafContext.fill(p,with:.color(dark ? Color(red:0.15,green:0.32,blue:0.23):Color(red:0.28,green:0.45,blue:0.30)))
                var vein=Path();vein.move(to:CGPoint(x:2,y:0));vein.addLine(to:CGPoint(x:25,y:0))
                leafContext.stroke(vein,with:.color(Color(red:0.73,green:0.70,blue:0.43)),lineWidth:0.65)
            }
            leaf(42,26,-155,true);leaf(36,23,-90,false);leaf(48,24,-32,true)
            leaf(61,27,-10,false);leaf(30,28,-175,false)
            for (x,y) in [(43.0,28.0),(50.0,31.0),(48.0,23.0)] {
                context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:7,height:7)),with:.color(Color(red:0.65,green:0.18,blue:0.23)))
                context.fill(Path(ellipseIn:CGRect(x:x+1,y:y+1,width:1.7,height:1.7)),with:.color(Color(red:0.96,green:0.67,blue:0.56)))
            }
            var ribbon=Path();ribbon.addLines([CGPoint(x:49,y:34),CGPoint(x:60,y:42),CGPoint(x:64,y:38),CGPoint(x:69,y:39),CGPoint(x:54,y:30)])
            ribbon.closeSubpath();context.fill(ribbon,with:.color(Color(red:0.53,green:0.16,blue:0.21)))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct ThemeGlassBackdrop: NSViewRepresentable {
    var enabled: Bool
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.isHidden = !enabled
    }
}

struct ThemeRoot: ViewModifier {
    @ObservedObject var store: GardenStore
    var backdrop: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content
            .background {
                if backdrop && store.data.activeTheme == .liquidGlass {
                    if reduceTransparency { Color(red:0.91,green:0.95,blue:0.98) }
                    else { ThemeGlassBackdrop(enabled:true).allowsHitTesting(false) }
                }
            }
            .preferredColorScheme(store.data.activeTheme == .original ? .dark : .light)
            .onChange(of:store.data.activeTheme,initial:true) { _,theme in
                ThemeAppearance.shared.theme = theme
            }
    }
}

extension View {
    func appTheme(_ store: GardenStore, backdrop: Bool = true) -> some View {
        modifier(ThemeRoot(store:store,backdrop:backdrop))
    }
}
