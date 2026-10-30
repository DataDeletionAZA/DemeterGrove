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
                Text("进度 \((store.data.totalActions-store.data.consumedActions)%10000)/10,000").font(.caption).monospacedDigit().foregroundStyle(Palette.goldLight)
                Spacer()
                Button("兑换 \(store.data.typingReward) 铜纳特") {
                    let value=store.data.typingReward
                    if store.data.redeemTyping(){store.message="兑换了 \(value) 铜纳特。"}
                }.disabled(store.data.typingReward == 0)
            }.padding(12).magicSurface(Palette.paper)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(Upgrade.allCases) { item in
                    let rank=store.data.garden.rank(item)
                    VStack(alignment:.leading,spacing:8) {
                        HStack { GameSprite(sheet:"Equipment",index:item.icon,size:40);Text(item.name).font(.headline);Spacer();Text("\(rank)/\(item.limit)").font(.caption) }
                        Text(item.effect).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                        if rank<item.limit {
                            Text("等级 \(item.level(rank)) · \(Money.text(item.price(rank)))").font(.caption).foregroundStyle(Palette.goldLight)
                            Button("升级\(item.name)") {
                                if store.data.upgrade(item){store.message="\(item.name)已升至 \(rank+1) 级。"}
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
    @State private var slot:ClothingSlot = .outfit
    private var currentName:String {
        Cosmetic.all.first{$0.id == store.data.garden.economy.worn(slot)}?.name ?? "未穿戴"
    }
    private var adjustedAccessory:Cosmetic? {
        Cosmetic.all.first { $0.id == store.data.garden.economy.worn(slot) && $0.slot.isAccessory }
    }
    private func adjustmentBinding(_ id:String,_ field:WritableKeyPath<WearAdjustment,Int>) -> Binding<Double> {
        Binding(get:{Double(store.data.garden.economy.adjustment(for:id)[keyPath:field])},set:{value in
            var adjustment=store.data.garden.economy.adjustment(for:id)
            adjustment[keyPath:field]=Int(value.rounded())
            if store.data.garden.economy.adjustments == nil {store.data.garden.economy.adjustments=[:]}
            store.data.garden.economy.adjustments?[id]=adjustment
        })
    }
    private func adjustmentControl(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,display:String) -> some View {
        VStack(alignment:.leading,spacing:5) {
            HStack {Text(title);Spacer();Text(display).monospacedDigit().foregroundStyle(Palette.goldLight)}
            Slider(value:value,in:range,step:1).accessibilityLabel(title).accessibilityValue(display)
        }.font(.caption)
    }
    private var removalTitle:String {
        ([ClothingSlot.outfit,.top,.bottom,.outer,.socks,.shoes].contains(slot) ? "脱下":"取下")+slot.name
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:24) {
                ProfessorSprite(phase:store.petPhase,size:230,economy:store.data.garden.economy,idlePose:store.idlePose,expression:store.petExpression,basePhase:store.petBasePhase)
                VStack(alignment:.leading,spacing:10) {
                    Text("当前穿戴").font(.title2)
                    WalletView(coins:store.data.garden.coins)
                    Text("等级 \(store.data.levelProgress.level)").font(.caption).foregroundStyle(Palette.goldLight)
                    Text("上衣和下装可分别搭配，配饰可单独穿脱。").font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                    Button("穿上黑色长袍") {_=store.data.wear("black",slot:.outfit)}
                    Button("查看底模") {
                        for category in ClothingSlot.allCases {_=store.data.wear("",slot:category)}
                    }
                }
                Spacer()
            }.padding(12).magicSurface(Palette.paper)
            HStack(spacing:12) {
                Text("分类").font(.headline)
                PixelSelect(selection:$slot,items:ClothingSlot.allCases.map{($0,$0.name)}).frame(width:155).accessibilityLabel("衣物分类")
                Spacer()
                Button(removalTitle) {_=store.data.wear("",slot:slot)}.disabled(store.data.garden.economy.worn(slot).isEmpty)
            }
            Text("当前\(slot.name)：\(currentName)").font(.caption).foregroundStyle(Palette.muted)
            if let item=adjustedAccessory {
                let adjustment=store.data.garden.economy.adjustment(for:item.id)
                DisclosureGroup("微调配饰") {
                    VStack(alignment:.leading,spacing:12) {
                        adjustmentControl("大小",value:adjustmentBinding(item.id,\.scale),range:75...125,display:"\(adjustment.scale)%")
                        adjustmentControl("左右",value:adjustmentBinding(item.id,\.x),range:-30...30,display:adjustment.x == 0 ? "居中":"\(adjustment.x < 0 ? "左":"右") \(abs(adjustment.x))")
                        adjustmentControl("上下",value:adjustmentBinding(item.id,\.y),range:-30...30,display:adjustment.y == 0 ? "默认":"\(adjustment.y < 0 ? "上":"下") \(abs(adjustment.y))")
                        Button("恢复默认位置") {store.data.garden.economy.adjustments?.removeValue(forKey:item.id)}
                            .disabled(adjustment == WearAdjustment())
                    }.padding(.top,10)
                }.id(item.id).padding(12).magicSurface(Palette.paper)
            }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(Cosmetic.all.filter{$0.slot == slot}) { item in
                    let owned=item.price == 0 || store.data.garden.economy.owned.contains(item.id)
                    let wearing=store.data.garden.economy.worn(slot) == item.id
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            if let asset=item.asset,let image=DollImages.thumbnails[asset] {
                                Image(nsImage:image).resizable().interpolation(.none).scaledToFit().frame(width:62,height:62).accessibilityHidden(true)
                            }
                            else { GameSprite(sheet:"Equipment",index:item.sprite,size:62) }
                            VStack(alignment:.leading,spacing:5) {Text(item.name).font(.headline);Text("等级 \(item.level)").font(.caption).foregroundStyle(Palette.muted)}
                        }
                        if item.season != nil {Text("节日限定 · \(item.dates)").font(.caption).foregroundStyle(Palette.goldLight)}
                        if owned {
                            Text(item.price == 0 ? "免费":"已拥有").font(.caption).foregroundStyle(Palette.sage)
                            Button(wearing ? "已穿戴":"穿戴\(item.name)"){_=store.data.wear(item.id,slot:item.slot)}.disabled(wearing)
                        } else {
                            Text(Money.text(item.price)).font(.caption)
                            Button(item.available(store.now) ? "购买\(item.name)":"尚未到售卖日期") {
                                if store.data.buyCosmetic(item,at:store.now){_=store.data.wear(item.id,slot:item.slot)}
                            }.disabled(!item.available(store.now) || store.data.levelProgress.level<item.level || store.data.garden.coins<item.price)
                        }
                    }.frame(maxWidth:.infinity,minHeight:155,alignment:.topLeading).padding(12).magicSurface(Palette.paper)
                }
            }
        }
    }
}

struct MapPage: View {
    @ObservedObject var store:GardenStore
    @State private var selected:JourneyKind = .fishing
    @State private var recipeID="dew"
    @State private var hint=""
    private var trip:Journey? {store.data.garden.economy.journey}
    private var unlocked:Bool {store.data.levelProgress.level>=selected.level}
    private var matching:Bool {trip?.kind == selected}
    private var actionLabel:String {
        if !unlocked {return "等级 \(selected.level) 解锁"}
        if let trip {
            if trip.kind != selected {return "先完成\(trip.kind.rawValue)"}
            return trip.progress(store.data.totalFocus)>=1 ? "领取收获":"继续专注"
        }
        return selected == .fishing ? "抛竿":selected == .adventure ? "出发":"开始熬制"
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("等级 \(store.data.levelProgress.level)").font(.headline);Spacer();WalletView(coins:store.data.garden.coins) }
            PixelTabs(selection:$selected,items:JourneyKind.allCases.map{($0,$0.rawValue)})
            GeometryReader { geo in
                let w=geo.size.width,h=geo.size.height
                ZStack {
                    RoomBackdrop(name:selected.scene).frame(width:w,height:h).clipped()
                    if selected == .potions {
                        ObjectButton(label:actionLabel,action:act) {GameSprite(index:7,size:w*0.19)}.disabled(!unlocked).position(x:w*0.73,y:h*0.57)
                        if matching {SceneParticles(steam:true).frame(width:60,height:80).position(x:w*0.73,y:h*0.39)}
                    } else {
                        ObjectButton(label:actionLabel,action:act) {GameSprite(sheet:"Equipment",index:selected.icon,size:w*0.13)}
                            .disabled(!unlocked).position(x:w*(selected == .fishing ? 0.51:0.64),y:h*(selected == .fishing ? 0.54:0.73))
                        if matching {
                            SceneParticles().frame(width:w*0.22,height:h*0.15).position(x:w*0.53,y:h*0.58)
                        }
                    }
                    if !unlocked {
                        Palette.paper.opacity(0.55).allowsHitTesting(false)
                        Label("等级 \(selected.level) 解锁",systemImage:"lock.fill").font(.headline)
                            .padding(14).magicSurface(Palette.paper).position(x:w*0.5,y:h*0.45)
                    }
                    VStack(spacing:5) {
                        Text(actionLabel).font(.system(size:13,weight:.medium))
                        if let trip,matching {
                            PixelProgress(value:trip.progress(store.data.totalFocus)).frame(width:w*0.30)
                            Text(trip.progress(store.data.totalFocus)>=1 ? "收获已备好" : "还需 \(Int(ceil(max(0,trip.duration-(store.data.totalFocus-trip.startedAt))/60))) 分钟专注").font(.caption)
                        }
                    }.padding(10).background(Palette.paper.opacity(0.9)).position(x:w*0.5,y:h*0.90)
                }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            }.aspectRatio(1.5,contentMode:.fit)
            if !hint.isEmpty {Text(hint).font(.callout).foregroundStyle(Palette.goldLight)}
            if selected == .potions {
                ForEach(Potion.all) { potion in
                    HStack {
                        Button {recipeID=potion.id} label:{Image(systemName:recipeID == potion.id ? "largecircle.fill.circle":"circle")}.buttonStyle(.plain).accessibilityLabel("选择\(potion.name)")
                        VStack(alignment:.leading,spacing:4) {
                            Text(potion.name)
                            Text("\(potion.ingredient) ×1（持有 \(store.data.garden.ingredients[potion.ingredient,default:0])）+ \(potion.material) ×1（持有 \(store.data.garden.economy.finds[potion.material,default:0])）").font(.caption).foregroundStyle(Palette.muted)
                            Text(potion.benefit).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                    }.padding(10).magicSurface(Palette.paper)
                }
            }
            if !store.data.garden.economy.finds.filter({$0.value>0}).isEmpty {
                Text("收获袋").font(.headline)
                ForEach(store.data.garden.economy.finds.keys.sorted(),id:\.self) { key in
                    let count=store.data.garden.economy.finds[key,default:0]
                    if count>0 {
                        let potion=Potion.all.first{$0.id == key}
                        HStack {
                            GameSprite(sheet:"Equipment",index:potion != nil ? 11:key.contains("鱼") ? 8:10,size:35)
                            Text("\(potion?.name ?? key) ×\(count)").font(.callout)
                            Spacer()
                            if let potion {Button("使用"){if store.data.usePotion(potion.id){hint=potion.benefit}else{hint="先在农场播种，再使用繁盛药剂。"}}.accessibilityLabel("使用\(potion.name)")}
                            Button("出售 · \(Money.text(store.data.findPrice(key)))"){if store.data.sellFind(key){hint="已出售\(potion?.name ?? key)。"}}.accessibilityLabel("出售\(potion?.name ?? key)")
                        }.padding(8).magicSurface(Palette.paper)
                    }
                }
            }
        }.onChange(of:selected) { _,_ in hint="" }
    }
    private func act() {
        guard unlocked else{return}
        if let trip {
            guard trip.kind == selected else{hint="\(trip.kind.rawValue)还未结束。";return}
            if let result=store.data.collectJourney(){hint=result}
            else {store.pet?.openTool("计时器")}
        } else if store.data.embark(selected,recipe:selected == .potions ? recipeID:nil) {hint="\(selected.rawValue)已开始，记录专注后回来领取。"}
        else {hint="熬制需要配方中的食材和探险材料。"}
    }
}
