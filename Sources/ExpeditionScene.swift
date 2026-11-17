import SwiftUI

struct ExpeditionScene: View {
    @ObservedObject var store: GardenStore
    var initialLocation: String? = nil
    @State private var minutes: String?
    @State private var tab = "行程"
    @State private var showInventory = false
    @State private var showParty = false
    @State private var equipmentCompanion: Companion?
    @State private var showEarlyReturn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var state: ExpeditionState { store.data.expeditionState }
    private var location: ExpeditionLocation {
        let id = initialLocation ?? state.trip?.locationID ?? state.preferredLocation
        return ExpeditionLocation.all.first{$0.id == id} ?? ExpeditionLocation.all[0]
    }
    private var route: String { "探险/" + location.id }
    private var locked: Bool { store.data.levelProgress.level < location.level }
    private var localTrip: ExpeditionTrip? { state.trip.flatMap{$0.locationID == location.id ? $0:nil} }
    private var legacyTrip: Bool { store.data.garden.economy.trip(.adventure) != nil }
    private var pending: [String:Int] { state.unclaimedRewards(at:location.id) }
    private var localInventory: Int {
        let inventory=state.inventory
        return NatureCatalog.forage.filter{$0.locations.contains(location.id)}
            .reduce(0){$0+inventory[$1.id,default:0]}
    }
    private var minuteInput: String { minutes ?? String(state.preferredMinutes) }
    private var duration: Int? { Int(minuteInput.trimmingCharacters(in:.whitespacesAndNewlines)).flatMap{(1...1440).contains($0) ? $0:nil} }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader(store:store,toolbar:[
                    SceneToolbarItem("酒馆"){SceneNavigation.open("酒馆",store:store,from:store.currentRoute)},
                    SceneToolbarItem("世界地图"){SceneNavigation.open("世界地图",store:store,from:store.currentRoute)}
            ]) {
                Text("本地物资 \(localInventory) 份").font(.caption).foregroundStyle(Palette.muted)
            }
            SceneCanvas(hasSidebar:true) {size in landscape(size)} sidebar: {cabinet}
        }.onChange(of:location.id) { _,_ in tab="行程" }
            .onChange(of:state.history.last?.id) { _,_ in
                if state.history.last?.locationID == location.id { tab=pending.isEmpty ? "记录":"行程" }
            }
            .sheet(isPresented:$showInventory) { InventoryView(store:store) }
            .sheet(isPresented:$showParty) { ExpeditionPartySheet(store:store,location:location) }
            .sheet(item:$equipmentCompanion) { person in CompanionEquipmentSheet(store:store,person:person) }
            .alert("提前结束探险？",isPresented:$showEarlyReturn) {
                Button("取消",role:.cancel) {}
                Button("提前结束",role:.destructive) {
                    guard localTrip != nil else { return }
                    if store.commitGameChange({$0.returnExpedition(at:store.now)}) {tab="记录"}
                }
            } message: {
                if let trip=localTrip {
                    let forfeited=trip.rewards.keys.reduce(0){$0+trip.unpackedCount($1)}
                    if forfeited>0 { Text("本次尚未结算的 \(forfeited) 份收获将失去。") }
                }
            }
    }

    private func elapsed(_ trip: ExpeditionTrip) -> Double { max(0,min(trip.duration,store.gameFocus-trip.startedFocus)) }
    private func progress(_ trip: ExpeditionTrip) -> Double { elapsed(trip)/trip.duration }

    private func tripStatus(_ trip: ExpeditionTrip) -> String {
        let focusing = store.data.timer.map { $0.kind != .rest && $0.resumedAt != nil } ?? false
        if focusing { return "探险进行中" }
        return progress(trip)>0 ? "旅途暂停 · 等待专注":"已出发 · 等待专注"
    }

    private func landscape(_ size:CGSize) -> some View {
        let w=size.width,h=size.height
        let trip=localTrip
        let party=trip?.companions ?? (locked ? []:state.team(at:location.id).filter{!state.isTraveling($0)})
        let distance=trip.map{0.05+progress($0)*0.07} ?? 0
        return ZStack {
            RoomBackdrop(name:location.backdrop).frame(width:w,height:h)
            ForEach(Array(party.enumerated()),id:\.element) {index,id in
                if let person=Companion.all.first(where:{$0.id == id}) {
                    ObjectButton(label:"查看\(person.name)的装备",action:{equipmentCompanion=person},caption:person.name) {
                        GameNatureSprite(key:person.spriteKey,size:w*0.12)
                    }.position(x:w*(0.23+Double(index)*0.15+distance),y:h*(index%2 == 0 ? 0.55:0.63))
                        .animation(reduceMotion ? nil:.easeOut(duration:0.3),value:trip?.id)
                }
            }
            SceneArrows(store:store,scene:route)
        }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
    }

    private func railButton(_ title:String, primary:Bool=false, action:@escaping()->Void) -> some View {
        Button(action:action) {
            Text(title).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth:.infinity)
        }.buttonStyle(PixelButtonStyle(primary:primary))
    }

    private var cabinet: some View {
        VStack(alignment:.leading,spacing:9) {
            Text("远行小册").font(.headline).foregroundStyle(Palette.goldLight)
            PixelTabs(selection:$tab,items:[("行程","行程"),("行囊","行囊"),("记录","记录")])
            PixelScrollView {
                VStack(alignment:.leading,spacing:10) {
                    if tab == "行程" {itinerary}
                    else if tab == "行囊" {satchel}
                    else {records}
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,2)
            }
        }.padding(10).magicSurface(Palette.paper)
    }

    private var itinerary: some View {
        VStack(alignment:.leading,spacing:9) {
            if !pending.isEmpty {
                railButton("领取收获",primary:true) {
                    if store.commitGameChange({$0.claimExpeditionRewards(at:location.id)}) {
                        store.message="收获已放入行囊。"
                    }
                }
                VStack(alignment:.leading,spacing:6) {
                    ForEach(NatureCatalog.forage.filter{pending[$0.id,default:0]>0}) { item in
                        HStack(spacing:6) {
                            GameNatureSprite(key:item.spriteKey,size:24)
                            Text(item.name).font(.caption)
                            Spacer(minLength:0)
                            Text("×\(pending[item.id,default:0])").font(.caption).foregroundStyle(Palette.goldLight)
                        }
                    }
                }.padding(6).magicSurface(Palette.card)
            }
            if let trip=localTrip {
                Text(tripStatus(trip)).font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.goldLight)
                Text("\(Int(elapsed(trip)/60)) / \(Int(trip.duration/60)) 分钟专注").font(.system(size:11)).monospacedDigit()
                PixelProgress(value:progress(trip))
                Text("采集 \(trip.gathering) · 寻踪 \(trip.scouting) · 护行 \(trip.guarding)").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                railButton("记录专注"){SceneNavigation.open("计时器",store:store,from:store.currentRoute)}
                railButton("提前结束"){showEarlyReturn=true}
            } else if let trip=state.trip, let destination=ExpeditionLocation.all.first(where:{$0.id == trip.locationID}) {
                railButton("查看\(destination.name)的行程") { SceneNavigation.open("探险/"+destination.id,store:store,from:store.currentRoute) }
                if !locked { partyButton }
            } else if legacyTrip {
                Text("行程进行中").font(.caption).fixedSize(horizontal:false,vertical:true)
            } else if locked {
                Text("尚未解锁").font(.caption).fixedSize(horizontal:false,vertical:true)
            } else {
                Text("行程时长").font(.system(size:12)).foregroundStyle(Palette.goldLight)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:4) {
                    ForEach([15,30,60,120],id:\.self) {value in
                        railButton("\(value)",primary:duration == value){minutes=String(value)}
                    }
                }
                HStack(spacing:5) {
                    TextField("1～1440",text:Binding(get:{minuteInput},set:{minutes=$0}))
                        .textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("自定义探险分钟数")
                    Text("分钟").font(.system(size:11))
                }
                if duration == nil {Text("请输入 1～1440 的整数分钟。").font(.system(size:10)).foregroundStyle(Palette.goldLight)}
                partyButton
                railButton("出发探险",primary:true) {
                    guard let duration else{return}
                    store.commitGameChange { $0.embarkExpedition(locationID:location.id,minutes:duration,at:store.now) }
                }.disabled(duration == nil)
            }
        }
    }

    private var partyButton:some View {
        railButton("队伍 · \(state.team(at:location.id).count)/4"){showParty=true}
    }

    private var satchel: some View {
        VStack(alignment:.leading,spacing:8) {
            if state.inventory.values.allSatisfy({$0 == 0}) {Text("行囊为空").font(.caption).foregroundStyle(Palette.muted)}
            ForEach(NatureCatalog.forage.filter{state.inventory[$0.id,default:0]>0}) {item in
                VStack(alignment:.leading,spacing:6) {
                    HStack(spacing:7) {
                        GameNatureSprite(key:item.spriteKey,size:38)
                        VStack(alignment:.leading,spacing:3) {Text(item.name).font(.system(size:11));Text(item.origin.name).font(.system(size:9)).foregroundStyle(Palette.muted)}
                        Spacer(minLength:0)
                        Text("×\(state.inventory[item.id,default:0])").font(.system(size:11)).foregroundStyle(Palette.goldLight)
                    }
                    Text(item.description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                    NatureSourceLinks(ids:item.sourceIDs)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:74),spacing:5)],spacing:5) {
                        if item.isCookable,let ingredient=item.ingredient {
                            railButton("加工 ×1") {
                                if store.commitGameChange({$0.prepareForage(item.id,count:1)}) {store.message="\(item.name)已加工为\(ingredient)。"}
                            }.accessibilityLabel("将一份\(item.name)加工为\(ingredient)")
                        }
                        if Potion.all.contains(where:{$0.forageID == item.id}) {
                            railButton("炼金"){SceneNavigation.open("炼金室",store:store,from:store.currentRoute)}.accessibilityLabel("用\(item.name)熬制魔药")
                        }
                        railButton("售出 ×1") {
                            if store.commitGameChange({$0.sellForage(item.id,count:1)}) {store.message="售出\(item.name)，收到\(Money.text(item.salePrice))。"}
                        }.accessibilityLabel("售出一份\(item.name)，获得\(Money.text(item.salePrice))")
                    }.font(.system(size:10))
                }.padding(6).magicSurface(Palette.card)
            }
            railButton("打开全部库存"){showInventory=true}
        }
    }

    private var records: some View {
        LazyVStack(alignment:.leading,spacing:9) {
            if state.history.isEmpty {Text("暂无远行记录").font(.caption).foregroundStyle(Palette.muted)}
            ForEach(state.history.reversed()) {record in
                VStack(alignment:.leading,spacing:5) {
                    let destination=ExpeditionLocation.all.first{$0.id == record.locationID}?.name ?? "远行"
                    Text(record.completed ? "探险完成":"已提前返回")
                        .font(.system(size:12)).foregroundStyle(Palette.goldLight)
                    Text("\(destination) · 专注 \(Int(record.duration/60)) 分钟" + (record.companions.isEmpty ? "":" · 伙伴 \(record.companions.count) 位"))
                        .font(.system(size:10)).foregroundStyle(Palette.muted)
                    if record.rewards.values.allSatisfy({$0==0}) {Text("本次没有收获").font(.system(size:11))}
                    ForEach(NatureCatalog.forage.filter{record.rewards[$0.id,default:0]>0}) {item in
                        HStack(spacing:5) {
                            GameNatureSprite(key:item.spriteKey,size:22)
                            Text(item.name).font(.system(size:11))
                            Spacer(minLength:0)
                            Text("×\(record.rewards[item.id,default:0])").font(.system(size:11)).foregroundStyle(Palette.goldLight)
                        }
                    }
                    if !record.discoveries.isEmpty {Text("发现 \(record.discoveries.count) 种").font(.system(size:10)).foregroundStyle(Palette.muted)}
                    ForEach(NatureCatalog.wildlife.filter{record.discoveries.contains("wildlife:"+$0.id)}) {animal in
                        HStack(alignment:.top,spacing:5) {
                            GameNatureSprite(key:animal.spriteKey,size:28)
                            VStack(alignment:.leading,spacing:3) {
                                Text(animal.name).font(.system(size:11))
                                Text(animal.description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                                NatureSourceLinks(ids:animal.sourceIDs)
                            }
                        }
                    }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(8).magicSurface(Palette.card)
            }
        }
    }
}

private struct ExpeditionPartySheet: View {
    @ObservedObject var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    let location:ExpeditionLocation
    private var state:ExpeditionState { store.data.expeditionState }
    private var party:[String] { state.team(at:location.id) }

    var body: some View {
        SceneDialog(preferred:CGSize(width:450,height:480)) {
            VStack(alignment:.leading,spacing:6) {
                Text("\(location.name)的队伍 · \(party.count)/4").font(.headline)
                let stats = store.data.expeditionStats(at:location.id)
                Text("采集 \(stats.gathering) · 寻踪 \(stats.scouting) · 护行 \(stats.guarding)")
                    .font(.caption).foregroundStyle(Palette.goldLight)
            }
        } content: {
            VStack(alignment:.leading,spacing:8) {
                if state.hired.isEmpty { Text("还没有同行伙伴。可以先去酒馆招募。").foregroundStyle(Palette.muted) }
                ForEach(Companion.all.filter{state.hired.contains($0.id)}) { person in
                    let selected = party.contains(person.id)
                    HStack(spacing:8) {
                        GameNatureSprite(key:person.spriteKey,size:44)
                        VStack(alignment:.leading,spacing:3) {
                            Text(person.name)
                            Text(state.isTraveling(person.id) ? "正在远行":person.role).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength:0)
                        Button(selected ? "移出":"加入") {
                            store.commitGameChange { $0.toggleExpeditionCompanion(person.id,at:location.id) }
                        }.buttonStyle(PixelButtonStyle(primary:selected))
                            .disabled(!selected && party.count>=4)
                            .accessibilityLabel(selected ? "移出\(person.name)":"加入\(person.name)")
                    }.padding(7).magicSurface(Palette.card)
                }
            }
        } footer: {
            HStack(spacing:8) {
                if !state.hired.isEmpty {
                    Text("点击场景里的队员可查看装备。").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength:0)
                Button("完成"){dismiss()}.keyboardShortcut(.cancelAction)
            }
        }
    }
}
