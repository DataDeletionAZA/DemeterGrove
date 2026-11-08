import SwiftUI

struct TavernScene: View {
    @ObservedObject var store: GardenStore
    var workshop = false
    @State private var selected = "rowan"
    @State private var tab = "伙伴"
    @State private var slot: GearSlot = .tool
    private var state: ExpeditionState { store.data.expeditionState }
    private var companion: Companion { Companion.all.first { $0.id == selected } ?? Companion.all[0] }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Text(workshop ? "铸造 · 伙伴装备":"酒馆 · 伙伴 \(state.hired.count)/8 · 同行 \(state.team.count)/4")
                        .font(.system(size:13)).lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength:0)
                    WalletView(coins:store.data.garden.coins)
                }
                SceneToolbar(items:[
                    SceneToolbarItem("出发探险"){SceneNavigation.open("探险",store:store)},
                    SceneToolbarItem(workshop ? "酒馆":"铸造"){SceneNavigation.open(workshop ? "酒馆":"铸造",store:store)},
                    SceneToolbarItem("矿洞"){SceneNavigation.open("矿洞",store:store)},
                    SceneToolbarItem("小院"){SceneNavigation.open("首页",store:store)}
                ])
            }
            SceneCanvas(hasSidebar:true) { size in
                if workshop {forge(size)} else {tavern(size)}
            } sidebar: { cabinet }
        }.onAppear {if workshop {tab="装备"}}
    }

    private func forge(_ size:CGSize) -> some View {
        let w=size.width,h=size.height
        return ZStack {
            RoomBackdrop(name:"Forge").frame(width:w,height:h)
            ForEach(Array(CraftedGear.all.enumerated()),id:\.element.id) {index,item in
                ObjectButton(label:"查看\(item.name)",action:{slot=item.slot},caption:item.name) {
                    GameNatureSprite(key:item.spriteKey,size:w*0.095)
                }.position(x:w*(0.18+Double(index%4)*0.18),y:h*(index<4 ? 0.43:0.73))
            }
            GameNatureSprite(key:companion.spriteKey,size:w*0.16).position(x:w*0.87,y:h*0.76)
        }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
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
            if workshop {
                PixelSelect(selection:$selected,items:Companion.all.map{($0.id,$0.name + (state.hired.contains($0.id) ? "":" · 未结识"))})
                    .accessibilityLabel("选择装备伙伴")
            } else {PixelTabs(selection:$tab,items:[("伙伴","伙伴"),("装备","装备")])}
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
            stats(companion.gathering,companion.scouting,companion.guarding)
            if state.hired.contains(companion.id) {
                Text(state.team.contains(companion.id) ? "已加入下次同行队伍":"已结识，正在酒馆休息").font(.caption).foregroundStyle(Palette.goldLight)
                Button(state.team.contains(companion.id) ? "留在酒馆":"邀请同行") {
                    if store.commitGameChange({$0.toggleExpeditionCompanion(selected)}) {store.message=state.team.contains(selected) ? "已邀请\(companion.name)同行。":"\(companion.name)留在酒馆。"}
                }.frame(maxWidth:.infinity)
                    .disabled(!state.team.contains(companion.id) && state.team.count >= 4)
                ForEach(GearSlot.allCases,id:\.self) { slot in
                    let item=CraftedGear.all.first{$0.id == state.equipment[selected]?[slot.rawValue]}
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
            if let id=state.equipment[selected]?[slot.rawValue],let item=CraftedGear.all.first(where:{$0.id == id}) {
                HStack {
                    Text("已装备 · \(item.name)").font(.system(size:10)).fixedSize(horizontal:false,vertical:true)
                    Spacer(minLength:0)
                    Button("取下"){if store.commitGameChange({$0.equipExpeditionGear(nil,companion:selected,slot:slot)}) {store.message="已取下\(item.name)。"}}
                }
            }
            ForEach(CraftedGear.all.filter{$0.slot == slot}) { item in gearCard(item) }
        }
    }

    private func gearCard(_ item:CraftedGear) -> some View {
        let owned=state.gear[item.id,default:0]
        let used=state.equipment.values.filter{$0[item.slot.rawValue] == item.id}.count
        let equipped=state.equipment[selected]?[item.slot.rawValue] == item.id
        let canCraft=store.data.levelProgress.level >= item.level && store.data.garden.coins >= item.price
            && item.minerals.allSatisfy{store.data.miningState.inventory[$0.key,default:0] >= $0.value}
            && item.materials.allSatisfy{store.data.garden.economy.finds[$0.key,default:0] >= $0.value}
        return VStack(alignment:.leading,spacing:6) {
            HStack(spacing:6) {
                GameNatureSprite(key:item.spriteKey,size:40)
                VStack(alignment:.leading,spacing:3) {
                    Text(item.name).font(.system(size:11)).foregroundStyle(Palette.goldLight)
                    Text("等级 \(item.level) · 闲置 \(owned-used)/\(owned)").font(.system(size:10)).foregroundStyle(Palette.muted)
                }
            }
            stats(item.gathering,item.scouting,item.guarding)
            ForEach(item.minerals.keys.sorted(),id:\.self) { id in
                Text("\(Mineral.all.first{$0.id == id}?.name ?? id) \(store.data.miningState.inventory[id,default:0])/\(item.minerals[id]!)")
                    .font(.system(size:10)).foregroundStyle(Palette.muted)
            }
            ForEach(item.materials.keys.sorted(),id:\.self) { id in
                Text("\(NatureCatalog.ranchSpecies.first{$0.productID == id}?.productName ?? id) \(store.data.garden.economy.finds[id,default:0])/\(item.materials[id]!)")
                    .font(.system(size:10)).foregroundStyle(Palette.muted)
            }
            Text(Money.text(item.price)).font(.system(size:10)).foregroundStyle(Palette.goldLight)
            HStack(spacing:5) {
                Button("制作"){if store.commitGameChange({$0.craftExpeditionGear(item.id)}) {store.message="已制作\(item.name)。"}}
                    .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth:.infinity).disabled(!canCraft)
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
