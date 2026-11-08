import SwiftUI

struct ExpeditionScene: View {
    @ObservedObject var store: GardenStore
    var initialLocation: String? = nil
    @State private var locationID = "forest"
    @State private var minutes = "30"
    @State private var tab = "行程"
    private var state: ExpeditionState { store.data.expeditionState }
    private var location: ExpeditionLocation { ExpeditionLocation.all.first{$0.id == (state.trip?.locationID ?? locationID)} ?? ExpeditionLocation.all[0] }
    private var duration: Int? { Int(minutes.trimmingCharacters(in:.whitespacesAndNewlines)).flatMap{(1...1440).contains($0) ? $0:nil} }

    var body: some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Text("\(location.name) · \(state.trip == nil ? "准备出发":"旅途中")").font(.system(size:13))
                    Spacer(minLength:0)
                    Text(state.trip.map{"同行伙伴 \($0.companions.count)/4"} ?? "下次同行 \(state.team.count)/4").font(.system(size:12)).foregroundStyle(Palette.goldLight)
                }
                SceneToolbar(items:[
                    SceneToolbarItem("酒馆与装备"){SceneNavigation.open("酒馆",store:store)},
                    SceneToolbarItem("户外地图"){SceneNavigation.open("户外地图",store:store)},
                    SceneToolbarItem("记录专注"){SceneNavigation.open("计时器",store:store)}
                ])
            }
            SceneCanvas(hasSidebar:true) {size in landscape(size)} sidebar: {cabinet}
        }.onAppear {
            locationID=initialLocation ?? state.preferredLocation
            minutes=String(state.preferredMinutes)
        }
    }

    private func progress(_ trip:ExpeditionTrip) -> Double {max(0,min(1,(store.gameFocus-trip.startedFocus)/trip.duration))}
    private func landscape(_ size:CGSize) -> some View {
        let w=size.width,h=size.height
        let trip=state.trip
        let party=trip?.companions ?? state.team
        let progress=trip.map{self.progress($0)} ?? 0
        let forage=NatureCatalog.forage.filter{$0.locations.contains(location.id) && $0.level <= store.data.levelProgress.level}
        return ZStack {
            RoomBackdrop(name:location.backdrop).frame(width:w,height:h)
            ForEach(Array(forage.prefix(4).enumerated()),id:\.element.id) {index,item in
                ObjectButton(label:item.name,action:{store.message=item.name+" · "+item.description},caption:item.name) {
                    GameNatureSprite(key:item.spriteKey,size:w*0.065)
                }.position(x:w*(0.15+Double(index)*0.23),y:h*(index%2 == 0 ? 0.72:0.88))
            }
            ForEach(Array(party.enumerated()),id:\.element) {index,id in
                if let person=Companion.all.first(where:{$0.id == id}) {
                    ObjectButton(label:"同行伙伴\(person.name)",action:{store.message="\(person.name) · \(person.role)"},caption:person.name) {
                        GameNatureSprite(key:person.spriteKey,size:w*0.12)
                    }.position(x:w*(0.25+Double(index)*0.15+progress*0.10),y:h*(index%2 == 0 ? 0.79:0.85))
                }
            }
            if let key=(trip?.discoveries ?? state.history.last?.discoveries ?? []).last(where:{$0.hasPrefix("wildlife:")}),
               let animal=NatureCatalog.wildlife.first(where:{"wildlife:"+$0.id == key && $0.locations.contains(location.id)}) {
                ObjectButton(label:"观察\(animal.name)",action:{store.message=animal.name+" · "+animal.description},caption:animal.name) {
                    GameNatureSprite(key:animal.spriteKey,size:w*0.12)
                }.position(x:w*0.88,y:h*0.74)
            }
            if let trip {
                PixelProgress(value:self.progress(trip)).frame(width:w*0.38).position(x:w*0.5,y:h*0.10)
            }
        }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
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
            if let trip=state.trip {
                Text("本次行程").font(.system(size:12)).foregroundStyle(Palette.goldLight)
                Text("\(Int(min(trip.duration,max(0,store.gameFocus-trip.startedFocus))/60)) / \(Int(trip.duration/60)) 分钟专注").font(.system(size:11)).monospacedDigit()
                PixelProgress(value:progress(trip))
                Text("已采集 \(trip.rewards.values.reduce(0,+)) 份 · 发现 \(trip.discoveries.count) 种").font(.system(size:11)).foregroundStyle(Palette.muted)
                Text("采集 \(trip.gathering) · 寻踪 \(trip.scouting) · 护行 \(trip.guarding)").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                Button("提前返回，带回收获") {
                    if store.commitGameChange({$0.returnExpedition(at:store.now)}) {store.message="队伍已返回，收获已放进行囊。";tab="行囊"}
                }.frame(maxWidth:.infinity)
            }
            Text("目的地").font(.system(size:12)).foregroundStyle(Palette.goldLight)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:5) {
                ForEach(ExpeditionLocation.all) {place in
                    Button {locationID=place.id} label:{
                        VStack(spacing:3) {Text(place.name).font(.system(size:11));Text("等级 \(place.level)").font(.system(size:9)).foregroundStyle(Palette.muted)}.frame(maxWidth:.infinity)
                    }.buttonStyle(PixelButtonStyle(primary:locationID == place.id)).disabled(store.data.levelProgress.level < place.level)
                }
            }
            Text("行程时长").font(.system(size:12)).foregroundStyle(Palette.goldLight)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:4) {
                ForEach([15,30,60,120],id:\.self) {value in
                    Button("\(value)"){minutes=String(value)}.lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:duration == value))
                }
            }
            HStack(spacing:5) {TextField("1～1440",text:$minutes).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("自定义探险分钟数");Text("分钟").font(.system(size:11))}
            if duration == nil {Text("请输入 1～1440 的整数分钟。").font(.system(size:10)).foregroundStyle(Palette.goldLight)}
            Text(state.team.isEmpty ? "你独自出发":"与你同行："+state.team.compactMap{id in Companion.all.first{$0.id == id}?.name}.joined(separator:"、"))
                .font(.system(size:11)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
            Button("出发探险") {
                guard let duration else{return}
                if store.commitGameChange({$0.embarkExpedition(locationID:locationID,minutes:duration,at:store.now)}) {store.message="队伍已出发。"}
            }.frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:true))
                .disabled(state.trip != nil || duration == nil || store.data.levelProgress.level < (ExpeditionLocation.all.first{$0.id == locationID}?.level ?? Int.max))
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
                    HStack(spacing:5) {
                        if item.isCookable,let ingredient=item.ingredient {
                            Button("加工 ×1") {
                                if store.commitGameChange({$0.prepareForage(item.id,count:1)}) {store.message="\(item.name)已加工为\(ingredient)。"}
                            }.accessibilityLabel("将一份\(item.name)加工为\(ingredient)")
                        }
                        if Potion.all.contains(where:{$0.forageID == item.id}) {
                            Button("炼金"){SceneNavigation.open("炼金室",store:store)}.accessibilityLabel("用\(item.name)熬制魔药")
                        }
                        Button("售出 ×1") {
                            if store.commitGameChange({$0.sellForage(item.id,count:1)}) {store.message="售出\(item.name)，收到\(Money.text(item.salePrice))。"}
                        }.accessibilityLabel("售出一份\(item.name)，获得\(Money.text(item.salePrice))")
                    }.font(.system(size:10))
                }.padding(6).magicSurface(Palette.card)
            }
            Button("打开全部库存"){SceneNavigation.open("库存",store:store)}.frame(maxWidth:.infinity)
        }
    }

    private var records: some View {
        VStack(alignment:.leading,spacing:9) {
            if state.history.isEmpty {Text("暂无远行记录").font(.caption).foregroundStyle(Palette.muted)}
            ForEach(state.history.reversed()) {record in
                VStack(alignment:.leading,spacing:5) {
                    Text((ExpeditionLocation.all.first{$0.id == record.locationID}?.name ?? "远行") + (record.completed ? " · 已完成":" · 提前返回"))
                        .font(.system(size:12)).foregroundStyle(Palette.goldLight)
                    Text("专注 \(Int(record.duration/60)) 分钟 · 伙伴 \(record.companions.count) 位").font(.system(size:10)).foregroundStyle(Palette.muted)
                    Text("带回 \(record.rewards.values.reduce(0,+)) 份收获 · 发现 \(record.discoveries.count) 种").font(.system(size:10))
                }.frame(maxWidth:.infinity,alignment:.leading).padding(8).magicSurface(Palette.card)
            }
        }
    }
}
