import SwiftUI

struct ThemePreview: View {
    var theme: AppTheme
    private var colors: ThemeColors { ThemeColors(theme) }
    var body: some View {
        Group {
            switch theme {
            case .y2k: chromePreview
            case .liquidGlass: glassPreview
            case .christmas: holidayPreview
            case .original: originalPreview
            }
        }.frame(maxWidth:.infinity).frame(height:166)
            .clipShape(PixelFrame(theme:theme))
            .environment(\.colorScheme,theme == .original ? .dark:.light)
            .accessibilityElement(children:.ignore).accessibilityLabel(theme.name+"主题预览")
    }
    private var originalPreview: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:9) {
                if theme == .original { Image(systemName:"sparkles").foregroundStyle(colors.goldLight) }
                else { ThemeIcon(name:"主题",size:25,theme:theme) }
                Text(theme.name).font(.system(size:17,weight:.semibold)).foregroundStyle(colors.ink)
                Spacer()
                Circle().fill(colors.sage).frame(width:6,height:6)
            }
            HStack(alignment:.top,spacing:10) {
                VStack(alignment:.leading,spacing:7) {
                    Text("今日事项").font(.system(size:11,weight:.medium)).foregroundStyle(colors.muted)
                    HStack(spacing:5) {
                        Image(systemName:"checkmark.circle.fill").font(.system(size:10)).foregroundStyle(colors.sage)
                        Text("整理书房").font(.system(size:12)).foregroundStyle(colors.ink)
                    }
                    Rectangle().fill(colors.line.opacity(0.4)).frame(height:1)
                    Text("25:00").font(.system(size:22,weight:.medium,design:.rounded)).monospacedDigit().foregroundStyle(colors.goldLight)
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(spacing:10) {
                    ForEach(["日程","农场"],id:\.self) { name in
                        if theme == .original { Image(systemName:name == "日程" ? "calendar":"leaf.fill").foregroundStyle(colors.goldLight).frame(width:24,height:24) }
                        else { ThemeIcon(name:name,size:24,theme:theme) }
                    }
                }.padding(10).background(colors.control,in:RoundedRectangle(cornerRadius:theme == .original ? 2:10))
            }
        }.padding(16).frame(maxWidth:.infinity,maxHeight:.infinity).background(colors.paper)
    }
    private var chromePreview: some View {
        VStack(spacing:9) {
            HStack(spacing:7) {
                ThemeIcon(name:"专注",size:20,theme:theme)
                Text("专注").font(.system(size:12,weight:.bold))
                Spacer()
                ForEach(0..<5) { n in Rectangle().fill(colors.line).frame(width:2,height:8+CGFloat(n%3)*3) }
            }
            HStack {
                Text("25:00").font(.system(size:30,weight:.medium,design:.monospaced)).foregroundStyle(Color(red:0.63,green:0.91,blue:0.98))
                Spacer()
                Text("整理书房").font(.system(size:11)).foregroundStyle(.white)
            }.padding(12).background(Color(red:0.09,green:0.14,blue:0.23),in:PixelFrame(theme:.y2k))
            HStack(spacing:6) {
                ForEach(["任务","日程","农场"],id:\.self) { name in
                    ThemeIcon(name:name,size:23,theme:theme).frame(maxWidth:.infinity).padding(5)
                        .background(LinearGradient(colors:[.white,colors.control,.white],startPoint:.top,endPoint:.bottom),in:PixelFrame(theme:theme))
                }
            }
        }.padding(12).foregroundStyle(colors.ink).frame(maxWidth:.infinity,maxHeight:.infinity)
            .background(LinearGradient(colors:[colors.card,colors.control,colors.paper],startPoint:.top,endPoint:.bottom))
    }
    private var glassPreview: some View {
        ZStack {
            LinearGradient(colors:[Color(red:0.75,green:0.84,blue:0.86),Color(red:0.91,green:0.89,blue:0.84)],startPoint:.topLeading,endPoint:.bottomTrailing)
            VStack(alignment:.leading,spacing:12) {
                HStack {
                    Text("今日事项").font(.system(size:17,weight:.bold))
                    Spacer()
                    Image(systemName:"plus").font(.system(size:13,weight:.semibold))
                }
                HStack {
                    Image(systemName:"checkmark.circle.fill").foregroundStyle(colors.sage)
                    Text("整理书房").font(.system(size:12))
                    Spacer()
                    Text("25:00").font(.system(size:12)).monospacedDigit().foregroundStyle(colors.muted)
                }.padding(12).background(.white.opacity(0.85),in:RoundedRectangle(cornerRadius:14))
                HStack {
                    ForEach(["任务","日程","农场"],id:\.self) { name in
                        ThemeIcon(name:name,size:22,theme:theme).frame(maxWidth:.infinity)
                    }
                }.padding(10).modifier(ThemeNavigationSurface(theme:.liquidGlass))
            }.padding(14).foregroundStyle(colors.ink)
        }
    }
    private var holidayPreview: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("今日事项").font(.system(size:16,weight:.semibold))
                Spacer()
                HolidaySprig().frame(width:70,height:30)
            }
            HStack(spacing:9) {
                ThemeIcon(name:"任务",size:25,theme:theme)
                Text("整理书房").font(.system(size:12))
                Spacer()
            }
            HStack {
                Text("25:00").font(.system(size:24,weight:.medium)).monospacedDigit()
                Spacer()
                ThemeIcon(name:"日程",size:27,theme:theme)
                ThemeIcon(name:"农场",size:27,theme:theme)
            }
        }.padding(15).foregroundStyle(colors.ink).frame(maxWidth:.infinity,maxHeight:.infinity)
            .background(ThemeSurface(color:colors.card,appearance:theme))
            .overlay(alignment:.leading) {Rectangle().fill(colors.goldLight).frame(width:4)}
    }
}

struct ThemeSettings: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:230,maximum:400))],alignment:.leading,spacing:16) {
            ForEach(AppTheme.allCases.filter {store.data.ownsTheme($0)}) { theme in
                VStack(alignment:.leading,spacing:12) {
                    ThemePreview(theme:theme)
                    HStack {
                        Text(theme.name).font(.system(size:15,weight:.medium))
                        Spacer()
                        Button(store.data.activeTheme == theme ? "使用中":"使用") {
                            _ = store.commitGameChange { $0.selectTheme(theme) }
                        }.buttonStyle(PixelButtonStyle(primary:store.data.activeTheme == theme))
                            .disabled(store.data.activeTheme == theme || store.storageLocked)
                            .accessibilityLabel((store.data.activeTheme == theme ? "使用中，":"使用主题，")+theme.name)
                    }
                }.padding(12).magicSurface(Palette.card,strong:store.data.activeTheme == theme)
            }
        }
    }
}

struct ThemeShop: View {
    @ObservedObject var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SceneDialog(preferred:CGSize(width:900,height:620)) {
            HStack {
                PixelIcon(name:"主题",size:26)
                Text("主题").font(.system(size:20,weight:.semibold))
                Spacer()
                Text(Money.text(store.data.garden.coins)).font(.callout).foregroundStyle(Palette.goldLight)
                Button("关闭") {dismiss()}
            }
        } content: {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:220,maximum:360))],alignment:.leading,spacing:14) {
                ForEach(AppTheme.allCases.filter {$0 != .original}) { theme in
                    let owned=store.data.ownsTheme(theme)
                    let unlocked=store.data.levelProgress.level >= theme.level
                    VStack(alignment:.leading,spacing:12) {
                        ThemePreview(theme:theme)
                        HStack {
                            Text(theme.name).font(.system(size:16,weight:.medium))
                            Spacer()
                            Text("等级 \(theme.level)").font(.caption).foregroundStyle(Palette.muted)
                        }
                        HStack {
                            Text(Money.text(theme.price)).font(.callout).foregroundStyle(Palette.goldLight)
                            Spacer()
                            Button(owned ? "已拥有" : !unlocked ? "未解锁" : "购买") {
                                if store.commitGameChange({$0.buyTheme(theme)}) {store.message="已购买「\(theme.name)」"}
                            }.buttonStyle(PixelButtonStyle(primary:!owned && unlocked))
                                .disabled(owned || !unlocked || store.data.garden.coins < theme.price || store.storageLocked)
                                .accessibilityLabel("购买主题，"+theme.name)
                        }
                        if !owned && unlocked && store.data.garden.coins < theme.price {
                            Text("余额不足").font(.caption).foregroundStyle(Palette.clay)
                        }
                    }.padding(12).magicSurface(Palette.card)
                }
            }
        } footer: {
            HStack {
                if !store.error.isEmpty {Text(store.error).font(.callout).foregroundStyle(Palette.clay)}
                Spacer()
            }.frame(minHeight:20)
        }
    }
}
