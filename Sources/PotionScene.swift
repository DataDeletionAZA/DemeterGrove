import SwiftUI

struct PotionScene:View {
    @ObservedObject var store:GardenStore
    @State private var selection=PotionSelection()
    @State private var category="全部"
    @State private var cabinetTab="材料柜"
    @State private var showingBrew=false
    @State private var showingRecipes=false
    @State private var showingInventory=false
    @State private var heat:AlchemyHeat = .gentle
    @State private var minuteText="15"
    private var legacy:Journey? {store.data.garden.economy.trip(.potions)}
    private var brew:AlchemyBrew? {store.data.alchemyState.active}
    private var brewing:Bool {brew != nil || legacy != nil}
    private var unlocked:Bool {store.data.levelProgress.level>=JourneyKind.potions.level}
    private var progress:Double {brew?.progress(store.gameFocus) ?? legacy?.progress(store.gameFocus) ?? 0}
    private var ready:Bool {brewing && progress>=1}
    private var materials:[AlchemyMaterial] {selection.portions.map{.init(name:$0.name,kind:$0.kind)}}
    private var minutes:Int? {Int(minuteText.trimmingCharacters(in:.whitespacesAndNewlines)).flatMap{(1...1440).contains($0) ? $0:nil}}
    private var label:String {ready ? "领取魔药":brewing ? "查看熬制":"熬制魔药"}
    var body:some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader(store:store,toolbar:[
                .init("成长",action:{SceneNavigation.open("成长",store:store,from:store.currentRoute)}),
                .init("库存",action:{if let pet=store.pet {pet.openInventory()} else {showingInventory=true}})
            ])
            SceneCanvas(hasSidebar:true) {size in
                let w=size.width,h=size.height
                ZStack {
                    RoomBackdrop(name:"Laboratory").frame(width:w,height:h)
                    ObjectButton(label:"打开魔药配方册",action:{showingRecipes=true},caption:"配方册") {
                        GameSceneBook(kind:.alchemy,size:w*0.22)
                    }.position(x:w*0.18,y:h*0.69)
                    ObjectButton(label:label,action:openPot,caption:label) {GameSprite(index:7,size:w*0.19)}
                        .disabled(!unlocked).position(x:w*0.735,y:h*0.59)
                    if brewing {
                        PotionBrewAnimation(progress:progress,ready:ready)
                            .frame(width:w*0.25,height:h*0.38).position(x:w*0.735,y:h*0.54)
                        if ready {
                            ObjectButton(label:"领取魔药",action:openPot,caption:"领取") {GameSprite(sheet:"Equipment",index:11,size:w*0.10)}
                                .position(x:w*0.55,y:h*0.68)
                        }
                    } else {
                        ForEach(selection.portions) {portion in
                            let places:[CGPoint]=[.init(x:0.36,y:0.62),.init(x:0.46,y:0.62),.init(x:0.56,y:0.62),.init(x:0.40,y:0.735),.init(x:0.52,y:0.735)]
                            PotionTableItem(portion:portion,size:w*0.08) {selection.remove(portion.id)}
                                .position(x:w*places[portion.slot].x,y:h*places[portion.slot].y)
                        }
                    }
                    if !unlocked {
                        Palette.paper.opacity(0.55).allowsHitTesting(false)
                        Text("等级 8 解锁").font(.headline).padding(14).magicSurface(Palette.paper)
                    }
                    SceneArrows(store:store,scene:"炼金室")
                }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            } sidebar: {cabinet}
        }.sheet(isPresented:$showingBrew){brewWindow}
            .sheet(isPresented:$showingRecipes){recipeWindow}
            .sheet(isPresented:$showingInventory){InventoryView(store:store)}
    }
    private var cabinet:some View {
        VStack(alignment:.leading,spacing:9) {
            PixelTabs(selection:$cabinetTab,items:[("材料柜","材料柜"),("收获袋","收获袋")])
            if cabinetTab == "材料柜" {
                PixelSelect(selection:$category,items:(["全部"]+IngredientCategory.allCases.map(\.rawValue)+["探险材料"]).map{($0,$0)})
                    .accessibilityLabel("魔药材料分类")
                PixelScrollView {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:82))],spacing:10) {
                        if category != "探险材料" {
                            ForEach(Ingredient.allCases.filter{store.data.ingredientCount($0)>0 && (category == "全部" || category == $0.category.rawValue)}) {item in
                                materialButton(.init(name:item.rawValue,kind:.ingredient))
                            }
                        }
                        if category == "全部" || category == "探险材料" {
                            ForEach(store.data.potionMaterialNames,id:\.self) {name in materialButton(.init(name:name,kind:.material))}
                        }
                    }.padding(.trailing,16)
                }
                HStack {Text("材料 \(selection.portions.count)/5").font(.caption);Spacer();Button("取回全部"){selection.clear()}.disabled(selection.portions.isEmpty || brewing)}
            } else {harvestBag}
            if brewing {
                PixelProgress(value:progress)
                Text(ready ? "魔药已熬好":"还需 \(remainingMinutes) 分钟专注").font(.caption).foregroundStyle(Palette.goldLight)
                Button(ready ? "领取":"查看熬制",action:openPot)
            }
        }.padding(10).magicSurface(Palette.paper)
    }
    private var remainingMinutes:Int {
        let duration=brew?.duration ?? legacy?.duration ?? 0
        let start=brew?.startedFocus ?? legacy?.startedAt ?? store.gameFocus
        return Int(ceil(max(0,duration-(store.gameFocus-start))/60))
    }
    private func materialButton(_ material:AlchemyMaterial)->some View {
        let available=store.data.alchemyCount(material)
        let selected=selection.count(material.name,kind:material.kind)>0
        let traits=material.profile?.traits.map(\.name).joined(separator:" · ") ?? ""
        return Button {
            _=selection.add(material.name,kind:material.kind,available:available)
        } label: {
            VStack(spacing:4) {
                PotionMaterialArt(name:material.name,kind:material.kind,size:44)
                Text(material.name).font(.system(size:11)).lineLimit(2)
                Text(traits).font(.system(size:10)).foregroundStyle(Palette.muted).lineLimit(2)
                Text(selected ? "已选":"×\(available)").font(.caption).foregroundStyle(Palette.goldLight)
            }.frame(maxWidth:.infinity).padding(.vertical,4)
        }.buttonStyle(.plain).help(material.name+" · "+traits)
            .accessibilityLabel("取用魔药材料："+material.name)
            .disabled(!unlocked || brewing || selected || available<=0 || selection.portions.count>=5)
    }
    private var harvestBag:some View {
        PixelScrollView {
            VStack(alignment:.leading,spacing:10) {
                ForEach(store.data.alchemyState.batches) {batch in
                    VStack(alignment:.leading,spacing:7) {
                        HStack {GameSprite(sheet:"Equipment",index:11,size:34);Text(batch.name+" ×\(batch.count)").font(.callout)}
                        Text("品质 \(batch.outcome.quality)").font(.caption).foregroundStyle(Palette.goldLight)
                        ForEach(batch.outcome.effects,id:\.self) {effect in Text(effect.text(quality:batch.outcome.quality)).font(.caption).foregroundStyle(Palette.muted)}
                        LazyVGrid(columns:[GridItem(.adaptive(minimum:88),spacing:6)],spacing:6) {
                            Button {
                                if store.commitGameChange({$0.useAlchemy(batch.id)}) {store.message="已使用"+batch.name}
                                else if batch.outcome.effects.contains(.growth) && !store.data.garden.plots.contains(where:{$0.crop != nil}) {store.message="当前没有已种作物"}
                            } label:{Text("使用").frame(maxWidth:.infinity,minHeight:16,maxHeight:16)}
                            Button {if store.commitGameChange({$0.sellAlchemy(batch.id)}) {store.message="已出售"+batch.name}} label:{
                                Text("出售 · \(Money.text(batch.price))").lineLimit(1).minimumScaleFactor(0.75)
                                    .frame(maxWidth:.infinity,minHeight:16,maxHeight:16)
                            }
                        }
                    }.padding(9).magicSurface(Palette.card)
                }
                ForEach(Potion.all.filter{store.data.garden.economy.finds[$0.id,default:0]>0}) {potion in
                    VStack(alignment:.leading,spacing:7) {
                        Text(potion.name+" ×\(store.data.garden.economy.finds[potion.id,default:0])").font(.callout)
                        Text(potion.benefit).font(.caption).foregroundStyle(Palette.muted)
                        LazyVGrid(columns:[GridItem(.adaptive(minimum:88),spacing:6)],spacing:6) {
                            Button {if store.commitGameChange({$0.usePotion(potion.id)}) {store.message=potion.benefit}else{store.message="当前没有已种作物"}} label:{
                                Text("使用").frame(maxWidth:.infinity,minHeight:16,maxHeight:16)
                            }
                            Button {_=store.commitGameChange{$0.sellFind(potion.id)}} label:{
                                Text("出售 · \(Money.text(potion.price))").lineLimit(1).minimumScaleFactor(0.75)
                                    .frame(maxWidth:.infinity,minHeight:16,maxHeight:16)
                            }
                        }
                    }.padding(9).magicSurface(Palette.card)
                }
                if store.data.alchemyState.batches.isEmpty && !Potion.all.contains(where:{store.data.garden.economy.finds[$0.id,default:0]>0}) {Text("暂无收获").font(.caption).foregroundStyle(Palette.muted)}
            }.padding(.trailing,16)
        }
    }
    private var brewWindow:some View {
        SceneDialog(preferred:CGSize(width:540,height:520)) {
            HStack {Text(brewing ? "正在熬制":"熬制魔药").font(.title3);Spacer();Button("关闭"){showingBrew=false}}
        } content: {
            VStack(alignment:.leading,spacing:14) {
                if brewing {
                    Text(brew?.formula.materials.map(\.name).joined(separator:" + ") ?? legacy?.recipe.flatMap{id in Potion.all.first{$0.id == id}?.name} ?? "魔药").font(.headline)
                    if let brew {Text("\(brew.formula.heat.name) · \(brew.formula.minutes) 分钟专注").font(.caption)}
                    PixelProgress(value:progress)
                    Text(ready ? "可以领取":"还需 \(remainingMinutes) 分钟专注").font(.caption).foregroundStyle(Palette.goldLight)
                } else {
                    Text(materials.isEmpty ? "尚未选择材料":materials.map(\.name).joined(separator:" + ")).font(.headline)
                    ForEach(materials) {material in
                        HStack {PotionMaterialArt(name:material.name,kind:material.kind,size:30);Text(material.name);Spacer();Text(material.profile?.traits.map(\.name).joined(separator:" · ") ?? "").font(.caption).foregroundStyle(Palette.muted)}
                    }
                    HStack {Text("火候");Spacer();PixelSelect(selection:$heat,items:AlchemyHeat.allCases.map{($0,$0.name)}).frame(width:140)}
                    HStack {Text("熬制时间");Spacer();TextField("1—1440",text:$minuteText).textFieldStyle(PixelTextFieldStyle()).frame(width:110);Text("分钟专注").font(.caption)}
                    if let minutes,!materials.isEmpty {
                        let estimate=AlchemyAssessment(materials:materials,heat:heat,minutes:minutes)
                        HStack {Text("预计成功率");Spacer();Text("\(estimate.successChance)%").monospacedDigit()}.font(.callout)
                        Text("适宜用时约 \(estimate.idealMinutes) 分钟").font(.caption).foregroundStyle(Palette.muted)
                        if estimate.heatPenalty>0 {Text("火候不太适合部分材料").font(.caption).foregroundStyle(Palette.clay)}
                        if estimate.timingPenalty>0 {Text(minutes<estimate.idealMinutes ? "用时偏短":"用时偏长").font(.caption).foregroundStyle(Palette.clay)}
                    } else if !materials.isEmpty {Text("时间须为 1—1440 的整数").font(.caption).foregroundStyle(Palette.clay)}
                }
                if let result=store.data.alchemyState.lastResult {
                    Divider().overlay(Palette.line)
                    Text("上次结果 · \(result.outcome.name)").font(.callout)
                    if result.outcome.succeeded {Text("品质 \(result.outcome.quality)").font(.caption).foregroundStyle(Palette.goldLight)}
                }
            }
        } footer: {
            HStack {Spacer();Button(ready ? "领取":"开始熬制") {if ready {collect()}else{start()}}.disabled(brewing ? !ready:!unlocked || materials.isEmpty || minutes == nil)}
        }
    }
    private var recipeWindow:some View {
        SceneDialog(preferred:CGSize(width:560,height:520)) {
            HStack {Text("魔药配方册").font(.title3);Spacer();Button("关闭"){showingRecipes=false}}
        } content: {
            VStack(alignment:.leading,spacing:12) {
                ForEach(store.data.knownAlchemyFormulas) {formula in
                    VStack(alignment:.leading,spacing:8) {
                        Text(formula.name).font(.headline)
                        Text(formula.materials.map(\.name).joined(separator:" + ")).font(.callout)
                        HStack {Text("\(formula.heat.name) · \(formula.minutes) 分钟").font(.caption).foregroundStyle(Palette.muted);Spacer();Button("准备材料"){prepare(formula)}.disabled(brewing || !formula.materials.allSatisfy{store.data.alchemyCount($0)>0})}
                    }.padding(12).magicSurface(Palette.card)
                }
                let unknown=AlchemyFormula.catalog.filter{!store.data.alchemyState.known.contains($0.id)}.count
                if unknown>0 {Text("未知配方 ×\(unknown)").font(.caption).foregroundStyle(Palette.muted)}
                if store.data.knownAlchemyFormulas.isEmpty {Text("尚无已掌握的配方").font(.callout)}
            }
        } footer: {
            HStack {Spacer();Button("前往商店"){showingRecipes=false;SceneNavigation.open("商店",store:store,from:store.currentRoute)}}
        }
    }
    private func prepare(_ formula:AlchemyFormula) {
        guard formula.materials.allSatisfy({store.data.alchemyCount($0)>0}),!brewing else{return}
        selection.clear()
        for material in formula.materials {_=selection.add(material.name,kind:material.kind,available:store.data.alchemyCount(material))}
        heat=formula.heat;minuteText=String(formula.minutes);cabinetTab="材料柜";showingRecipes=false
    }
    private func openPot() {if ready {collect()}else{showingBrew=true}}
    private func start() {
        guard let minutes,store.commitGameChange({$0.startAlchemy(materials:materials,heat:heat,minutes:minutes,at:store.now)}) else{return}
        selection.clear();showingBrew=false;store.message="开始熬制魔药"
    }
    private func collect() {
        if legacy != nil {
            var result:String?
            guard store.commitGameChange({result=$0.collectJourney(.potions,at:store.now);return result != nil}) else{return}
            store.message=result ?? "已领取魔药"
        } else {
            guard store.commitGameChange({$0.collectAlchemy(at:store.now)}) else{return}
            let result=store.data.alchemyState.lastResult?.outcome
            store.message=result?.succeeded == true ? "获得"+(result?.name ?? "魔药"):"熬制失败"
        }
        showingBrew=false;cabinetTab="收获袋"
    }
}

struct AlchemyRecipeShop:View {
    @ObservedObject var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        SceneDialog(preferred:CGSize(width:600,height:520)) {
            HStack {Text("魔药配方").font(.title3);Spacer();WalletView(coins:store.data.garden.coins);Button("关闭"){dismiss()}}
        } content: {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:220))],spacing:12) {
                ForEach(AlchemyFormula.catalog) {formula in
                    let owned=store.data.alchemyState.known.contains(formula.id)
                    VStack(alignment:.leading,spacing:9) {
                        HStack {PixelIcon(name:"配方册",size:28);Text(formula.name).font(.headline)}
                        Text("材料 \(formula.materials.count) 种 · 等级 8").font(.caption).foregroundStyle(Palette.muted)
                        Text(Money.text(formula.purchasePrice)).font(.callout).foregroundStyle(Palette.goldLight)
                        Button(owned ? "已掌握":"购买") {_=store.commitGameChange{$0.buyAlchemyFormula(formula.id)}}
                            .disabled(owned || store.data.levelProgress.level<8 || store.data.garden.coins<formula.purchasePrice)
                            .accessibilityLabel("购买魔药配方："+formula.name)
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(12).magicSurface(Palette.card)
                }
            }
        } footer: {EmptyView()}
    }
}

private struct PotionMaterialArt:View {
    var name:String
    var kind:PotionSelection.Kind
    var size:CGFloat
    var body:some View {
        if kind == .ingredient {IngredientArt(name:name,size:size)}
        else if let item=NatureCatalog.forage.first(where:{$0.name == name || $0.id == name}) {GameNatureSprite(key:item.spriteKey,size:size)}
        else {GameSprite(sheet:"Equipment",index:name.contains("鱼") ? 8:10,size:size)}
    }
}

private struct PotionTableItem:View {
    var portion:PotionSelection.Portion
    var size:CGFloat
    var takeBack:()->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:1/30,paused:reduceMotion)) {timeline in
            let age=timeline.date.timeIntervalSince(portion.droppedAt)
            ObjectButton(label:"取回\(portion.name)",action:takeBack) {
                ZStack {
                    Rectangle().fill(.black.opacity(0.18)).frame(width:size*0.65,height:3).offset(y:size*0.4)
                    PotionMaterialArt(name:portion.name,kind:portion.kind,size:size)
                        .rotationEffect(.degrees(Double(portion.slot == 0 ? -5:5)))
                        .offset(y:reduceMotion ? 0:IngredientDrop.height(age:age))
                }.frame(width:size,height:size)
            }
        }
    }
}

private struct PotionBrewAnimation:View {
    var progress:Double
    var ready:Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:0.15,paused:reduceMotion)) {timeline in
            Canvas {context,size in
                let time=reduceMotion ? 0:timeline.date.timeIntervalSince1970
                let color=ready ? Palette.goldLight:progress<0.35 ? Palette.sage:progress<0.75 ? Palette.gold:Color.purple
                for i in 0..<6 {
                    let phase=(time*0.4+Double(i)/6).truncatingRemainder(dividingBy:1)
                    let x=size.width*(0.5+sin(Double(i)*2+time)*0.18)
                    let y=size.height*(0.30-phase*0.28)
                    let pixel=CGFloat(3+i%3)
                    context.fill(Path(CGRect(x:x,y:y,width:pixel,height:pixel)),with:.color(color.opacity((1-phase)*0.8)))
                }
                if !ready {
                    for i in 0..<5 {
                        let flicker=sin(time*8+Double(i)*2)*3
                        context.fill(Path(CGRect(x:size.width*(0.28+Double(i)*0.09),y:size.height*0.99-flicker,width:size.width*0.06,height:6+flicker)),with:.color(i%2 == 0 ? .orange:Palette.goldLight))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
