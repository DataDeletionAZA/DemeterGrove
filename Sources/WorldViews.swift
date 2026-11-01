import SwiftUI

struct WalletView: View {
    var coins:Int
    var body:some View {
        HStack(spacing:8) {
            ForEach(0..<3) { index in
                let amount=[coins/493,coins%493/29,coins%29][index]
                HStack(spacing:3) { GameSprite(sheet:"Equipment",index:index,size:21);Text("\(amount)").monospacedDigit().font(.system(size:12)) }
            }
        }.accessibilityElement(children:.ignore).accessibilityLabel(Money.text(coins))
            .help("1 金加隆 = 17 银西可；1 银西可 = 29 铜纳特")
    }
}

struct GrowthPage: View {
    @ObservedObject var store:GardenStore
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            let level=store.data.levelProgress
            HStack { Text("等级 \(level.level)").font(.title2);Spacer();WalletView(coins:store.data.garden.coins) }
            PixelProgress(value:level.experience/Double(level.needed))
            Text("经验 \(Int(level.experience)) / \(level.needed) · 专注 1 分钟获得 1 点经验").font(.callout)
            Text("升到下一级还需累计 \(Int(ceil(Double(level.needed)-level.experience))) 分钟专注。").font(.caption).foregroundStyle(Palette.muted)
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text("操作兑换").font(.headline)
                    Text("10,000 次操作 = 1 铜纳特").font(.caption).foregroundStyle(Palette.muted)
                }
                CountText(count:store.data.availableActions).font(.caption).monospacedDigit().foregroundStyle(Palette.goldLight)
                Spacer()
                Button("兑换 \(store.data.typingReward) 铜纳特") {
                    let value=store.data.typingReward
                    if store.commitGameChange({$0.redeemTyping()}){store.message="兑换了 \(value) 铜纳特。"}
                }.disabled(store.data.typingReward == 0)
            }.padding(12).magicSurface(Palette.paper)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:240))],spacing:10) {
                ForEach(Upgrade.allCases) { item in
                    let rank=store.data.garden.rank(item)
                    VStack(alignment:.leading,spacing:8) {
                        HStack { GameSprite(sheet:"Equipment",index:item.icon,size:40);Text(item.name).font(.headline);Spacer();Text("\(rank)/\(item.limit)").font(.caption) }
                        Text(item.effect).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                        if rank<item.limit {
                            Text("等级 \(item.level(rank)) · \(Money.text(item.price(rank)))").font(.caption).foregroundStyle(Palette.goldLight)
                            Button("升级\(item.name)") {
                                if store.commitGameChange({$0.upgrade(item)}){store.message="\(item.name)已升至 \(rank+1) 级。"}
                            }.disabled(level.level<item.level(rank) || store.data.garden.coins<item.price(rank))
                        } else { Text("已完成全部升级").font(.caption).foregroundStyle(Palette.sage) }
                    }.frame(maxWidth:.infinity,minHeight:142,alignment:.topLeading).padding(12).magicSurface(Palette.paper)
                }
            }
        }
    }
}

struct WardrobePage: View {
    @ObservedObject var store:GardenStore
    @State private var preview = "Stand"
    @State private var expression = -1
    @State private var clickPhase = 0
    @State private var clickExpression = 0
    @State private var nextClickExpression = 0
    @State private var clickBegan = Date()
    @State private var clickID = 0
    private var basePhase:Int { preview == "DragRight" ? 10:preview == "Focus" ? 30:preview == "Rest" ? 31:0 }
    private var selection:Binding<PetSkin> {
        Binding(get:{store.data.preferences.selectedPetSkin},set:{skin in
            _ = store.commitGameChange {$0.preferences.petSkin=skin.rawValue;return true}
        })
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            PixelTabs(selection:selection,items:PetSkin.allCases.map{($0,$0.name)})
            if selection.wrappedValue == .casual {
                VStack(spacing:12) {
                    ProfessorSprite(phase:clickPhase == 0 ? basePhase:clickPhase,size:260,
                                    motionStart:clickPhase == 0 ? nil:clickBegan,idlePose:preview == "Sit" ? 1:0,
                                    expression:expression < 0 ? clickExpression:expression,expressionActive:expression >= 0 || clickPhase != 0,
                                    basePhase:basePhase,skin:.casual)
                        .contentShape(Rectangle()).onTapGesture(perform:replayPreview)
                    HStack(spacing:10) {
                        PixelSelect(selection:$preview,items:[("Stand","站立"),("Sit","坐下"),("DragRight","拎起"),("Focus","专注"),("Rest","休息")])
                            .frame(width:140).accessibilityLabel("预览姿势")
                        PixelSelect(selection:$expression,items:[(-1,"自然")] + PetExpression.allCases.map {($0.rawValue,$0.title)})
                            .frame(width:150).accessibilityLabel("预览表情")
                        Button("点一下",action:replayPreview).font(.caption).buttonStyle(PixelButtonStyle()).disabled(preview == "DragRight")
                    }
                }.frame(maxWidth:.infinity).padding(18).magicSurface(Palette.paper)
                    .task(id:clickID) {
                        guard clickPhase != 0 else { return }
                        let activeClickID = clickID
                        do { try await Task.sleep(nanoseconds:UInt64(PetMotion.waving.duration * 1_000_000_000)) }
                        catch { return }
                        guard !Task.isCancelled, activeClickID == clickID else { return }
                        clickPhase = 0
                    }
                    .onChange(of:preview) { _,_ in resetPreview() }
                    .onDisappear(perform:resetPreview)
            } else { LegacyWardrobePage(store:store) }
        }
    }
    private func replayPreview() {
        guard preview != "DragRight" else { return }
        if expression < 0 {
            clickExpression = nextClickExpression
            nextClickExpression = (nextClickExpression + 1) % PetExpression.allCases.count
        }
        clickBegan = Date()
        clickPhase = PetMotion.waving.rawValue
        clickID += 1
    }
    private func resetPreview() {
        clickPhase = 0
        clickExpression = 0
        nextClickExpression = 0
        clickID += 1
    }
}

private struct LegacyWardrobePage: View {
    @ObservedObject var store:GardenStore
    @State private var slot:ClothingSlot = .top
    @State private var preview="Stand"
    @State private var showingBase=false
    private var wardrobeItems:[Cosmetic] {ChibiWardrobe.availableItems}
    private var categories:[ClothingSlot] {ClothingSlot.allCases.filter{category in wardrobeItems.contains{$0.slot == category}}}
    private var currentName:String {
        wardrobeItems.first{$0.id == store.data.garden.economy.worn(slot)}?.name ?? "未穿戴"
    }
    private var adjustedAccessory:Cosmetic? {
        wardrobeItems.first { $0.id == store.data.garden.economy.worn(slot) && $0.slot.isAccessory }
    }
    private func adjustmentBinding(_ id:String,_ field:WritableKeyPath<WearAdjustment,Int>) -> Binding<Double> {
        Binding(get:{Double(store.data.garden.economy.adjustment(for:id)[keyPath:field])},set:{value in
            store.commitGameChange {data in
                var adjustment=data.garden.economy.adjustment(for:id)
                adjustment[keyPath:field]=Int(value.rounded())
                if data.garden.economy.adjustments == nil {data.garden.economy.adjustments=[:]}
                data.garden.economy.adjustments?[id]=adjustment
                return true
            }
        })
    }
    private func adjustmentControl(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,display:String) -> some View {
        VStack(alignment:.leading,spacing:5) {
            HStack {Text(title);Spacer();Text(display).monospacedDigit().foregroundStyle(Palette.goldLight)}
            PixelSlider(value:value,in:range,step:1).accessibilityLabel(title).accessibilityValue(display)
        }.font(.caption)
    }
    private var removalTitle:String {
        ([ClothingSlot.outfit,.top,.bottom,.outer,.socks,.shoes,.focusOutfit].contains(slot) ? "脱下":"取下")+slot.name
    }
    private func wardrobePreview(horizontal:Bool)->some View {
        let layout=horizontal ? AnyLayout(HStackLayout(alignment:.center,spacing:24)):AnyLayout(VStackLayout(alignment:.leading,spacing:12))
        return layout {
                ProfessorSprite(phase:preview == "DragRight" ? 10:preview == "Focus" ? 30:preview == "Rest" ? 31:0,size:230,
                                economy:showingBase ? Economy(outfit:"base"):store.data.garden.economy,idlePose:preview == "Sit" ? 1:0,
                                expression:store.petExpression,expressionActive:store.petSpeech != nil,skin:.original)
                VStack(alignment:.leading,spacing:10) {
                    Text("当前穿戴").font(.title2)
                    WalletView(coins:store.data.garden.coins)
                    Text("等级 \(store.data.levelProgress.level)").font(.caption).foregroundStyle(Palette.goldLight)
                    PixelSelect(selection:$preview,items:[("Stand","站立"),("Sit","坐地"),("DragRight","拖动"),("Focus","专注"),("Rest","休息")])
                        .frame(width:130).accessibilityLabel("预览姿势")
                    Button(showingBase ? "查看穿搭":"查看底模") {showingBase.toggle()}
                }
        }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            ViewThatFits(in:.horizontal) {
                wardrobePreview(horizontal:true)
                wardrobePreview(horizontal:false)
            }.padding(12).magicSurface(Palette.paper)
            HStack(spacing:12) {
                Text("分类").font(.headline)
                if !categories.isEmpty {PixelSelect(selection:$slot,items:categories.map{($0,$0.name)}).frame(width:155).accessibilityLabel("衣物分类")}
                Spacer()
                if categories.contains(slot) {Button(removalTitle) {_=store.commitGameChange{$0.wear("",slot:slot)}}.disabled(store.data.garden.economy.worn(slot).isEmpty)}
            }
            if categories.isEmpty {Text("暂无服饰").font(.caption).foregroundStyle(Palette.muted)}
            else {Text("当前\(slot.name)：\(currentName)").font(.caption).foregroundStyle(Palette.muted)}
            if let item=adjustedAccessory {
                let adjustment=store.data.garden.economy.adjustment(for:item.id)
                DisclosureGroup("微调配饰") {
                    VStack(alignment:.leading,spacing:12) {
                        adjustmentControl("大小",value:adjustmentBinding(item.id,\.scale),range:75...125,display:"\(adjustment.scale)%")
                        adjustmentControl("左右",value:adjustmentBinding(item.id,\.x),range:-30...30,display:adjustment.x == 0 ? "居中":"\(adjustment.x < 0 ? "左":"右") \(abs(adjustment.x))")
                        adjustmentControl("上下",value:adjustmentBinding(item.id,\.y),range:-30...30,display:adjustment.y == 0 ? "默认":"\(adjustment.y < 0 ? "上":"下") \(abs(adjustment.y))")
                        Button("恢复默认位置") {_=store.commitGameChange{$0.garden.economy.adjustments?.removeValue(forKey:item.id);return true}}
                            .disabled(adjustment == WearAdjustment())
                    }.padding(.top,10)
                }.id(item.id).padding(12).magicSurface(Palette.paper)
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:240))],spacing:10) {
                ForEach(wardrobeItems.filter{$0.slot == slot}) { item in
                    let owned=item.price == 0 || store.data.garden.economy.owned.contains(item.id)
                    let wearing=store.data.garden.economy.worn(slot) == item.id
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            if let asset=item.asset,let image=ChibiWardrobe.thumbnail(asset:asset) {
                                Image(nsImage:image).resizable().interpolation(.none).scaledToFit().frame(width:62,height:62).accessibilityHidden(true)
                            }
                            else { GameSprite(sheet:"Equipment",index:item.sprite,size:62) }
                            VStack(alignment:.leading,spacing:5) {Text(item.name).font(.headline);Text("等级 \(item.level)").font(.caption).foregroundStyle(Palette.muted)}
                        }
                        if item.season != nil {Text("节日限定 · \(item.dates)").font(.caption).foregroundStyle(Palette.goldLight)}
                        if owned {
                            Text(item.price == 0 ? "免费":"已拥有").font(.caption).foregroundStyle(Palette.sage)
                            Button(wearing ? "已穿戴":"穿戴\(item.name)"){if store.commitGameChange({$0.wear(item.id,slot:item.slot)}) {showingBase=false}}.disabled(wearing)
                        } else {
                            Text(Money.text(item.price)).font(.caption)
                            Button(item.available(store.now) ? "购买\(item.name)":"尚未到售卖日期") {
                                if store.commitGameChange({$0.buyCosmetic(item,at:store.now) && $0.wear(item.id,slot:item.slot)}) {showingBase=false}
                            }.disabled(!item.available(store.now) || store.data.levelProgress.level<item.level || store.data.garden.coins<item.price)
                        }
                    }.frame(maxWidth:.infinity,minHeight:155,alignment:.topLeading).padding(12).magicSurface(Palette.paper)
                }
            }
        }.onAppear {if !categories.contains(slot),let first=categories.first {slot=first}}
            .onChange(of:slot) {_,value in
                if value == .focusOutfit {preview="Focus"}
                else if preview == "Focus" || preview == "Rest" {preview="Stand"}
            }
    }
}

struct MapPage: View {
    @ObservedObject var store:GardenStore
    var journey:JourneyKind = .fishing
    @State private var hint=""
    @State private var showingInventory=false
    @State private var showingTackleShop=false
    private var trip:Journey? {store.data.garden.economy.journey}
    private var unlocked:Bool {store.data.levelProgress.level>=journey.level}
    private var matching:Bool {trip?.kind == journey}
    private var actionLabel:String {
        if !unlocked {return "等级 \(journey.level) 解锁"}
        if let trip {
            if !matching {return "先完成\(SceneNavigation.title(trip.kind.rawValue))"}
            return trip.progress(store.data.totalFocus)>=1 ? "领取收获":"继续专注"
        }
        return journey == .fishing ? "抛竿":"出发"
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            SceneHeader {
                HStack {Spacer();WalletView(coins:store.data.garden.coins)}
                SceneToolbar(items:[
                    .init("成长",action:{SceneNavigation.open("成长",store:store)}),
                    .init("库存",action:{showingInventory=true})
                ])
            }
            if journey == .potions {PotionScene(store:store)}
            else {
                SceneCanvas(hasSidebar:true) {size in
                    let w=size.width,h=size.height
                    ZStack {
                        RoomBackdrop(name:journey.scene).frame(width:w,height:h)
                        ObjectButton(label:actionLabel,action:act,caption:actionLabel) {GameSprite(sheet:"Equipment",index:journey.icon,size:w*0.13)}
                            .disabled(!unlocked).position(x:w*(journey == .fishing ? 0.51:0.64),y:h*(journey == .fishing ? 0.54:0.73))
                        if journey == .adventure {SceneTarget(object:.forestExit,sceneSize:size,label:"户外地图"){SceneNavigation.open("户外地图",store:store)}}
                        if matching {SceneParticles().frame(width:w*0.22,height:h*0.15).position(x:w*0.53,y:h*0.58)}
                        if !unlocked {
                            Palette.paper.opacity(0.55).allowsHitTesting(false)
                            Label("等级 \(journey.level) 解锁",systemImage:"lock.fill").font(.headline).padding(14).magicSurface(Palette.paper)
                        }
                    }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
                } sidebar: {expeditionSidebar}
            }
            if journey == .potions {harvestBag}
        }
        .sheet(isPresented:$showingInventory) {InventoryView(store:store)}
        .sheet(isPresented:$showingTackleShop) {tackleShop}
    }
    private var expeditionSidebar:some View {
        PixelScrollView {
            VStack(alignment:.leading,spacing:12) {
                Text(journey == .fishing ? "渔具箱":"探险背包").font(.headline)
                HStack(alignment:.top,spacing:8) {
                    let tool:Upgrade=journey == .fishing ? .rod:.wand
                    GameSprite(sheet:"Equipment",index:tool.icon,size:38)
                    VStack(alignment:.leading,spacing:4) {
                        Text(tool.name).font(.callout)
                        Text("等级 \(store.data.garden.rank(tool)) / \(tool.limit)").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                if journey == .fishing {Button("渔具店") {showingTackleShop=true}}
                if let trip,matching {
                    PixelProgress(value:trip.progress(store.data.totalFocus))
                    Text(trip.progress(store.data.totalFocus)>=1 ? "收获已备好":"还需 \(Int(ceil(max(0,trip.duration-(store.data.totalFocus-trip.startedAt))/60))) 分钟专注")
                        .font(.caption).foregroundStyle(Palette.goldLight).fixedSize(horizontal:false,vertical:true)
                }
                if !hint.isEmpty {Text(hint).font(.caption).foregroundStyle(Palette.goldLight).fixedSize(horizontal:false,vertical:true)}
                harvestBag
            }.padding(12).frame(maxWidth:.infinity,alignment:.topLeading)
        }.magicSurface(Palette.paper)
    }
    private var tackleShop:some View {
        SceneDialog(preferred:CGSize(width:370,height:340)) {
            HStack {Text("渔具店").font(.title2);Spacer();WalletView(coins:store.data.garden.coins)}
        } content: {
            let tool=Upgrade.rod
            let rank=store.data.garden.rank(tool)
            VStack(alignment:.leading,spacing:12) {
                HStack {GameSprite(sheet:"Equipment",index:tool.icon,size:48);Text("钓竿 · 等级 \(rank)").font(.headline)}
                Text(tool.effect).font(.callout).foregroundStyle(Palette.muted)
                if rank<tool.limit {
                    Text("等级 \(tool.level(rank)) · \(Money.text(tool.price(rank)))").font(.caption).foregroundStyle(Palette.goldLight)
                    Button("升级钓竿") {
                        if store.commitGameChange({$0.upgrade(tool)}) {store.message="钓竿已升至 \(rank+1) 级。"}
                    }.disabled(store.data.levelProgress.level<tool.level(rank) || store.data.garden.coins<tool.price(rank))
                } else {Text("已完成全部升级").font(.caption).foregroundStyle(Palette.sage)}
            }
        } footer: {HStack {Spacer();Button("关闭") {showingTackleShop=false}}}
    }
    private var harvestKeys:[String] {
        store.data.garden.economy.finds.keys.sorted().filter {key in
            guard store.data.garden.economy.finds[key,default:0]>0 else{return false}
            if journey == .fishing {return key.contains("鱼")}
            if journey == .adventure {return !key.contains("鱼") && !Potion.all.contains{$0.id == key}}
            return true
        }
    }
    private var harvestBag:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("收获袋").font(.headline)
            if harvestKeys.isEmpty {Text("暂无收获").font(.caption).foregroundStyle(Palette.muted)}
            else {
                ForEach(harvestKeys,id:\.self) {key in
                    let count=store.data.garden.economy.finds[key,default:0]
                    if count>0 {
                        let potion=Potion.all.first{$0.id == key}
                        VStack(alignment:.leading,spacing:8) {
                            HStack(spacing:6) {
                                GameSprite(sheet:"Equipment",index:potion != nil ? 11:key.contains("鱼") ? 8:10,size:30)
                                Text("\(potion?.name ?? key) ×\(count)").font(.callout).fixedSize(horizontal:false,vertical:true)
                            }
                            if let potion {Button("使用") {
                                var usable=false
                                if store.commitGameChange({usable=$0.usePotion(potion.id);return usable}) {store.message=potion.benefit}
                                else if !usable {store.message="先在农场播种，再使用繁盛药剂。"}
                            }.accessibilityLabel("使用\(potion.name)")}
                            Button("出售 · \(Money.text(store.data.findPrice(key)))"){if store.commitGameChange({$0.sellFind(key)}){store.message="已出售\(potion?.name ?? key)。"}}.accessibilityLabel("出售\(potion?.name ?? key)")
                        }.padding(8).magicSurface(Palette.paper)
                    }
                }
            }
        }
    }
    private func act() {
        guard unlocked else{return}
        if let trip {
            guard matching else{hint="\(SceneNavigation.title(trip.kind.rawValue))还未结束。";return}
            guard trip.progress(store.data.totalFocus)>=1 else {SceneNavigation.open("计时器",store:store);return}
            var result:String?
            if store.commitGameChange({result=$0.collectJourney();return result != nil}),let result {store.message=result;hint=""}
        } else if store.commitGameChange({$0.embark(journey)}) {store.message="\(journey.rawValue)已开始，记录专注后回来领取。";hint=""}
    }
}
