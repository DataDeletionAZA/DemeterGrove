import SwiftUI

struct TavernScene: View {
    @ObservedObject var store: GardenStore
    @State private var showRecruits = false
    @State private var showInventory = false
    @State private var equipmentCompanion: Companion?
    private var state:ExpeditionState { store.data.expeditionState }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader(store:store,toolbar:[
                SceneToolbarItem("成长") { SceneNavigation.open("成长",store:store,from:store.currentRoute) },
                SceneToolbarItem("库存") {
                    if let pet=store.pet {pet.openInventory()} else {showInventory=true}
                }
            ])
            SceneCanvas(hasSidebar:true) { size in
                ZStack {
                    RoomBackdrop(name:"Tavern").frame(width:size.width,height:size.height)
                    SceneImageHotspot(background:"Tavern",rect:CGRect(x:0.339,y:0.264,width:0.451,height:0.14),
                                      size:size,label:"酒馆吧台 · 查看招募",action:{showRecruits=true})
                    SceneArrows(store:store,scene:"酒馆")
                }.frame(width:size.width,height:size.height).clipShape(PixelFrame())
                    .overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
            } sidebar: { companions }
        }.onAppear {
            if store.data.expeditionState.tavern == nil { store.commitGameChange { $0.openTavern(at:store.now) } }
        }
        .sheet(isPresented:$showInventory) { InventoryView(store:store) }
        .sheet(isPresented:$showRecruits) { TavernRecruitmentSheet(store:store) }
        .sheet(item:$equipmentCompanion) { CompanionEquipmentSheet(store:store,person:$0) }
    }

    private var companions:some View {
        VStack(alignment:.leading,spacing:9) {
            Text("已有伙伴").font(.headline).foregroundStyle(Palette.goldLight)
            PixelScrollView {
                LazyVStack(alignment:.leading,spacing:8) {
                    if state.hired.isEmpty {
                        Text("还没有伙伴").font(.caption).foregroundStyle(Palette.muted)
                    }
                    ForEach(Companion.all.filter {state.hired.contains($0.id)}) { person in
                        Button {equipmentCompanion=person} label: {
                            HStack(spacing:6) {
                                GameNatureSprite(key:person.spriteKey,size:35)
                                VStack(alignment:.leading,spacing:3) {
                                    Text(person.name).foregroundStyle(Palette.goldLight)
                                    Text(state.isTraveling(person.id) ? "正在探险":person.role)
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer(minLength:0)
                                Image(systemName:"chevron.right").font(.system(size:9)).foregroundStyle(Palette.muted)
                            }.frame(maxWidth:.infinity,alignment:.leading).padding(6)
                                .magicSurface(Palette.card).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel("查看\(person.name)的装备")
                    }
                }.padding(.trailing,2)
            }.frame(maxHeight:.infinity)
        }.padding(10).magicSurface(Palette.paper)
    }
}

private struct TavernRecruitmentSheet: View {
    @ObservedObject var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    private var nextRefresh:Int {
        let last = store.data.expeditionState.tavern?.refreshedAtFocus ?? store.gameFocus
        return Int(ceil(max(0,TavernRoster.interval-(store.gameFocus-last))/60))
    }

    var body: some View {
        SceneDialog(preferred:CGSize(width:460,height:440)) {
            HStack {
                Text("酒馆招募").font(.headline)
                Spacer(minLength:0)
                WalletView(coins:store.data.garden.coins)
            }
        } content: {
            VStack(alignment:.leading,spacing:10) {
                if store.data.tavernVisitors.isEmpty {
                    Text("现在没有可招募的伙伴。").foregroundStyle(Palette.muted)
                }
                ForEach(store.data.tavernVisitors) { person in recruitCard(person) }
            }
        } footer: {
            VStack(alignment:.leading,spacing:8) {
                Text("再专注 \(nextRefresh) 分钟自动刷新").font(.caption).foregroundStyle(Palette.muted)
                HStack(spacing:8) {
                    Button("刷新 · \(Money.text(TavernRoster.refreshPrice))") {
                        store.commitGameChange { $0.refreshTavern(at:store.now) }
                    }.disabled(!store.data.canRefreshTavern || store.data.garden.coins<TavernRoster.refreshPrice)
                    Spacer(minLength:0)
                    Button("关闭"){dismiss()}.keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    private func recruitCard(_ person:Companion) -> some View {
        HStack(alignment:.top,spacing:10) {
            GameNatureSprite(key:person.spriteKey,size:74)
            VStack(alignment:.leading,spacing:7) {
                Text(person.name).font(.headline).foregroundStyle(Palette.goldLight)
                Text(person.role).font(.caption).foregroundStyle(Palette.muted)
                if let lore = ItemLore.text(for:"companion:"+person.id) {
                    Text(lore).font(.caption).fixedSize(horizontal:false,vertical:true)
                }
                Text("采集 \(person.gathering) · 寻踪 \(person.scouting) · 护行 \(person.guarding)")
                    .font(.caption).foregroundStyle(Palette.goldLight)
                Button("招募 · \(Money.text(person.price))") {
                    if store.commitGameChange({$0.hireCompanion(person.id)}) { store.message="\(person.name)加入了你的伙伴名单。" }
                }.buttonStyle(PixelButtonStyle(primary:true))
                    .disabled(store.data.garden.coins<person.price)
                    .accessibilityLabel("招募\(person.name)，\(Money.text(person.price))")
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(9).magicSurface(Palette.card)
    }
}
