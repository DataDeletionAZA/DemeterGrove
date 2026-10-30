import SwiftUI
import AppKit

struct RootView: View {
    @ObservedObject var store: GardenStore
    @State private var sidebarShown = true
    private let pages = [("首页", "house"), ("书房", "book.closed"), ("任务", "checklist"), ("专注", "timer"), ("日程", "calendar"),
                         ("习惯", "leaf"), ("日记", "book.closed"), ("农场", "carrot"), ("厨房", "frying.pan"), ("商店", "storefront"), ("成长", "sparkles"),
                         ("地图", "map"), ("衣柜", "tshirt"), ("统计", "chart.bar"), ("设置", "slider.horizontal.3")]
    private var sidebarPage: String { JourneyKind.allCases.contains { $0.rawValue == store.selectedPage } ? "地图" : store.selectedPage }
    var body: some View {
        HStack(spacing: 0) {
            if sidebarShown {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    PixelIcon(name: "药瓶", size: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("暮色小院").font(.system(size: 20, weight: .semibold, design: .default))
                    }
                }.padding(.bottom, 30).padding(.top, 15)
                PixelScrollView {
                VStack(spacing: 7) {
                ForEach(pages, id: \.0) { page in
                    Button { store.selectedPage = page.0 } label: {
                        HStack(spacing: 13) {
                            PixelIcon(name: page.1, size: 23)
                            Text(page.0).fontWeight(sidebarPage == page.0 ? .semibold : .regular)
                            Spacer()
                            if page.0 == "任务", !store.todayTasks.isEmpty {
                                Text("\(store.todayTasks.count)").font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Palette.control, in: PixelFrame())
                            }
                        }.padding(.horizontal, 13).padding(.vertical, 12)
                            .background(sidebarPage == page.0 ? Palette.moss.opacity(0.7) : .clear, in: PixelFrame())
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                }
                }
                Spacer(minLength: 24)
                HStack {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.sage).frame(width: 6, height: 6)
                    Text(store.storageLocked ? "存档需要恢复" : store.saveStatus).font(.caption)
                }.foregroundStyle(Palette.muted)
            }.padding(20).frame(width: 196).background(Palette.paper)
            Rectangle().fill(Palette.line).frame(width: 1)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Button { sidebarShown.toggle() } label: { Image(systemName: "sidebar.left").font(.system(size: 17)) }
                        .buttonStyle(.plain).help(sidebarShown ? "收起侧栏" : "展开侧栏").accessibilityLabel(sidebarShown ? "收起侧栏" : "展开侧栏")
                    if store.selectedPage != "首页" {
                        Button { store.selectedPage = "首页" } label: { Image(systemName: "house") }
                            .buttonStyle(.plain).help("回到小院").accessibilityLabel("回到小院")
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.selectedPage == "首页" ? "暮色小院" : store.selectedPage).font(.system(size: 23, weight: .semibold, design: .default))
                    }
                    Spacer()
                    Text(store.now.formatted(.dateTime.year().month().day().weekday(.wide)))
                        .font(.caption).foregroundStyle(Palette.muted)
                }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 20)
                if !store.error.isEmpty {
                    Label(store.error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.red)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.red.opacity(0.06)).padding(.horizontal, 30)
                }
                GeometryReader { viewport in
                PixelScrollView {
                    Group {
                        switch store.selectedPage {
                        case "首页": HomeScene(store: store)
                        case "书房": StudyScene(store: store)
                        case "任务", "四象限": TasksPage(store: store)
                        case "专注": FocusPage(store: store)
                        case "日程": SchedulePage(store: store)
                        case "习惯": HabitsPage(store: store)
                        case "日记": DiaryPage(store: store)
                        case "小院", "农场": FarmPage(store: store, section: "农场")
                        case "厨房": FarmPage(store: store, section: "厨房")
                        case "商店": FarmPage(store: store, section: "商店")
                        case "成长": GrowthPage(store: store)
                        case "地图", "湖畔钓鱼": MapPage(store: store, journey: .fishing)
                        case "林间冒险": MapPage(store: store, journey: .adventure)
                        case "熬制魔药": MapPage(store: store, journey: .potions)
                        case "衣柜": WardrobePage(store: store)
                        case "统计": StatsPage(store: store)
                        default: SettingsPage(store: store)
                        }
                    }.disabled(store.storageLocked && store.selectedPage != "设置")
                        .padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .topLeading)
                        .environment(\.sceneViewport, CGSize(width:max(200,viewport.size.width-48),height:max(180,viewport.size.height-24)))
                }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
        }.frame(minWidth: 560, minHeight: 400).environment(\.calendar,store.calendar).foregroundStyle(Palette.ink).tint(Palette.sage)
            .magicControls().environment(\.locale, Locale(identifier: "zh_CN"))
            .overlay {WindowResizeBorder(minimumContentSize:NSSize(width:560,height:400))}
    }
}

struct Card<Content: View>: View {
    var title: String
    var icon: String = ""
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            if !title.isEmpty {
                HStack(spacing: 8) {
                    if !icon.isEmpty { PixelIcon(name: icon, size: 23) }
                    Text(title).font(.system(size: 16, weight: .semibold))
                }
            }
            content
        }.padding(21).frame(maxWidth: .infinity, alignment: .leading)
            .magicSurface(Palette.paper)
    }
}

struct Metric: View {
    var title: String
    var value: String
    var foot: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 22, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(foot).font(.caption2).foregroundStyle(Palette.muted).frame(minHeight: 30, alignment: .topLeading)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .magicSurface(Palette.paper)
    }
}

struct EmptyNote: View {
    var text: String
    var body: some View { Text(text).foregroundStyle(Palette.muted).font(.callout).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading) }
}
