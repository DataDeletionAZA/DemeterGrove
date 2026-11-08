import SwiftUI

struct MiningScene: View {
    @ObservedObject var store: GardenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var area: String
    @State private var tab = "矿层"
    @State private var highlighted: String?
    private let areas = ["旧矿场", "群山矿洞", "火山矿洞", "极地矿洞"]
    init(store: GardenStore, initialArea: String? = nil) {
        self.store = store
        _area = State(initialValue: ["旧矿场", "群山矿洞", "火山矿洞", "极地矿洞"].contains(initialArea ?? "") ? initialArea! : "旧矿场")
    }
    private var mining: MiningState { store.data.miningState }
    private var layers: [MineLayer] { MineLayer.all.filter { $0.area == area } }
    private var focus: Double { store.gameFocus }
    private var working: Bool { store.data.timer.map { $0.kind != .rest && $0.resumedAt != nil } ?? false }
    private var inspected: MineLayer? {
        layers.first { $0.id == highlighted } ?? layers.first { $0.id == mining.selectedLayer } ?? layers.first
    }
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
                    SceneToolbarItem("铸造") { SceneNavigation.open("铸造", store: store) },
                    SceneToolbarItem("酒馆") { SceneNavigation.open("酒馆", store: store) },
                    SceneToolbarItem("户外地图") { SceneNavigation.open("户外地图", store: store) },
                    SceneToolbarItem("专注") { SceneNavigation.open("计时器", store: store) }
                ])
            }
            SceneCanvas(hasSidebar: true) { size in
                cave(size)
            } sidebar: { cabinet }
        }.onChange(of: area) { _, _ in highlighted = nil }
    }

    private func cave(_ size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            RoomBackdrop(name: "Mine").frame(width: w, height: h)
            SceneImageHotspot(background: "Mine", rect: CGRect(x: 0.015, y: 0.12, width: 0.15, height: 0.28), size: size, label: "回到户外地图") {
                SceneNavigation.open("户外地图", store: store)
            }
            ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                let point = orePoint(index)
                let opened = mining.layers[layer.id] != nil
                let opening = mining.opening?.layerID == layer.id
                ObjectButton(label: layer.name + "，" + layerStatus(layer), action: { highlighted = layer.id; tab = "矿层" }, caption: layer.name) {
                    GameNatureSprite(key: layer.mineral.spriteKey, size: w * 0.17)
                        .brightness(opened ? 0.05 : -0.18).opacity(opened || opening ? 1 : 0.75)
                }.position(x: w * point.x, y: h * point.y)
                if (mining.selectedLayer == layer.id || opening) && working {
                    TimelineView(.animation(minimumInterval: 0.08, paused: reduceMotion)) { timeline in
                        GameNatureSprite(key: "tool_pickaxe", size: w * 0.12)
                            .rotationEffect(.degrees(reduceMotion ? -12 : sin(timeline.date.timeIntervalSinceReferenceDate * 5) * 23 - 12), anchor: .bottomTrailing)
                    }.position(x: w * point.x + w * 0.085, y: h * point.y + w * 0.025).allowsHitTesting(false)
                }
            }
            HStack(spacing: -w * 0.012) {
                ForEach(Mineral.all.filter { mining.inventory[$0.id, default: 0] > 0 }.prefix(4)) { mineral in
                    ObjectButton(label: "查看" + mineral.name + "库存", action: { tab = "矿石" }, caption: mineral.name) {
                        GameNatureSprite(key: mineral.spriteKey, size: w * 0.075)
                    }
                }
            }.position(x: w * 0.62, y: h * 0.79)
            SceneArrows(store: store, scene: "矿洞")
        }.frame(width: w, height: h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65), lineWidth: 1))
    }

    private var cabinet: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(area).font(.headline).foregroundStyle(Palette.goldLight)
            PixelTabs(selection: $tab, items: [("矿层", "矿层"), ("矿石", "矿石")])
            if tab == "矿层", let inspected { detail(inspected) }
            PixelScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if tab == "矿层" {
                        ForEach(layers) { layer in layerCard(layer) }
                    } else { mineralShelf }
                }.padding(.trailing, 2)
            }
            if tab == "矿石" { diamondButton }
        }.padding(10).magicSurface(Palette.paper)
    }

    private func layerCard(_ layer: MineLayer) -> some View {
        Button { highlighted = layer.id } label: {
            HStack(spacing: 6) {
                GameNatureSprite(key: layer.mineral.spriteKey, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.name).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Text("第\(layer.depth)层 · " + layerStatus(layer)).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(PixelButtonStyle(primary: inspected?.id == layer.id))
    }

    private func detail(_ layer: MineLayer) -> some View {
        let opened = mining.layers[layer.id] != nil
        let opening = mining.opening?.layerID == layer.id
        let active = mining.selectedLayer == layer.id
        let required = layer.prerequisite.flatMap { id in MineLayer.all.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 8) {
            Text(layer.mineral.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.goldLight)
            if opened {
                PixelProgress(value: progress(layer))
                Text("常规产出 · \(layer.cycleMinutes) 分钟 / 份").font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                Text(active ? "驻留加成 ×\(layer.residentYield)" : "可驻留 · 产出 ×\(layer.residentYield)").font(.system(size: 11)).foregroundStyle(Palette.goldLight)
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
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 2)
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
    private func orePoint(_ index: Int) -> CGPoint {
        [CGPoint(x: 0.26, y: 0.43), CGPoint(x: 0.52, y: 0.48), CGPoint(x: 0.75, y: 0.40)][min(2, index)]
    }
}
