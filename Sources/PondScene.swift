import SwiftUI

struct PondScene: View {
    @ObservedObject var store: GardenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = "鱼群"
    @State private var market = false
    @State private var inventory = false
    @State private var selected: UUID?

    private var pond: PondState? { store.data.pondState }

    var body: some View {
        VStack(alignment: .leading, spacing: SceneSizing.sectionGap) {
            SceneHeader {
                HStack(spacing: 14) {
                    if let pond {
                        Text("鱼 \(pond.fish.count)/\(pond.capacity)").font(.system(size: 13))
                        Text("鱼粮 \(pond.feed) 份").font(.system(size: 13)).foregroundStyle(Palette.goldLight)
                    } else {
                        Text("池塘").font(.headline)
                    }
                    Spacer(minLength: 0)
                    WalletView(coins: store.data.garden.coins)
                }
                SceneToolbar(items: [
                    SceneToolbarItem("后院") { SceneNavigation.open("后院", store: store, from: "池塘") },
                    SceneToolbarItem("库存") { inventory = true },
                    SceneToolbarItem("专注") { SceneNavigation.open("计时器", store: store, from: "池塘") }
                ])
            }
            SceneCanvas(hasSidebar: true) { size in
                stage(size)
            } sidebar: {
                cabinet
            }
        }
        .sheet(isPresented: $market) { fishMarket }
        .sheet(isPresented: $inventory) { InventoryView(store: store) }
    }

    private func stage(_ size: CGSize) -> some View {
        ZStack {
            RoomBackdrop(name: "Pond").frame(width: size.width, height: size.height)
            if let pond {
                TimelineView(.animation(minimumInterval: 0.12, paused: reduceMotion)) { timeline in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        water(size, time: time)
                        ForEach(Array(pond.fish.enumerated()), id: \.element.id) { index, stock in
                            if let fish = stock.species?.fish {
                                let phase = time * (stock.fed && !stock.ready ? 0.65 : 0.38) + Double(index) * 1.7
                                let x = 0.29 + Double(index % 4) * 0.14 + 0.032 * sin(phase)
                                let y = 0.56 + Double(index / 4) * 0.085 + 0.013 * cos(phase * 0.72)
                                ObjectButton(label: fish.name + "，" + status(stock), action: { select(stock) }, caption: fish.name) {
                                    GameNatureSprite(key: fish.spriteKey, size: size.width * (stock.ready ? 0.076 : 0.063))
                                        .scaleEffect(x: cos(phase) < 0 ? -1 : 1, y: 1)
                                        .opacity(stock.id == selected || stock.ready ? 1 : 0.82)
                                }.position(x: size.width * x, y: size.height * y)
                            }
                        }
                    }.frame(width: size.width, height: size.height)
                }
            }
            SceneImageHotspot(background:"Pond",rect:CGRect(x:0.035,y:0.465,width:0.09,height:0.10),size:size,label:"鱼粮") {tab="鱼粮"}
            SceneImageHotspot(background:"Pond",rect:CGRect(x:0.17,y:0.12,width:0.085,height:0.20),size:size,label:"回到后院") {SceneNavigation.open("后院",store:store,from:"池塘")}
            SceneArrows(store: store, scene: "池塘")
        }
        .frame(width: size.width, height: size.height)
        .clipShape(PixelFrame())
        .overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65), lineWidth: 1).allowsHitTesting(false))
    }

    private func water(_ size: CGSize, time: TimeInterval) -> some View {
        Canvas { context, _ in
            for index in 0..<9 {
                let phase = time * 0.57 + Double(index) * 1.27
                let x = floor(size.width * (0.26 + Double(index % 5) * 0.108 + 0.013 * sin(phase)))
                let y = floor(size.height * (0.525 + Double(index / 5) * 0.138 + Double(index % 3) * 0.018))
                let width = max(3, floor(size.width * (0.013 + 0.008 * (1 + cos(phase)))))
                let opacity = 0.15 + 0.16 * (1 + sin(phase))
                let line = CGRect(x: x, y: y, width: width, height: max(1, floor(size.width / 300)))
                context.fill(Path(line), with: .color(Color(red: 0.62, green: 0.82, blue: 0.76).opacity(opacity)))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private var cabinet: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let pond {
                PixelTabs(selection: $tab, items: [("鱼群", "鱼群"), ("鱼粮", "鱼粮")])
                PixelScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        if tab == "鱼群" { fishShelf(pond) }
                        else { foodShelf(pond) }
                    }.padding(.trailing, 2)
                }
                if tab == "鱼群" {
                    if pond.readyCount > 0 {
                        Button("收鱼 · \(pond.readyCount) 条") { collect(nil) }
                            .buttonStyle(PixelButtonStyle(primary: true))
                    }
                    Button("鱼苗商店") { market = true }
                        .buttonStyle(PixelButtonStyle(primary: pond.fish.isEmpty))
                }
            } else {
                Text("开辟池塘").font(.headline).foregroundStyle(Palette.goldLight)
                Text("容量 4 条 · 每条 1 份鱼粮")
                    .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                Button {
                    if store.commitGameChange({ $0.buildPond(at: store.now) }) { store.message = "池塘已开辟" }
                } label: {
                    pricedLabel("开辟", level: PondState.buildLevel, price: PondState.buildPrice)
                }.buttonStyle(PixelButtonStyle(primary: true))
                    .disabled(store.data.levelProgress.level < PondState.buildLevel || store.data.garden.coins < PondState.buildPrice)
                Spacer(minLength: 0)
            }
        }.padding(10).magicSurface(Palette.paper)
    }

    @ViewBuilder private func fishShelf(_ pond: PondState) -> some View {
        if pond.fish.isEmpty { Text("池塘里还没有鱼苗。").font(.caption).foregroundStyle(Palette.muted) }
        ForEach(pond.fish) { stock in
            if let fish = stock.species?.fish {
                Button {
                    if stock.ready { collect(stock.id) }
                    else { select(stock) }
                } label: {
                    HStack(spacing: 7) {
                        GameNatureSprite(key: fish.spriteKey, size: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fish.name).font(.system(size: 12))
                            Text(status(stock)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            PixelProgress(value: stock.progress / stock.growthSeconds)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.buttonStyle(PixelButtonStyle(primary: stock.ready || selected == stock.id))
                    .accessibilityLabel(fish.name + "，" + status(stock))
                if selected == stock.id {
                    Text(fish.description).font(.caption).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if !pond.expanded {
            Button {
                if store.commitGameChange({ $0.expandPond(at: store.now) }) { store.message = "池塘已扩建 · 容量 8 条" }
            } label: {
                pricedLabel("扩至 8 个位置", level: PondState.expansionLevel, price: PondState.expansionPrice)
            }.disabled(store.data.levelProgress.level < PondState.expansionLevel || store.data.garden.coins < PondState.expansionPrice)
        }
    }

    private func foodShelf(_ pond: PondState) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("存粮 \(pond.feed)/\(pond.feedCapacity) 份").font(.caption).foregroundStyle(Palette.goldLight)
            Text("每条鱼苗 · 1 份鱼粮")
                .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Button {
                if store.commitGameChange({ $0.buyPondFeed(at: store.now) }) {
                    store.message = "已添入 \(PondState.feedBagPortions) 份鱼粮。"
                }
            } label: {
                VStack(spacing: 3) {
                    Text("购买鱼粮")
                    Text("\(PondState.feedBagPortions) 份 · " + Money.text(PondState.feedBagPrice)).font(.system(size: 10))
                }.frame(maxWidth: .infinity)
            }.buttonStyle(PixelButtonStyle(primary: true))
                .disabled(pond.feed + PondState.feedBagPortions > pond.feedCapacity || store.data.garden.coins < PondState.feedBagPrice)
            ForEach(PondState.grains) { grain in
                let count = store.data.garden.ingredients[grain.rawValue, default: 0]
                Button {
                    if store.commitGameChange({ $0.fillPondFeed(grain, at: store.now) }) {
                        store.message = "已用\(grain.rawValue)添入 \(grain.portions) 份鱼粮。"
                    }
                } label: {
                    HStack(spacing: 7) {
                        IngredientArt(name: grain.rawValue, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(grain.rawValue) ×\(count)").font(.system(size: 12))
                            Text("用 1 份添粮 +\(grain.portions)").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }.disabled(count < 1 || pond.feed + grain.portions > pond.feedCapacity)
                    .accessibilityLabel("用\(grain.rawValue)添入 \(grain.portions) 份鱼粮")
            }
        }
    }

    private var fishMarket: some View {
        SceneDialog(preferred: CGSize(width: 650, height: 510)) {
            HStack { Text("鱼苗商店").font(.title3); Spacer(); Button("关闭") { market = false } }
        } content: {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 225))], alignment: .leading, spacing: 12) {
                ForEach(PondSpecies.all) { species in
                    if let fish = species.fish { marketCard(species, fish: fish) }
                }
            }
        } footer: {
            HStack {
                Text("鱼 \(pond?.fish.count ?? 0)/\(pond?.capacity ?? 0)").font(.caption)
                Spacer(minLength: 0)
                WalletView(coins: store.data.garden.coins)
            }
        }
    }

    private func marketCard(_ species: PondSpecies, fish: NatureFish) -> some View {
        let locked = store.data.levelProgress.level < species.level
        let full = pond.map { $0.fish.count >= $0.capacity } ?? true
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GameNatureSprite(key: fish.spriteKey, size: 45)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fish.name + "苗").font(.headline)
                    Text("\(species.growthMinutes) 分钟专注 · 1 份鱼粮").font(.system(size: 11))
                }
            }
            Text(fish.description).font(.caption).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if store.commitGameChange({ $0.buyPondFry(species.id, at: store.now) }) {
                    store.message = "已放入一条\(fish.name)苗。"
                }
            } label: {
                Text(locked ? "等级 \(species.level) 解锁" : full ? "池塘已满" : "放入 · " + Money.text(species.price))
                    .frame(maxWidth: .infinity)
            }.disabled(locked || full || store.data.garden.coins < species.price)
        }.padding(12).magicSurface(Palette.card)
    }

    private func pricedLabel(_ name: String, level: Int, price: Int) -> some View {
        VStack(spacing: 3) {
            Text(name)
            Text("等级 \(level) · " + Money.text(price)).font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }

    private func status(_ stock: PondFish) -> String {
        if stock.ready { return "可以收鱼" }
        if !stock.fed { return pond?.feed == 0 ? "等鱼粮" : "鱼粮已备好" }
        return "还需 \(Int(ceil((stock.growthSeconds - stock.progress) / 60))) 分钟专注"
    }

    private func select(_ stock: PondFish) {
        tab = "鱼群"
        selected = stock.id
    }

    private func collect(_ id: UUID?) {
        var catchCounts: [String: Int] = [:]
        guard store.commitGameChange({ data in
            catchCounts = data.harvestPondFish(id, at: store.now)
            return !catchCounts.isEmpty
        }) else { return }
        let names = NatureCatalog.fish.compactMap { fish in catchCounts[fish.id].map { "\(fish.name) ×\($0)" } }
        store.message = "已收取 " + names.joined(separator: "、")
    }
}
