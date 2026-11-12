import SwiftUI

struct RanchScene: View {
    @ObservedObject var store: GardenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = "饲料"
    @State private var market = false
    @State private var inventory = false
    @State private var selected: UUID?
    @State private var touchedAt = Date.distantPast
    private var ranch: RanchState { store.data.ranchState }
    private var feedingStatus: String {
        if ranch.animals.allSatisfy({ $0.ready >= $0.storageLimit }) { return "出产已满" }
        if ranch.feedPortions == 0 && !ranch.animals.contains(where: \.fed) { return "饲料不足" }
        if let timer = store.data.timer, timer.kind != .rest, timer.resumedAt != nil { return "自动喂养中" }
        return "等待专注"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SceneSizing.sectionGap) {
            SceneHeader {
                HStack(spacing: 14) {
                    Text("伙伴 \(ranch.animals.count)/\(ranch.capacity)").font(.system(size: 13))
                    Text("饲料 \(ranch.feedPortions) 份").font(.system(size: 13)).foregroundStyle(Palette.goldLight)
                    Spacer(minLength: 0)
                    WalletView(coins: store.data.garden.coins)
                }
                SceneToolbar(items: [
                    SceneToolbarItem("动物商店") { market = true },
                    SceneToolbarItem("库存") { inventory = true },
                    SceneToolbarItem("农场") { SceneNavigation.open("农场", store: store, from: "牧场") },
                    SceneToolbarItem("专注") { SceneNavigation.open("计时器", store: store, from: "牧场") }
                ])
            }
            SceneCanvas(hasSidebar: true) { size in
                pasture(size)
            } sidebar: {
                cabinet
            }
        }
        .sheet(isPresented: $market) { animalMarket }
        .sheet(isPresented: $inventory) { InventoryView(store: store) }
    }

    private func pasture(_ size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            RoomBackdrop(name: "Ranch").frame(width: w, height: h)
            SceneImageHotspot(background: "Ranch", rect: CGRect(x: 0.05, y: 0.12, width: 0.14, height: 0.24), size: size, label: "回到后院") {
                SceneNavigation.open("后院", store: store, from: "牧场")
            }
            TimelineView(.animation(minimumInterval: 1 / 10, paused: reduceMotion)) { timeline in
                let animals = Array(ranch.animals.enumerated()).sorted { left, right in
                    let a = RanchAnimalPose(index: left.offset, time: timeline.date.timeIntervalSinceReferenceDate, fed: left.element.fed, reducedMotion: reduceMotion)
                    let b = RanchAnimalPose(index: right.offset, time: timeline.date.timeIntervalSinceReferenceDate, fed: right.element.fed, reducedMotion: reduceMotion)
                    return a.y + animalSize(left.element) * 0.75 < b.y + animalSize(right.element) * 0.75
                }
                ZStack {
                    ForEach(animals, id: \.element.id) { index, animal in
                        if let species = animal.species {
                            let pose = RanchAnimalPose(index: index, time: timeline.date.timeIntervalSinceReferenceDate,
                                                       fed: animal.fed, reducedMotion: reduceMotion)
                            let artSize = w * animalSize(animal)
                            let age = timeline.date.timeIntervalSince(touchedAt)
                            let bounce = !reduceMotion && selected == animal.id && age >= 0 && age < 0.6 ? sin(age / 0.6 * .pi) * h * 0.025 : 0
                            ObjectButton(label: species.name + "，" + status(animal), action: { visit(animal) }, caption: species.name) {
                                GameNatureSprite(key: species.spriteKey, size: artSize)
                                    .scaleEffect(x: pose.facingRight ? -1 : 1, y: pose.eating ? 0.96 : 1, anchor: .bottom)
                                    .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                            }.position(x: w * pose.x, y: h * pose.y - bounce)
                            if animal.ready > 0 {
                                ObjectButton(label: "收取\(species.productName) ×\(animal.ready)", action: { collect(animal.id) }, caption: "收取\(species.productName)") {
                                    VStack(spacing: 1) {
                                        produceArt(species, size: w * 0.055)
                                        Text("×\(animal.ready)").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.goldLight)
                                            .padding(.horizontal, 5).background(Palette.paper.opacity(0.92), in: PixelFrame())
                                    }
                                }.position(x: w * pose.homeX + w * 0.065, y: h * pose.homeY + h * 0.065)
                            }
                        }
                    }
                }.frame(width: w, height: h)
            }
            SceneImageHotspot(background: "Ranch", rect: CGRect(x: 0.33, y: 0.81, width: 0.30, height: 0.10), size: size, label: "饲料槽 · \(ranch.feedPortions) 份可用") { tab = "饲料" }
            if !ranch.expanded {
                SceneImageHotspot(background: "Ranch", rect: CGRect(x: 0.78, y: 0.765, width: 0.16, height: 0.13), size: size, label: "扩建牧场") { tab = "伙伴" }
            }
            if ranch.animals.isEmpty {
                Button("迎接第一位伙伴") { market = true }.buttonStyle(PixelButtonStyle(primary: true)).position(x: w * 0.52, y: h * 0.56)
            }
            SceneArrows(store: store, scene: "牧场")
        }.frame(width: w, height: h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65), lineWidth: 1))
    }

    private func animalSize(_ animal: RanchAnimal) -> CGFloat { ["cow", "mooncalf"].contains(animal.speciesID) ? 0.17 : 0.14 }

    private var cabinet: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("牧场小柜").font(.headline).foregroundStyle(Palette.goldLight)
            PixelTabs(selection: $tab, items: [("饲料", "饲料"), ("出产", "出产"), ("伙伴", "伙伴")])
            PixelScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if tab == "饲料" { feedShelf }
                    else if tab == "出产" { produceShelf }
                    else { animalShelf }
                }.padding(.trailing, 2)
            }
            if tab == "饲料" {
                Button {
                    if store.commitGameChange({ $0.buyRanchFeed(at: store.now) }) { store.message = "已储备一袋混合饲料（\(RanchState.feedBagPortions) 份）。" }
                } label: {
                    VStack(spacing: 3) {
                        Text("购买混合饲料")
                        Text("\(RanchState.feedBagPortions) 份 · " + Money.text(RanchState.feedBagPrice)).font(.system(size: 10))
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(PixelButtonStyle()).disabled(store.data.garden.coins < RanchState.feedBagPrice)
                    .help(ItemLore.text(for: "feed:feed_bag") ?? "混合饲料")
            } else if tab == "出产" {
                Button("收取全部 · \(ranch.readyCount)") { collect(nil) }.frame(maxWidth: .infinity)
                    .buttonStyle(PixelButtonStyle(primary: true)).disabled(ranch.readyCount == 0)
                let fertilizer = store.data.garden.economy.finds["mooncalf_dung", default: 0]
                if fertilizer > 0 {
                    Button {
                        if store.commitGameChange({ $0.useRanchFertilizer() }) { store.message = "已施用银色粪肥，作物生长 +3 分钟。" }
                    } label: {
                        HStack(spacing: 6) { GameNatureSprite(key: "product_mooncalf", size: 23); Text("施肥 ×\(fertilizer)") }.frame(maxWidth: .infinity)
                    }.disabled(!store.data.garden.plots.contains { $0.crop != nil })
                        .accessibilityLabel("施用银色粪肥").help("银色粪肥 ×1 · 作物生长 +3 分钟")
                }
            }
        }.padding(10).magicSurface(Palette.paper)
    }

    private var feedShelf: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !ranch.animals.isEmpty { Text(feedingStatus).font(.caption).foregroundStyle(Palette.goldLight) }
            Text("槽内 \(ranch.trough)/\(ranch.troughCapacity) · 备用 \(ranch.feedBags) 袋")
                .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            ForEach(RanchFeed.allCases) { feed in
                let count = store.data.garden.ingredients[feed.rawValue, default: 0]
                Button { addFeed(feed) } label: {
                    HStack(spacing: 6) {
                        IngredientArt(name: feed.rawValue, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.rawValue + " ×\(count)").font(.system(size: 11))
                            Text("装入 \(feed.portions) 份").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity)
                }.disabled(count < 1 || ranch.trough + feed.portions > ranch.troughCapacity)
                    .accessibilityLabel("向饲料槽添加" + feed.rawValue)
            }
        }
    }

    private var produceShelf: some View {
        VStack(alignment: .leading, spacing: 9) {
            if ranch.animals.isEmpty { Text("迎接伙伴后，这里会显示出产。").font(.caption).foregroundStyle(Palette.muted) }
            ForEach(ranch.animals) { animal in
                if let species = animal.species {
                    Button { if animal.ready > 0 { collect(animal.id) } else { visit(animal) } } label: {
                        HStack(spacing: 7) {
                            produceArt(species, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(species.productName + " ×\(animal.ready)").font(.system(size: 11))
                                Text(status(animal)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                PixelProgress(value: animal.progress / animal.productionSeconds)
                            }
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(PixelButtonStyle(primary: animal.ready > 0))
                }
            }
        }
    }

    private var animalShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            if ranch.animals.isEmpty { Text("牧场还没有动物").font(.caption).foregroundStyle(Palette.muted) }
            ForEach(ranch.animals) { animal in
                if let species = animal.species {
                    VStack(alignment: .leading, spacing: 5) {
                        Button { visit(animal) } label: {
                            HStack(spacing: 6) { GameNatureSprite(key: species.spriteKey, size: 34); Text(species.name).font(.system(size: 12)); Spacer(minLength: 0) }
                        }.buttonStyle(PixelButtonStyle(primary: selected == animal.id))
                        if selected == animal.id {
                            Text(status(animal)).font(.caption).foregroundStyle(Palette.goldLight)
                            Text(species.description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                            if let description=ItemLore.text(for:"product:"+species.productID) {
                                Text(species.productName+" · "+description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                            }
                            Text("每 \(species.productionMinutes) 分钟专注 · \(species.productName) ×\(species.productCount)").font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !ranch.expanded {
                Text("扩建：4 → 8 位伙伴，饲料槽 24 → 48 份。").font(.caption).fixedSize(horizontal: false, vertical: true)
                Button {
                    if store.commitGameChange({ $0.expandRanch(at: store.now) }) { store.message = "牧场变宽敞了，可以迎接 8 位伙伴。" }
                } label: {
                    VStack(spacing: 4) { Text("扩建牧场"); Text("等级 \(RanchState.expansionLevel) · " + Money.text(RanchState.expansionPrice)).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity)
                }.disabled(store.data.levelProgress.level < RanchState.expansionLevel || store.data.garden.coins < RanchState.expansionPrice)
            } else { Text("牧场已扩建 · 8 个位置").font(.caption).foregroundStyle(Palette.goldLight) }
        }
    }

    private var animalMarket: some View {
        SceneDialog(preferred: CGSize(width: 650, height: 530)) {
            HStack { Text("迎接牧场伙伴").font(.title3); Spacer(); Button("关闭") { market = false } }
        } content: {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235))], alignment: .leading, spacing: 12) {
                ForEach(NatureCatalog.ranchSpecies) { species in marketCard(species) }
            }
        } footer: {
            HStack { Text("伙伴 \(ranch.animals.count)/\(ranch.capacity)").font(.caption); Spacer(); WalletView(coins: store.data.garden.coins) }
        }
    }

    private func marketCard(_ species: NatureRanchSpecies) -> some View {
        let locked = store.data.levelProgress.level < species.level
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                GameNatureSprite(key: species.spriteKey, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(species.name).font(.headline)
                    Text(species.origin.name).font(.system(size: 10)).foregroundStyle(Palette.goldLight)
                    Text("等级 \(species.level)").font(.caption).foregroundStyle(Palette.muted)
                }
            }
            Text(species.description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Text("\(species.productionMinutes) 分钟专注 → \(species.productName) ×\(species.productCount)").font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            Button {
                if store.commitGameChange({ $0.buyRanchAnimal(species.id, at: store.now) }) { store.message = species.name + "来到牧场了。" }
            } label: {
                Text(locked ? "等级 \(species.level) 解锁" : "迎接 · " + Money.text(species.price)).frame(maxWidth: .infinity)
            }.disabled(locked || ranch.animals.count >= ranch.capacity || store.data.garden.coins < species.price)
        }.padding(12).magicSurface(Palette.card)
    }

    @ViewBuilder private func produceArt(_ species: NatureRanchSpecies, size: CGFloat) -> some View {
        if let ingredient = species.ingredient { IngredientArt(name: ingredient, size: size) }
        else { GameNatureSprite(key: "product_" + species.id, size: size) }
    }

    private func status(_ animal: RanchAnimal) -> String {
        if animal.ready >= animal.storageLimit { return "出产已装满，收取后继续" }
        if animal.fed { return "已进食 · 还需 \(Int(ceil((animal.productionSeconds - animal.progress) / 60))) 分钟专注" }
        return ranch.feedPortions > 0 ? "饲料已备好" : "饲料不足"
    }

    private func visit(_ animal: RanchAnimal) {
        selected = animal.id; touchedAt = Date(); tab = "伙伴"
        store.message = (animal.species?.name ?? "伙伴") + " · " + status(animal)
    }

    private func addFeed(_ feed: RanchFeed) {
        if store.commitGameChange({ $0.fillRanchTrough(feed, at: store.now) }) { store.message = "已装入 \(feed.portions) 份饲料。" }
    }

    private func collect(_ animal: UUID?) {
        var produce: [String: Int] = [:]
        guard store.commitGameChange({ data in produce = data.collectRanchProduce(animal, at: store.now); return !produce.isEmpty }) else { return }
        store.message = "收取 " + produce.keys.sorted().map { "\($0) ×\(produce[$0]!)" }.joined(separator: "、")
    }
}
