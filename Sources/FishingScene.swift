import SwiftUI

struct FishingScene:View {
    @ObservedObject var store:GardenStore
    var initialLocation:String?=nil
    @State private var locationID="lake"
    @State private var selected:String?
    @State private var configuration=false
    @State private var market=false
    @State private var inventory=false
    @State private var codex=false
    @State private var rod="willow"
    @State private var bait=""
    @State private var automatic=true
    @State private var marketTab="鱼饵"
    @State private var quantity=1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var state:FishingState {store.data.fishingState}
    private var location:FishingLocation {FishingLocation.all.first{$0.id == locationID} ?? FishingLocation.all[0]}
    private var ownedRods:Set<String> {state.ownedRods.union(FishingRod.all.filter{$0.rank<=store.data.garden.rank(.rod)}.map(\.id))}
    private var bag:[String] {state.inventory.keys.filter{state.inventory[$0,default:0]>0}.sorted{(NatureItemInfo.find($0)?.name ?? $0)<(NatureItemInfo.find($1)?.name ?? $1)}}
    private var rodPosition:CGPoint {
        switch location.background {
        case "Lake":return CGPoint(x:0.465,y:0.435)
        case "Beach":return CGPoint(x:0.43,y:0.36)
        case "Tropical":return CGPoint(x:0.45,y:0.45)
        case "Polar":return CGPoint(x:0.41,y:0.44)
        case "PolarCoast":return CGPoint(x:0.44,y:0.44)
        case "SeaWarm":return CGPoint(x:0.45,y:0.41)
        default:return CGPoint(x:0.47,y:0.45)
        }
    }

    var body:some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {Text(location.name).font(.headline);Spacer();WalletView(coins:store.data.garden.coins)}
                SceneToolbar(items:[.init("渔具",action:openConfiguration),.init("鱼类图鉴",action:{codex=true}),
                    .init("库存",action:{inventory=true}),.init("户外地图",action:{SceneNavigation.open("户外地图",store:store)})])
            }
            SceneCanvas(hasSidebar:true) {size in stage(size)} sidebar:{catchCabinet}
        }.onAppear{locationID=initialLocation ?? state.locationID}
            .sheet(isPresented:$configuration){fishingConfiguration}
            .sheet(isPresented:$market){tackleMarket}
            .sheet(isPresented:$inventory){InventoryView(store:store)}
            .sheet(isPresented:$codex){fishCodex}
    }

    private func stage(_ size:CGSize)->some View {
        ZStack {
            RoomBackdrop(name:location.background).frame(width:size.width,height:size.height)
            ObjectButton(label:"选择渔竿和鱼饵",action:openConfiguration,caption:"渔具") {
                GameNatureSprite(key:"rod_"+state.rodID,size:size.width*0.13)
            }.position(x:size.width*rodPosition.x,y:size.height*rodPosition.y)
            if state.enabled,state.cast?.locationID == locationID {
                TimelineView(.animation(minimumInterval:0.12,paused:reduceMotion)) {time in
                    let drift=reduceMotion ? 0:sin(time.date.timeIntervalSinceReferenceDate*2)*2
                    GameNatureSprite(key:"fishing_float",size:size.width*0.035)
                        .offset(y:drift).position(x:size.width*0.60,y:size.height*0.60)
                }.allowsHitTesting(false)
            }
            VStack {
                HStack {Text(fishingStatus).font(.system(size:12)).padding(9).background(Palette.paper.opacity(0.94),in:PixelFrame());Spacer()}
                Spacer()
                HStack {
                    if locationID == "lake" {
                        ObjectButton(label:"渔具店",action:{market=true},caption:"渔具店") {GameSprite(sheet:"Equipment",index:9,size:size.width*0.12)}
                    }
                    Spacer()
                }
            }.padding(14)
        }.frame(width:size.width,height:size.height).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
    }

    private var fishingStatus:String {
        guard state.enabled else{return "自动钓鱼未开启"}
        if let legacy=store.data.garden.economy.trip(.fishing) {return "当前钓鱼还需 \(max(1,Int(ceil((legacy.duration-(store.gameFocus-legacy.startedAt))/60)))) 分钟专注"}
        guard let cast=state.cast else{return "等待专注开始"}
        let name=FishingLocation.all.first{$0.id == cast.locationID}?.name ?? location.name
        let running=store.data.timer.map{$0.kind != .rest && $0.resumedAt != nil} ?? false
        let seconds=max(0,Int(ceil(cast.duration-(store.gameFocus-cast.startedFocus))))
        return "\(name) · \(running ? "钓鱼中":"已暂停") · \(seconds/60):\(String(format:"%02d",seconds%60))"
    }

    private var catchCabinet:some View {
        VStack(alignment:.leading,spacing:9) {
            Text("收获袋").font(.headline).foregroundStyle(Palette.goldLight)
            Text("\(bag.count) 种 · \(state.inventory.values.reduce(0,+)) 份").font(.caption).foregroundStyle(Palette.muted)
            if let selected,let item=NatureItemInfo.find(selected),state.inventory[selected,default:0]>0 {
                Text(item.name).font(.callout)
                HStack(spacing:5) {
                    Button("出售 ×1") {if store.commitGameChange({$0.sellFishingCatch(selected,count:1)}){store.message="获得 \(Money.text(item.price))"}}
                    if NatureCatalog.fish.first(where:{$0.id == selected})?.isCookable == true {
                        Button("处理鱼肉") {if store.commitGameChange({$0.prepareFish(selected,count:1)}){store.message="鱼肉已放入食材柜"}}
                    }
                }.font(.system(size:11))
                if selected == "waterweed" {
                    Button("堆肥 ×5") {if store.commitGameChange({$0.compostWaterweed()}){store.message="作物生长增加 1 分钟"}}
                        .disabled(state.inventory["waterweed",default:0]<5 || !store.data.garden.plots.contains{$0.crop != nil})
                }
            }
            GeometryReader {geo in
                PixelScrollView {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:SceneSizing.stockColumns(width:max(1,geo.size.width-16))),spacing:8) {
                        ForEach(bag,id:\.self) {id in
                            if let item=NatureItemInfo.find(id) {
                                Button {selected=selected == id ? nil:id} label:{
                                    VStack(spacing:5) {
                                        GameNatureSprite(key:item.spriteKey,size:50)
                                        Text(item.name).font(.system(size:11)).lineLimit(2).frame(height:28)
                                        Text("×\(state.inventory[id,default:0])").font(.caption).foregroundStyle(Palette.goldLight)
                                    }.frame(maxWidth:.infinity).padding(6).magicSurface(selected == id ? Palette.card:Palette.paper)
                                }.buttonStyle(.plain).accessibilityLabel("选择收获：\(item.name)")
                            }
                        }
                    }
                    if bag.isEmpty {Text("暂无收获").font(.caption).foregroundStyle(Palette.muted).padding(.vertical,16)}
                    if let latest=state.catches.last {
                        Text(latest.itemID.flatMap{NatureItemInfo.find($0)?.name}.map{"最近钓获："+$0} ?? "最近一竿没有收获")
                            .font(.system(size:11)).foregroundStyle(Palette.muted).padding(.top,10)
                    }
                }
            }
        }.padding(10).magicSurface(Palette.paper)
    }

    private func openConfiguration() {
        guard store.data.garden.economy.trip(.fishing) == nil else{store.message="当前这次钓鱼尚未结束";return}
        rod=state.rodID;automatic=state.enabled || store.data.garden.economy.fishing == nil
        bait=state.baitID ?? "";configuration=true
    }
    private var fishingConfiguration:some View {
        SceneDialog(preferred:CGSize(width:560,height:480)) {
            HStack {Text("渔具配置").font(.title3);Spacer();Button("关闭"){configuration=false}}
        } content:{
            VStack(alignment:.leading,spacing:14) {
                PixelSelect(selection:$locationID,items:FishingLocation.all.filter{$0.level<=store.data.levelProgress.level}.map{($0.id,$0.name)})
                    .accessibilityLabel("钓鱼地点")
                PixelSelect(selection:$rod,items:FishingRod.all.filter{ownedRods.contains($0.id)}.map{($0.id,$0.name)})
                    .accessibilityLabel("选择渔竿")
                Toggle("随专注自动钓鱼",isOn:$automatic).toggleStyle(PixelToggleStyle())
                HStack {Text("鱼饵").font(.headline);Spacer();Button("无饵"){bait=""}.buttonStyle(PixelButtonStyle(primary:bait.isEmpty))}
                LazyVGrid(columns:[GridItem(.adaptive(minimum:100))],spacing:8) {
                    ForEach(location.baits.filter{$0.level<=store.data.levelProgress.level}) {item in
                        Button {bait=item.id} label:{
                            VStack(spacing:4) {
                                GameNatureSprite(key:item.spriteKey,size:46)
                                Text(item.name).font(.system(size:12))
                                Text("×\(state.baitStock[item.id,default:0])").font(.caption)
                            }.frame(maxWidth:.infinity).padding(8).magicSurface(bait == item.id ? Palette.card:Palette.paper)
                        }.buttonStyle(.plain).accessibilityLabel("选择鱼饵：\(item.name)").help(item.description)
                    }
                }
                if let chosen=NatureCatalog.baits.first(where:{$0.id == bait}),state.baitStock[chosen.id,default:0] == 0 {
                    Text("\(chosen.name)已用尽 · 当前使用无饵").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        } footer:{
            HStack {
                if locationID == "lake" {Button("渔具店"){configuration=false;market=true}}
                Spacer()
                Button("保存配置") {
                    let validBait=location.baits.first{$0.id == bait}?.id
                    if store.commitGameChange({$0.configureFishing(enabled:automatic,location:locationID,rod:rod,bait:validBait,at:store.now)}) {configuration=false}
                }.buttonStyle(PixelButtonStyle(primary:true))
            }
        }
    }

    private var tackleMarket:some View {
        SceneDialog(preferred:CGSize(width:570,height:500)) {
            HStack {Text("湖畔渔具店").font(.title3);Spacer();Button("关闭"){market=false}}
        } content:{
            VStack(alignment:.leading,spacing:12) {
                WalletView(coins:store.data.garden.coins)
                PixelTabs(selection:$marketTab,items:[("鱼饵","鱼饵"),("渔竿","渔竿")])
                if marketTab == "鱼饵" {
                    PixelSelect(selection:$quantity,items:[(1,"每次 1 份"),(5,"每次 5 份"),(10,"每次 10 份")]).accessibilityLabel("购买鱼饵数量")
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:140))],spacing:10) {
                        ForEach(NatureCatalog.baits) {item in
                            VStack(spacing:6) {
                                GameNatureSprite(key:item.spriteKey,size:54)
                                Text(item.name).font(.callout)
                                Text("拥有 \(state.baitStock[item.id,default:0]) · 等级 \(item.level)").font(.caption).foregroundStyle(Palette.muted)
                                Button("\(quantity) 份 · \(Money.text(item.price*quantity))") {_=store.commitGameChange{$0.buyFishingBait(item.id,count:quantity)}}
                                    .disabled(store.data.levelProgress.level<item.level || store.data.garden.coins<item.price*quantity)
                            }.padding(8).frame(maxWidth:.infinity).magicSurface(Palette.card).help(item.description)
                        }
                    }
                } else {
                    ForEach(FishingRod.all) {item in
                        HStack {
                            GameNatureSprite(key:item.spriteKey,size:48)
                            VStack(alignment:.leading,spacing:4) {Text(item.name);Text("等级 \(item.level) · 速度 \(Int(((1-item.speed)*100).rounded()))% 提升").font(.caption).foregroundStyle(Palette.muted)}
                            Spacer()
                            Button(ownedRods.contains(item.id) ? "已拥有":Money.text(item.price)) {_=store.commitGameChange{$0.buyFishingRod(item.id)}}
                                .disabled(ownedRods.contains(item.id) || store.data.levelProgress.level<item.level || store.data.garden.coins<item.price)
                        }.padding(8).magicSurface(Palette.card)
                    }
                }
            }
        } footer:{EmptyView()}
    }

    private var fishCodex:some View {
        SceneDialog(preferred:CGSize(width:640,height:530)) {
            HStack {Text("鱼类图鉴").font(.title3);Text("\(NatureCatalog.fish.filter{state.lifetime[$0.id,default:0]>0}.count)/\(NatureCatalog.fish.count)").font(.caption);Spacer();Button("关闭"){codex=false}}
        } content:{
            LazyVGrid(columns:[GridItem(.adaptive(minimum:170))],spacing:12) {
                ForEach(location.fish) {fish in
                    VStack(alignment:.leading,spacing:5) {
                        GameNatureSprite(key:fish.spriteKey,size:96).frame(maxWidth:.infinity)
                        Text(fish.name).font(.headline)
                        Text("\(fish.origin.name) · \(fish.rarity.name)").font(.caption).foregroundStyle(Palette.muted)
                        Text(fish.description).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
                        Text(state.lifetime[fish.id,default:0]>0 ? "累计钓获 \(state.lifetime[fish.id,default:0])":"尚未钓获").font(.caption).foregroundStyle(Palette.goldLight)
                    }.frame(maxWidth:.infinity,alignment:.topLeading).padding(10).magicSurface(Palette.card)
                }
            }
        } footer:{EmptyView()}
    }
}
