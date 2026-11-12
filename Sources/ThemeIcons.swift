import SwiftUI
import AppKit

struct ThemeSymbol: View {
    var systemName: String

    var body: some View {
        let theme = ThemeAppearance.shared.theme
        let symbol = theme == .original ? systemName : ThemeIcon.design(for: systemName).symbol(for: theme)
        let image = Image(systemName: symbol)
        switch theme {
        case .original:
            image
        case .y2k:
            image.symbolRenderingMode(.hierarchical)
        case .liquidGlass, .christmas:
            image.symbolRenderingMode(.monochrome)
        }
    }
}

struct ThemeIcon: View {
    var name: String
    var size: CGFloat
    var theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let design = Self.design(for: name)
        let symbol = design.symbol(for: theme)
        Group {
            switch theme {
            case .original:
                glyph(symbol).foregroundStyle(Color.primary)
            case .y2k:
                chromeIcon(symbol, accent: design.accent)
            case .liquidGlass:
                glyph(symbol, weight: .medium).foregroundStyle(Color.primary)
            case .christmas:
                printedIcon(symbol, accent: design.accent)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glyph(_ symbol: String, scale: CGFloat = 0.81, weight: Font.Weight = .semibold) -> some View {
        Image(systemName: symbol)
            .resizable()
            .symbolRenderingMode(.monochrome)
            .scaledToFit()
            .frame(width: size * scale, height: size * scale)
            .font(.system(size: size * scale, weight: weight))
    }

    private func chromeIcon(_ symbol: String, accent: Accent) -> some View {
        let ink = colorScheme == .dark ? Self.rgb(0xb9e8fc) : accent.chrome
        return glyph(symbol, scale: 0.82, weight: .bold).foregroundStyle(
            LinearGradient(stops: [
                .init(color: ink, location: 0),
                .init(color: size < 18 ? ink : Self.rgb(0x869cbb), location: 0.31),
                .init(color: ink, location: 0.44),
                .init(color: size < 18 ? ink : Self.rgb(0xe2f0fd), location: 0.46),
                .init(color: ink, location: 0.59),
                .init(color: colorScheme == .dark ? ink : Self.rgb(0x22254c), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    private func printedIcon(_ symbol: String, accent: Accent) -> some View {
        let ink = colorScheme == .dark ? Self.rgb(0xffe4ad) : accent.printedInk
        let cranberry = Self.rgb(0x9b263b)
        return glyph(symbol, scale: 0.82)
            .foregroundStyle(ink)
            .overlay {
                switch symbol {
                case "calendar.badge.checkmark" where size >= 24:
                    ribbon.fill(cranberry)
                        .frame(width: size * 0.35, height: size * 0.27)
                        .offset(x: size * 0.25, y: -size * 0.30)
                case "book.closed.fill" where size >= 24:
                    glyph("bookmark.fill", scale: 0.30)
                        .foregroundStyle(Self.rgb(0xc0803a))
                        .offset(x: size * 0.13, y: size * 0.19)
                case "envelope.fill" where size >= 18:
                    glyph("leaf.fill", scale: 0.32)
                        .foregroundStyle(Self.rgb(0xffefce))
                        .rotationEffect(.degrees(-28))
                        .offset(x: size * 0.15, y: size * 0.09)
                default:
                    EmptyView()
                }
            }
    }

    private var ribbon: Path {
        Path { path in
            path.move(to: CGPoint(x: 0.50, y: 0.36))
            path.addLines([CGPoint(x: 0.10, y: 0.04), CGPoint(x: 0.03, y: 0.61),
                           CGPoint(x: 0.37, y: 0.51), CGPoint(x: 0.20, y: 0.95),
                           CGPoint(x: 0.40, y: 0.81), CGPoint(x: 0.50, y: 0.92),
                           CGPoint(x: 0.53, y: 0.52), CGPoint(x: 0.69, y: 0.91),
                           CGPoint(x: 0.77, y: 0.75), CGPoint(x: 0.95, y: 0.77),
                           CGPoint(x: 0.62, y: 0.50), CGPoint(x: 0.97, y: 0.58),
                           CGPoint(x: 0.89, y: 0.03), CGPoint(x: 0.50, y: 0.36)])
            path.closeSubpath()
        }
        .applying(CGAffineTransform(scaleX: size * 0.35, y: size * 0.27))
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255,
              blue: Double(hex & 255) / 255)
    }

    enum Accent {
        case aqua, lilac, rose, mint, gold, silver, copper

        fileprivate var chrome: Color {
            switch self {
            case .aqua: return rgb(0x00658f)
            case .lilac: return rgb(0x4b388c)
            case .rose: return rgb(0x8b236d)
            case .mint: return rgb(0x076c62)
            case .gold: return rgb(0x70532a)
            case .silver: return rgb(0x4f647f)
            case .copper: return rgb(0x914631)
            }
        }

        fileprivate var printedInk: Color {
            switch self {
            case .aqua, .mint: return rgb(0x28513d)
            case .lilac, .rose: return rgb(0x8b2940)
            case .gold: return rgb(0x805722)
            case .silver: return rgb(0x4c6372)
            case .copper: return rgb(0x874831)
            }
        }
    }

    struct Design: Equatable {
        var chrome: String
        var glass: String
        var printed: String
        var accent: Accent

        func symbol(for theme: AppTheme) -> String {
            switch theme {
            case .original, .liquidGlass: return glass
            case .y2k: return chrome
            case .christmas: return printed
            }
        }
    }

    static func design(for name: String) -> Design {
        if let design = designs[name] { return design }
        if let route = name.split(separator: "/").first, let design = designs[String(route)] { return design }
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
            return Design(chrome: name, glass: name, printed: name, accent: .aqua)
        }
        return Design(chrome: "pawprint.fill", glass: "pawprint", printed: "pawprint.fill", accent: .lilac)
    }

    static let designs: [String: Design] = {
        let entries: [(String, String, String, Accent, [String])] = [
            ("pawprint.fill", "pawprint", "bird.fill", .rose, ["桌宠", "菜单", "person.crop.square"]),
            ("xmark", "xmark", "xmark", .rose, ["close", "xmark"]),
            ("checkmark", "checkmark", "checkmark", .mint, ["check", "checkmark"]),
            ("chevron.down", "chevron.down", "chevron.down", .aqua, ["down", "chevron.down"]),
            ("chevron.up", "chevron.up", "chevron.up", .aqua, ["chevron.up"]),
            ("chevron.left", "chevron.left", "chevron.left", .aqua, ["back", "chevron.left"]),
            ("chevron.right", "chevron.right", "chevron.right", .aqua, ["forward", "chevron.right"]),
            ("stopwatch.fill", "hourglass", "timer", .rose, ["计时器", "专注", "记录专注", "timer", "专注与提醒", "hourglass"]),
            ("rectangle.and.pencil.and.ellipsis", "book.closed", "book.closed.fill", .rose, ["日记", "book.closed"]),
            ("externaldrive.fill", "externaldrive", "archivebox.fill", .gold, ["存档", "存档与备份", "externaldrive"]),
            ("checklist", "list.bullet.clipboard", "list.clipboard.fill", .lilac, ["任务", "待办", "checklist"]),
            ("calendar.badge.clock", "calendar", "calendar.badge.checkmark", .aqua, ["日程", "日历", "calendar"]),
            ("square.grid.2x2.fill", "square.grid.2x2", "square.split.2x2.fill", .lilac, ["四象限", "square.grid.2x2"]),
            ("carrot.fill", "carrot", "carrot.fill", .mint, ["农场", "carrot", "胡萝卜"]),
            ("tray.2.fill", "tray.2", "envelope.fill", .mint, ["种子柜", "seed-cabinet"]),
            ("leaf.fill", "leaf", "leaf.fill", .gold, ["小麦"]),
            ("circle.hexagongrid.fill", "circle.hexagongrid", "circle.inset.filled", .rose, ["番茄"]),
            ("leaf.fill", "leaf", "leaf.fill", .mint, ["习惯", "leaf", "幼苗"]),
            ("frying.pan.fill", "frying.pan", "fork.knife", .rose, ["厨房", "frying.pan"]),
            ("books.vertical.fill", "books.vertical", "book.fill", .aqua, ["书房", "study"]),
            ("hare.fill", "hare", "bird.fill", .mint, ["牧场"]),
            ("pawprint.fill", "pawprint", "basket.fill", .mint, ["动物商店"]),
            ("mug.fill", "mug", "wineglass.fill", .gold, ["酒馆", "酒馆与装备", "tavern"]),
            ("wrench.and.screwdriver.fill", "hammer", "hammer.fill", .gold, ["锻造室", "forge"]),
            ("arrow.up.forward", "chart.line.uptrend.xyaxis", "star.fill", .lilac, ["成长", "growth", "sparkles"]),
            ("eyedropper.halffull", "flask", "flask.fill", .lilac, ["炼金室", "熬制魔药", "flask", "alchemy"]),
            ("waterbottle.fill", "waterbottle", "waterbottle.fill", .lilac, ["药瓶"]),
            ("location.fill.viewfinder", "map", "map.fill", .aqua, ["地图", "户外地图", "map", "worldmap"]),
            ("tshirt.fill", "tshirt", "tshirt.fill", .rose, ["衣柜", "tshirt"]),
            ("shippingbox.fill", "shippingbox", "gift.fill", .gold, ["库存", "inventory", "archivebox", "shippingbox"]),
            ("mountain.2.fill", "mountain.2", "diamond.fill", .aqua, ["矿洞"]),
            ("house.fill", "house", "house.fill", .rose, ["首页", "小院", "小屋", "home"]),
            ("cart.fill", "cart", "bag.fill", .rose, ["采买", "market", "cart"]),
            ("book.fill", "book", "menucard.fill", .rose, ["配方册", "recipes"]),
            ("storefront.fill", "storefront", "storefront.fill", .rose, ["商店", "storefront"]),
            ("chart.bar.xaxis", "chart.bar", "chart.bar.fill", .aqua, ["统计", "chart.bar"]),
            ("slider.horizontal.3", "gearshape", "gearshape.fill", .lilac, ["设置", "settings", "slider.horizontal.3", "通用"]),
            ("water.waves", "fish", "fish.fill", .aqua, ["池塘", "fish", "鱼类图鉴"]),
            ("figure.fishing", "fish", "figure.fishing", .aqua, ["湖畔钓鱼", "钓鱼", "渔具", "tackle", "渔具店"]),
            ("tree.fill", "tree", "tree.fill", .mint, ["后院", "garden"]),
            ("backpack.fill", "location.north.line", "backpack.fill", .mint, ["林间冒险", "探险", "出发探险", "背包", "backpack"]),
            ("cpu.fill", "atom", "wand.and.stars", .aqua, ["AI 服务", "ai", "AI 预设"]),
            ("text.bubble.fill", "text.bubble", "bubble.left.and.bubble.right.fill", .rose, ["表达与提示词", "text.bubble", "台词与表情"]),
            ("clock.arrow.circlepath", "clock", "clock.fill", .lilac, ["上次结果", "上次制作", "clock"]),
            ("keyboard.fill", "keyboard", "keyboard.fill", .aqua, ["keyboard", "操作计数"]),
            ("bell.fill", "bell", "bell.fill", .gold, ["bell"]),
            ("checkmark.circle.fill", "checkmark.circle", "checkmark.seal.fill", .mint, ["checkmark.circle"]),
            ("swatchpalette.fill", "paintpalette", "paintbrush.fill", .rose, ["主题", "外观", "主题商店", "主题衣橱"]),
            ("sun.max.fill", "sun.haze", "snowflake", .gold, ["天气"]),
            ("sidebar.left", "sidebar.left", "sidebar.left", .aqua, ["sidebar.left"]),
            ("lock.shield.fill", "lock", "lock.fill", .gold, ["lock.fill"]),
            ("play.fill", "play", "play.fill", .mint, ["play.fill"]),
            ("play.circle.fill", "play.circle", "play.circle.fill", .mint, ["play.circle"]),
            ("pause.fill", "pause", "pause.fill", .gold, ["pause.fill"]),
            ("stop.fill", "stop", "stop.fill", .rose, ["stop.fill"]),
            ("ellipsis", "ellipsis", "ellipsis", .aqua, ["ellipsis"]),
            ("trash.fill", "trash", "trash", .rose, ["trash"]),
            ("pencil.tip", "pencil", "pencil", .rose, ["pencil"]),
            ("magnifyingglass", "magnifyingglass", "magnifyingglass", .aqua, ["magnifyingglass"]),
            ("minus.circle.fill", "minus.circle", "minus.circle.fill", .rose, ["minus.circle"]),
            ("list.bullet.rectangle.fill", "list.bullet.rectangle", "list.bullet.rectangle.fill", .lilac, ["list.bullet.rectangle"]),
            ("exclamationmark.circle.fill", "exclamationmark.circle", "exclamationmark.circle.fill", .gold, ["exclamationmark.circle", "exclamationmark.circle.fill"]),
            ("info.circle.fill", "info.circle", "info.circle.fill", .aqua, ["info.circle"]),
            ("checkmark.circle.fill", "checkmark.circle.fill", "checkmark.seal.fill", .mint, ["checkmark.circle.fill"]),
            ("circle", "circle", "circle", .aqua, ["circle"]),
            ("seal", "seal", "seal", .gold, ["seal"]),
            ("seal.fill", "seal.fill", "seal.fill", .gold, ["seal.fill"]),
            ("drop.degreesign.fill", "drop.degreesign", "drop.fill", .aqua, ["煮"]),
            ("frying.pan.fill", "frying.pan", "frying.pan.fill", .rose, ["炒"]),
            ("humidity.fill", "humidity", "cloud.fill", .aqua, ["蒸"]),
            ("oven.fill", "oven", "flame.fill", .gold, ["烘烤"]),
            ("arrow.triangle.2.circlepath", "arrow.clockwise", "fork.knife", .mint, ["拌合"]),
            ("cup.and.saucer.fill", "cup.and.saucer", "cup.and.saucer.fill", .rose, ["冲泡"]),
            ("leaf.arrow.circlepath", "leaf", "leaf.circle.fill", .mint, ["土地培育"]),
            ("drop.triangle.fill", "drop.triangle", "drop.fill", .aqua, ["浇水工具"]),
            ("cooktop.fill", "cooktop", "fork.knife", .rose, ["烹饪工具"]),
            ("location.north.line.fill", "location.north.line", "flag.2.crossed.fill", .lilac, ["探险工具"]),
            ("paintbrush.pointed.fill", "paintbrush.pointed", "paintbrush.fill", .rose, ["店面装潢"]),
            ("arrow.up.left.and.arrow.down.right", "arrow.up.left.and.arrow.down.right", "carrot.fill", .mint, ["扩张农场"]),
            ("storefront.fill", "storefront", "bag.fill", .rose, ["扩张店面"]),
            ("figure.fishing", "fish", "figure.fishing", .aqua, ["钓竿"]),
            ("circle.circle.fill", "circle.circle", "medal.fill", .gold, ["金加隆"]),
            ("circle.dotted.circle.fill", "circle.dotted.circle", "circle.dotted.circle.fill", .silver, ["银西可"]),
            ("circle.inset.filled", "smallcircle.filled.circle", "circle.hexagonpath.fill", .copper, ["铜纳特"]),
            ("water.waves", "water.waves", "fish.fill", .aqua, ["暮色湖", "芦苇湿地", "河谷缓流", "清流上游", "潮间海岸", "雨林水湾", "冷流海域", "暖流远洋", "极地近岸", "珊瑚潟湖", "深海崖岸", "河谷", "海滩"]),
            ("tree.fill", "tree", "tree.fill", .mint, ["森林", "雨林"]),
            ("mountain.2.fill", "mountain.2", "snowflake", .aqua, ["群山", "高山湖区", "冰原湖", "云雾高地", "极地"]),
            ("building.columns.fill", "building.columns", "building.columns.fill", .gold, ["古塔遗迹"])
        ]
        return Dictionary(uniqueKeysWithValues: entries.flatMap { chrome, glass, printed, accent, names in
            let design = Design(chrome: chrome, glass: glass, printed: printed, accent: accent)
            return names.map { ($0, design) }
        })
    }()
}
