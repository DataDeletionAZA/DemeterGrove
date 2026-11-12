import SwiftUI

struct ExpeditionScene: View {
    @ObservedObject var store: GardenStore
    var initialLocation: String? = nil
    @State private var minutes: String?
    @State private var tab = "行程"
    @State private var forageNote: String?
    @State private var showInventory = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var state: ExpeditionState { store.data.expeditionState }
    private var location: ExpeditionLocation {
        let id = initialLocation ?? state.trip?.locationID ?? state.preferredLocation
        return ExpeditionLocation.all.first{$0.id == id} ?? ExpeditionLocation.all[0]
    }
    private var route: String { "探险/" + location.id }
    private var locked: Bool { store.data.levelProgress.level < location.level }
    private var legacyTrip: Bool { store.data.garden.economy.trip(.adventure) != nil }
    private var minuteInput: String { minutes ?? String(state.preferredMinutes) }
    private var duration: Int? { Int(minuteInput.trimmingCharacters(in:.whitespacesAndNewlines)).flatMap{(1...1440).contains($0) ? $0:nil} }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                if initialLocation == nil || locked {
                    HStack {
                        if initialLocation == nil {Text(location.name).font(.headline)}
                        Spacer(minLength:0)
                        if locked {Label("等级 \(location.level) 解锁",systemImage:"lock.fill").font(.caption).foregroundStyle(Palette.goldLight)}
                    }
                }
                SceneToolbar(items:[
                    SceneToolbarItem("酒馆与装备"){SceneNavigation.open("酒馆",store:store,from:store.currentRoute)},
                    SceneToolbarItem("户外地图"){SceneNavigation.open("户外地图",store:store,from:store.currentRoute)},
                    SceneToolbarItem("记录专注"){SceneNavigation.open("计时器",store:store,from:store.currentRoute)}
                ])
            }
            SceneCanvas(hasSidebar:true) {size in landscape(size)} sidebar: {cabinet}
        }.onChange(of:location.id) { _,_ in forageNote=nil }
            .onChange(of:state.history.last?.id) { _,_ in tab="记录";forageNote=nil }
            .sheet(isPresented:$showInventory) { InventoryView(store:store) }
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
        let trip=state.trip.flatMap{$0.locationID == location.id ? $0:nil}
        let party=trip?.companions ?? (state.trip == nil && !locked ? state.team:[])
        let distance=trip.map{0.05+progress($0)*0.07} ?? 0
        let eligible=NatureCatalog.forage.filter{!locked && $0.locations.contains(location.id) && $0.level <= (trip?.level ?? store.data.levelProgress.level)}
        let ready=eligible.filter{(trip?.unpackedCount($0.id) ?? 0)>0}
        let forage=ready + eligible.filter{(trip?.unpackedCount($0.id) ?? 0)==0}
        return ZStack {
            RoomBackdrop(name:location.backdrop).frame(width:w,height:h)
            ForEach(Array(party.enumerated()),id:\.element) {index,id in
                if let person=Companion.all.first(where:{$0.id == id}) {
                    ObjectButton(label:"同行伙伴\(person.name)",action:{store.message="\(person.name) · \(person.role)"},caption:person.name) {
                        GameNatureSprite(key:person.spriteKey,size:w*0.12)
                    }.position(x:w*(0.23+Double(index)*0.15+distance),y:h*(index%2 == 0 ? 0.55:0.63))
                        .animation(reduceMotion ? nil:.easeOut(duration:0.3),value:trip?.id)
                }
            }
            if let key=(trip?.discoveries ?? state.history.last(where:{$0.locationID == location.id})?.discoveries ?? []).last(where:{$0.hasPrefix("wildlife:")}),
               let animal=NatureCatalog.wildlife.first(where:{"wildlife:"+$0.id == key && $0.locations.contains(location.id)}) {
                ObjectButton(label:"观察\(animal.name)",action:{store.message=animal.name+" · "+animal.description},caption:animal.name) {
                    GameNatureSprite(key:animal.spriteKey,size:w*0.12)
                }.position(x:w*0.84,y:h*0.65)
            }
            ForEach(Array(forage.prefix(4).enumerated()),id:\.element.id) {index,item in
                let count=trip?.unpackedCount(item.id) ?? 0
                ObjectButton(label:count>0 ? "采集\(item.name) ×\(count)":item.name,action:{pickForage(item,count:count)},caption:item.name) {
                    VStack(spacing:1) {
                        GameNatureSprite(key:item.spriteKey,size:w*0.085)
                        if count>0 {
                            Text("采集 ×\(count)").font(.system(size:10,weight:.medium)).lineLimit(1)
                                .foregroundStyle(Palette.goldLight).padding(.horizontal,4).padding(.vertical,3)
                                .background(Palette.paper,in:PixelFrame())
                        }
                    }.frame(minWidth:44,minHeight:34)
                }.position(x:w*(0.17+Double(index)*0.22),y:h*0.84)
            }
            if trip != nil || forageNote != nil {
                VStack(alignment:.leading,spacing:5) {
                    if let trip {
                        Text(tripStatus(trip)).font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.goldLight)
                        PixelProgress(value:progress(trip)).frame(width:min(166,w*0.54))
                    }
                    if let forageNote {Text(forageNote).font(.caption).fixedSize(horizontal:false,vertical:true)}
                }.padding(8).background(Palette.paper,in:PixelFrame())
                    .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(9).allowsHitTesting(false)
            }
            SceneArrows(store:store,scene:route)
        }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
    }

    private func pickForage(_ item: NatureForage, count: Int) {
        guard count>0 else {
            let trip=state.trip
            let alreadyPacked=trip?.locationID == location.id && (trip?.packedRewards?[item.id] ?? 0)>0
            forageNote=alreadyPacked ? "\(item.name)已放入行囊":"尚未发现\(item.name)"
            store.message=item.description
            return
        }
        let collected=store.commitGameChange{$0.collectExpeditionForage(item.id,at:location.id)}
        forageNote=collected ? "\(item.name)已放入行囊":"暂时无法采集\(item.name)"
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
            if tab == "行程" { itineraryAction }
        }.padding(10).magicSurface(Palette.paper)
    }

    private var itinerary: some View {
        VStack(alignment:.leading,spacing:9) {
            if let trip=state.trip {
                if let destination=ExpeditionLocation.all.first(where:{$0.id == trip.locationID}), destination.id != location.id {
                    Button("返回\(destination.name)的行程") { SceneNavigation.open("探险/"+destination.id,store:store,from:store.currentRoute) }
                        .fixedSize(horizontal:false,vertical:true)
                }
                Text("\(Int(elapsed(trip)/60)) / \(Int(trip.duration/60)) 分钟专注").font(.system(size:11)).monospacedDigit()
                PixelProgress(value:progress(trip))
                Text("收获 \(trip.rewards.values.reduce(0,+)) 份 · 发现 \(trip.discoveries.count) 种").font(.system(size:11)).foregroundStyle(Palette.muted)
                Text("采集 \(trip.gathering) · 寻踪 \(trip.scouting) · 护行 \(trip.guarding)").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                if trip.locationID == location.id {
                    Text("待收入行囊 \(trip.rewards.keys.reduce(0){$0+trip.unpackedCount($1)}) 份")
                        .font(.system(size:11)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                }
            } else if legacyTrip {
                Text("行程进行中").font(.caption).fixedSize(horizontal:false,vertical:true)
            } else if locked {
                Text("尚未解锁").font(.caption).fixedSize(horizontal:false,vertical:true)
            } else {
                if !state.history.isEmpty {
                    Button("上次结算"){tab="记录"}.font(.system(size:11))
                }
                Text("行程时长").font(.system(size:12)).foregroundStyle(Palette.goldLight)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:4) {
                    ForEach([15,30,60,120],id:\.self) {value in
                        Button("\(value)"){minutes=String(value)}.lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:duration == value))
                    }
                }
                HStack(spacing:5) {
                    TextField("1～1440",text:Binding(get:{minuteInput},set:{minutes=$0}))
                        .textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("自定义探险分钟数")
                    Text("分钟").font(.system(size:11))
                }
                if duration == nil {Text("请输入 1～1440 的整数分钟。").font(.system(size:10)).foregroundStyle(Palette.goldLight)}
                Text(state.team.isEmpty ? "你独自出发":"与你同行："+state.team.compactMap{id in Companion.all.first{$0.id == id}?.name}.joined(separator:"、"))
                    .font(.system(size:11)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
            }
        }
    }

    @ViewBuilder private var itineraryAction: some View {
        if let trip=state.trip {
            if trip.locationID == location.id {
                Button("提前返回") {
                    if store.commitGameChange({$0.returnExpedition(at:store.now)}) {tab="记录"}
                }.frame(maxWidth:.infinity)
            }
        } else {
            Button("出发探险") {
                guard let duration else{return}
                if store.commitGameChange({$0.embarkExpedition(locationID:location.id,minutes:duration,at:store.now)}) {
                    forageNote=nil
                }
            }.frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:true))
                .disabled(locked || legacyTrip || duration == nil)
        }
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
                    HStack(spacing:5) {
                        if item.isCookable,let ingredient=item.ingredient {
                            Button("加工 ×1") {
                                if store.commitGameChange({$0.prepareForage(item.id,count:1)}) {store.message="\(item.name)已加工为\(ingredient)。"}
                            }.accessibilityLabel("将一份\(item.name)加工为\(ingredient)")
                        }
                        if Potion.all.contains(where:{$0.forageID == item.id}) {
                            Button("炼金"){SceneNavigation.open("炼金室",store:store,from:store.currentRoute)}.accessibilityLabel("用\(item.name)熬制魔药")
                        }
                        Button("售出 ×1") {
                            if store.commitGameChange({$0.sellForage(item.id,count:1)}) {store.message="售出\(item.name)，收到\(Money.text(item.salePrice))。"}
                        }.accessibilityLabel("售出一份\(item.name)，获得\(Money.text(item.salePrice))")
                    }.font(.system(size:10))
                }.padding(6).magicSurface(Palette.card)
            }
            Button("打开全部库存"){showInventory=true}.frame(maxWidth:.infinity)
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
