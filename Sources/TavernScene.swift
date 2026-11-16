import SwiftUI

struct TavernScene: View {
    @ObservedObject var store: GardenStore
    @State private var showRecruits = false

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Button {showRecruits=true} label: {
                        Label {Text("查看招募")} icon: {PixelIcon(name:"酒馆",size:20)}
                    }.buttonStyle(PixelButtonStyle())
                    Spacer()
                    WalletView(coins:store.data.garden.coins)
                }
            }
            SceneCanvas { size in
                ZStack {
                    RoomBackdrop(name:"Tavern").frame(width:size.width,height:size.height)
                    SceneImageHotspot(background:"Tavern",rect:CGRect(x:0.339,y:0.264,width:0.451,height:0.14),
                                      size:size,label:"酒馆吧台 · 查看招募",action:{showRecruits=true})
                    ForEach(Array(store.data.tavernVisitors.enumerated()),id:\.element.id) { index,person in
                        ObjectButton(label:"查看\(person.name)的招募信息",action:{showRecruits=true},caption:person.name) {
                            GameNatureSprite(key:person.spriteKey,size:min(size.width*0.15,size.height*0.28))
                        }.position(x:size.width*(0.44+Double(index)*0.15),y:size.height*0.60)
                    }
                    SceneArrows(store:store,scene:"酒馆")
                }.frame(width:size.width,height:size.height).clipShape(PixelFrame())
                    .overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
            }
        }.onAppear {
            if store.data.expeditionState.tavern == nil { store.commitGameChange { $0.openTavern(at:store.now) } }
        }
        .sheet(isPresented:$showRecruits) { TavernRecruitmentSheet(store:store) }
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
