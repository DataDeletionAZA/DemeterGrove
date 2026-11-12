import SwiftUI

struct MiningScene: View {
    @ObservedObject var store: GardenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var area: String
    @State private var tab = "矿层"
    @State private var highlighted: String?
    private let areas = MineLayer.areas
    init(store: GardenStore, initialArea: String? = nil) {
        self.store = store
        let startingArea = initialArea.flatMap { MineLayer.areas.contains($0) ? $0 : nil } ?? "旧矿场"
        _area = State(initialValue: startingArea)
        _highlighted = State(initialValue: MineLayer.visible(in: startingArea, highlighted: nil, selected: store.data.miningState.selectedLayer).id)
    }
    private var mining: MiningState { store.data.miningState }
    private var layers: [MineLayer] { MineLayer.layers(in: area) }
    private var focus: Double { store.gameFocus }
    private var working: Bool { store.data.timer.map { $0.kind != .rest && $0.resumedAt != nil } ?? false }
    private var inspected: MineLayer { MineLayer.visible(in: area, highlighted: highlighted, selected: mining.selectedLayer) }
    var body: some View {
        VStack(alignment: .leading, spacing: SceneSizing.sectionGap) {
            SceneHeader {
                HStack(spacing: 12) {
                    PixelSelect(selection: $area, items: areas.map { ($0, $0) }).frame(width: 142)
                    Text("已开拓 \(mining.layers.count)/\(MineLayer.all.count)").font(.system(size: 12)).foregroundStyle(Palette.goldLight)
                    Spacer(minLength: 0)
                    WalletView(coins: store.data.garden.coins)
                }
                SceneToolbar(items: [
                    SceneToolbarItem("锻造室") { SceneNavigation.open("锻造室",store:store,from:store.currentRoute) },
                    SceneToolbarItem("酒馆") { SceneNavigation.open("酒馆",store:store,from:store.currentRoute) },
                    SceneToolbarItem("户外地图") { SceneNavigation.open("户外地图",store:store,from:store.currentRoute) },
                    SceneToolbarItem("专注") { SceneNavigation.open("计时器",store:store,from:store.currentRoute) }
                ])
            }
            SceneCanvas(hasSidebar: true) { size in
                cave(size)
            } sidebar: { cabinet }
        }.onChange(of: area) { _, area in
            highlighted = MineLayer.visible(in: area, highlighted: nil, selected: mining.selectedLayer).id
        }
    }

    private func cave(_ size: CGSize) -> some View {
        let w = size.width, h = size.height
        let layer = inspected
        let opening = mining.opening?.layerID == layer.id
        return ZStack {
            RoomBackdrop(name: layer.artworkName).frame(width: w, height: h)
            VStack(alignment: .leading, spacing: 4) {
                Text("第\(layer.depth)层 · " + layer.name).font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Text(layerStatus(layer)).font(.system(size: 11)).foregroundStyle(Palette.goldLight)
            }.frame(maxWidth: max(80, w * 0.38), alignment: .leading).padding(8).background(Palette.paper.opacity(0.94), in: PixelFrame())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(9).allowsHitTesting(false)
            ObjectButton(label: layer.name + "，" + layerStatus(layer), action: { tab = "矿层" }, caption: layer.mineral.name) {
                GameNatureSprite(key: layer.mineral.spriteKey, size: w * 0.14)
            }.position(x: w * 0.64, y: h * 0.56)
            if (mining.selectedLayer == layer.id || opening) && working {
                TimelineView(.animation(minimumInterval: 0.08, paused: reduceMotion)) { timeline in
                    GameNatureSprite(key: opening ? MiningTool.all[0].id : mining.tool.id, size: w * 0.12)
                        .rotationEffect(.degrees(reduceMotion ? -12 : sin(timeline.date.timeIntervalSinceReferenceDate * 5) * 23 - 12), anchor: .bottomTrailing)
                }.position(x: w * 0.73, y: h * 0.58).allowsHitTesting(false)
            }
            VStack {
                if layer.adjacent(-1) != nil {layerArrow(up: true, layer: layer)}
                Spacer(minLength: 0)
                layerArrow(up: false, layer: layer)
            }.padding(9)
        }.frame(width: w, height: h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65), lineWidth: 1))
    }

    private func layerArrow(up: Bool, layer: MineLayer) -> some View {
        let next = layer.adjacent(up ? -1 : 1)
        let label = next.map { (up ? "上行 · " : "下行 · ") + $0.name } ?? "已到最深层"
        return Button {
            if let next { highlighted = next.id; tab = "矿层" }
        } label: {
            Text(up ? "▲" : "▼").font(.system(size: 16)).foregroundStyle(Palette.goldLight)
                .frame(width: 34, height: 30).background(Palette.paper.opacity(0.94), in: PixelFrame())
        }.buttonStyle(.plain).disabled(!up && next == nil).opacity(!up && next == nil ? 0.45 : 1)
            .help(label).accessibilityLabel(label)
    }

    private var cabinet: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(area).font(.headline).foregroundStyle(Palette.goldLight)
            Text("第\(inspected.depth) / \(layers.count)层").font(.system(size: 11)).foregroundStyle(Palette.muted)
            PixelTabs(selection: $tab, items: [("矿层", "矿层"), ("矿石", "矿石"), ("矿镐", "矿镐")])
            PixelScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if tab == "矿层" { detail(inspected) }
                    else if tab == "矿石" { mineralShelf }
                    else { toolShelf }
                }.padding(.trailing, 2)
            }
            if tab == "矿石" { diamondButton }
        }.padding(10).magicSurface(Palette.paper)
    }

    private func detail(_ layer: MineLayer) -> some View {
        let opened = mining.layers[layer.id] != nil
        let opening = mining.opening?.layerID == layer.id
        let active = mining.selectedLayer == layer.id
        let required = layer.prerequisite.flatMap { id in MineLayer.all.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 8) {
            Text(layer.mineral.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.goldLight)
            Text(ItemLore.text(for: "mineral:" + layer.mineral.id) ?? "").font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            if opened {
                PixelProgress(value: progress(layer))
                Text("常规产出 · \(layer.cycleMinutes) 分钟 / 份").font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                Text(active ? "驻留加成 ×\(mining.residentRate(layer))" : "可驻留 · 产出 ×\(mining.residentRate(layer))").font(.system(size: 11)).foregroundStyle(Palette.goldLight)
                Button(active ? "结束驻留" : "在此驻留") {
                    if store.commitGameChange({ $0.selectMine(active ? nil : layer.id, at: store.now) }) { store.message = active ? "结束驻留" : "驻留 · " + layer.name }
                }.frame(maxWidth: .infinity)
            } else if opening {
                PixelProgress(value: progress(layer))
                Text("开拓中 · 还需 \(Int(ceil(Double(layer.unlockMinutes) * (1 - progress(layer))))) 分钟专注").font(.caption).foregroundStyle(Palette.goldLight).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("等级 \(layer.level) · 开拓 \(layer.unlockMinutes) 分钟").font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                if let required, mining.layers[required.id] == nil {
                    Text("前置矿层：" + required.name).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                }
                Button("开拓此层") {
                    if store.commitGameChange({ $0.openMine(layer.id, at: store.now) }) { store.message = "开始开拓 · " + layer.name }
                }.disabled(store.data.levelProgress.level < layer.level || mining.opening != nil || (required.map { mining.layers[$0.id] == nil } ?? false))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(8).magicSurface(Palette.card)
    }

    private var mineralShelf: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Mineral.all) { mineral in
                HStack(spacing: 7) {
                    GameNatureSprite(key: mineral.spriteKey, size: 33)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mineral.name).font(.system(size: 11))
                        Text("×\(mining.inventory[mineral.id, default: 0])").font(.system(size: 11)).foregroundStyle(Palette.goldLight)
                        Text(ItemLore.text(for: "mineral:" + mineral.id) ?? "").font(.system(size: 10)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 2)
            }
        }
    }

    private var toolShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolDetails(mining.tool)
            if let next = mining.nextTool {
                Divider().overlay(Palette.line)
                toolDetails(next)
                Text("等级 \(next.level) · \(Money.text(next.price))").font(.caption).foregroundStyle(Palette.goldLight)
                    .fixedSize(horizontal: false, vertical: true)
                Button("升级为\(next.name)") {
                    if store.commitGameChange({ $0.upgradeMiningTool(at: store.now) }) { store.message = "已换上\(next.name)" }
                }.buttonStyle(PixelButtonStyle(primary: true))
                    .disabled(store.data.levelProgress.level < next.level || store.data.garden.coins < next.price)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolDetails(_ tool: MiningTool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            GameNatureSprite(key: tool.id, size: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(tool.name).font(.system(size: 12, weight: .medium))
                if let lore = ItemLore.text(for: "pickaxe:" + tool.id) {
                    Text(lore).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                }
                Text("驻留产出倍率 +\(tool.bonus)").font(.caption).foregroundStyle(Palette.goldLight)
            }
        }
    }

    private var diamondButton: some View {
        Button {
            if store.commitGameChange({ $0.combineDiamond() }) { store.message = "合成钻石 ×1" }
        } label: {
            VStack(spacing: 3) { Text("合成钻石"); Text("10 碎片 → 1 钻石").font(.system(size: 10)) }.frame(maxWidth: .infinity)
        }.disabled(mining.inventory["diamond_shard", default: 0] < 10)
    }

    private func progress(_ layer: MineLayer) -> Double {
        if let opening = mining.opening, opening.layerID == layer.id {
            return min(1, max(0, (focus - opening.startedFocus) / Double(layer.unlockMinutes * 60)))
        }
        return (mining.layers[layer.id]?.work ?? 0) / Double(layer.cycleMinutes * 60)
    }
    private func layerStatus(_ layer: MineLayer) -> String {
        if mining.opening?.layerID == layer.id { return "开拓中" }
        if mining.selectedLayer == layer.id { return "驻留中" }
        if mining.layers[layer.id] != nil { return "已开拓" }
        return store.data.levelProgress.level < layer.level ? "等级 \(layer.level)" : "未开拓"
    }
}
