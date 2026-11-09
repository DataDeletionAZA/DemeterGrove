import SwiftUI

struct TavernScene: View {
    @ObservedObject var store: GardenStore
    @State private var selected = "rowan"
    @State private var tab = "伙伴"
    @State private var slot: GearSlot = .tool
    private var state: ExpeditionState { store.data.expeditionState }
    private var companion: Companion { Companion.all.first { $0.id == selected } ?? Companion.all[0] }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Text("酒馆 · 伙伴 \(state.hired.count)/8 · 同行 \(state.team.count)/4")
                        .font(.system(size:13)).lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength:0)
                    WalletView(coins:store.data.garden.coins)
                }
                SceneToolbar(items:[
                    SceneToolbarItem("出发探险"){SceneNavigation.open("探险",store:store)},
                    SceneToolbarItem("锻造室"){SceneNavigation.open("锻造室",store:store)},
                    SceneToolbarItem("矿洞"){SceneNavigation.open("矿洞",store:store)},
                    SceneToolbarItem("小院"){SceneNavigation.open("首页",store:store)}
                ])
            }
            SceneCanvas(hasSidebar:true) { size in
                tavern(size)
            } sidebar: { cabinet }
        }
    }

    private func tavern(_ size:CGSize) -> some View {
        let w=size.width,h=size.height
        return ZStack {
            RoomBackdrop(name:"Tavern").frame(width:w,height:h)
            ForEach(Array(Companion.all.enumerated()),id:\.element.id) { index,person in
                let row=index/4,column=index%4
                let x=w*(0.20+Double(column)*0.20)
                let y=h*(row == 0 ? 0.58:0.78)
                ObjectButton(label:"\(person.name)，\(person.role)",action:{selected=person.id},caption:person.name + (state.team.contains(person.id) ? " · 同行":"")) {
                    GameNatureSprite(key:person.spriteKey,size:w*0.12)
                        .background(alignment:.bottom) {
                            Ellipse().fill(selected == person.id ? Palette.gold.opacity(0.45):Color.black.opacity(0.12)).frame(width:w*0.11,height:h*0.025)
                        }.opacity(store.data.levelProgress.level >= person.level ? 1:0.55)
                }.position(x:x,y:y)
            }
        }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
    }

    private var cabinet: some View {
        VStack(alignment:.leading,spacing:9) {
            HStack(spacing:7) {
                GameNatureSprite(key:companion.spriteKey,size:42)
                VStack(alignment:.leading,spacing:3) {
                    Text(companion.name).font(.headline).foregroundStyle(Palette.goldLight)
                    Text(companion.role).font(.system(size:11)).foregroundStyle(Palette.muted)
                }
            }
            PixelTabs(selection:$tab,items:[("伙伴","伙伴"),("装备","装备")])
            PixelScrollView {
                VStack(alignment:.leading,spacing:10) {
                    if tab == "伙伴" { companionDetails }
                    else { equipmentShelf }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,2)
            }
        }.padding(10).magicSurface(Palette.paper)
    }

    private var companionDetails: some View {
        VStack(alignment:.leading,spacing:10) {
            if let lore=ItemLore.text(for:"companion:"+companion.id) {Text(lore).font(.system(size:11)).foregroundStyle(Palette.ink).fixedSize(horizontal:false,vertical:true)}
            stats(companion.gathering,companion.scouting,companion.guarding)
            if state.hired.contains(companion.id) {
                Text(state.team.contains(companion.id) ? "已加入下次同行队伍":"已结识，正在酒馆休息").font(.caption).foregroundStyle(Palette.goldLight)
                Button(state.team.contains(companion.id) ? "留在酒馆":"邀请同行") {
                    if store.commitGameChange({$0.toggleExpeditionCompanion(selected)}) {store.message=state.team.contains(selected) ? "已邀请\(companion.name)同行。":"\(companion.name)留在酒馆。"}
                }.frame(maxWidth:.infinity)
                    .disabled(!state.team.contains(companion.id) && state.team.count >= 4)
                ForEach(GearSlot.allCases,id:\.self) { slot in
                    let item=(state.equipment[selected]?[slot.rawValue]).flatMap{state.resolveGear($0)}
                    HStack(spacing:6) {
                        if let item {GameNatureSprite(key:item.spriteKey,size:28)}
                        Text("\(slot.rawValue) · \(item?.name ?? "尚未装备")").font(.system(size:11)).fixedSize(horizontal:false,vertical:true)
                    }
                }
                Button("挑选装备"){tab="装备"}.frame(maxWidth:.infinity)
            } else {
                Text("等级 \(companion.level) · \(Money.text(companion.price))").font(.system(size:11)).foregroundStyle(Palette.goldLight).fixedSize(horizontal:false,vertical:true)
                Button("结识伙伴") {
                    if store.commitGameChange({$0.hireCompanion(selected)}) {store.message="已结识\(companion.name)。"}
                }.frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:true))
                    .disabled(store.data.levelProgress.level < companion.level || store.data.garden.coins < companion.price)
            }
            Text("下次队伍 · \(state.team.count)/4").font(.system(size:12)).foregroundStyle(Palette.goldLight)
            let total=store.data.expeditionStats
            stats(total.gathering,total.scouting,total.guarding)
            if state.team.isEmpty {Text("你独自出发").font(.caption).foregroundStyle(Palette.muted)}
            ForEach(state.team,id:\.self) { id in
                if let person=Companion.all.first(where:{$0.id == id}) {
                    Button{selected=id} label:{
                        HStack {GameNatureSprite(key:person.spriteKey,size:32);Text(person.name);Spacer(minLength:0)}
                    }.buttonStyle(.plain).accessibilityLabel("查看同行伙伴\(person.name)")
                }
            }
        }
    }

    private var equipmentShelf: some View {
        VStack(alignment:.leading,spacing:9) {
            PixelSelect(selection:$slot,items:GearSlot.allCases.map{($0,$0.rawValue)})
                .accessibilityLabel("装备部位")
            if let id=state.equipment[selected]?[slot.rawValue],let item=state.resolveGear(id) {
                HStack {
                    Text("已装备 · \(item.name)").font(.system(size:10)).fixedSize(horizontal:false,vertical:true)
                    Spacer(minLength:0)
                    Button("取下"){if store.commitGameChange({$0.equipExpeditionGear(nil,companion:selected,slot:slot)}) {store.message="已取下\(item.name)。"}}
                }
            }
            ForEach(state.ownedGear.filter{$0.slot == slot}) { item in gearCard(item) }
        }
    }

    private func gearCard(_ item:CraftedGear) -> some View {
        let owned=state.gear[item.id,default:0]
        let used=state.wornCount(item.id)
        let equipped=state.equipment[selected]?[item.slot.rawValue] == item.id
        return VStack(alignment:.leading,spacing:6) {
            HStack(spacing:6) {
                GameNatureSprite(key:item.spriteKey,size:40)
                VStack(alignment:.leading,spacing:3) {
                    Text(item.name).font(.system(size:11)).foregroundStyle(Palette.goldLight)
                    Text("闲置 \(owned-used)/\(owned)").font(.system(size:10)).foregroundStyle(Palette.muted)
                }
            }
            stats(item.gathering,item.scouting,item.guarding)
            if let lore=item.description {Text(lore).font(.system(size:10)).foregroundStyle(Palette.ink).fixedSize(horizontal:false,vertical:true)}
            HStack(spacing:5) {
                Button(equipped ? "已装备":"装备") {
                    if store.commitGameChange({$0.equipExpeditionGear(item.id,companion:selected,slot:item.slot)}) {store.message="\(companion.name)已装备\(item.name)。"}
                }.lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth:.infinity).disabled(equipped || !state.hired.contains(selected) || owned <= used)
            }
        }.padding(7).magicSurface(Palette.card)
    }

    private func stats(_ gathering:Int,_ scouting:Int,_ guarding:Int) -> some View {
        Text("采集 \(gathering) · 寻踪 \(scouting) · 护行 \(guarding)").font(.system(size:10)).foregroundStyle(Palette.goldLight).fixedSize(horizontal:false,vertical:true)
            .help("采集增加收获数量；寻踪增加珍稀发现的机会；护行有机会多带回一份收获。")
    }
}
