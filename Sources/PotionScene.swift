import SwiftUI

struct PotionScene:View {
    @ObservedObject var store:GardenStore
    @State private var selection=PotionSelection()
    @State private var materials=false
    @State private var recipes=false
    @State private var hint=""
    private var trip:Journey? {store.data.garden.economy.journey}
    private var brewing:Bool {trip?.kind == .potions}
    private var unlocked:Bool {store.data.levelProgress.level>=JourneyKind.potions.level}
    private var ready:Bool {brewing && (trip?.progress(store.data.totalFocus) ?? 0)>=1}
    private var label:String {ready ? "领取魔药":brewing ? "查看熬制":"选择配方"}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            SceneCanvas(reservedHeight:180,hasSidebar:true) {size in
                let w=size.width,h=size.height
                ZStack {
                    RoomBackdrop(name:"Laboratory").frame(width:w,height:h)
                    ObjectButton(label:label,action:openPot,caption:label) {GameSprite(index:7,size:w*0.19)}
                        .disabled(!unlocked).position(x:w*0.735,y:h*0.59)
                    if brewing,let trip {
                        PotionBrewAnimation(progress:trip.progress(store.data.totalFocus),ready:ready)
                            .frame(width:w*0.25,height:h*0.38).position(x:w*0.735,y:h*0.54)
                        if ready {
                            ObjectButton(label:"领取魔药",action:openPot,caption:"领取") {GameSprite(sheet:"Equipment",index:11,size:w*0.10)}
                                .position(x:w*0.55,y:h*0.68)
                        }
                    } else {
                        ForEach(selection.portions) {portion in
                            PotionTableItem(portion:portion,size:w*0.12) {selection.remove(portion.id);hint=""}
                                .position(x:w*(0.35+CGFloat(portion.slot)*0.18),y:h*0.66)
                        }
                    }
                    if !unlocked {
                        Palette.paper.opacity(0.55).allowsHitTesting(false)
                        Text("等级 8 解锁").font(.headline).padding(14).magicSurface(Palette.paper)
                    }
                    SceneArrows(store:store,scene:JourneyKind.potions.rawValue)
                }.frame(width:w,height:h).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            } sidebar: {cabinet}
            if let trip,brewing {
                PixelProgress(value:trip.progress(store.data.totalFocus))
                HStack {
                    Text(ready ? "魔药已熬好" : "还需 \(Int(ceil(max(0,trip.duration-(store.data.totalFocus-trip.startedAt))/60))) 分钟专注").font(.caption).foregroundStyle(Palette.goldLight)
                    Spacer()
                    if !ready {Button("记录专注"){SceneNavigation.open("计时器",store:store)}}
                }
            } else {
                Text(selection.portions.isEmpty ? "桌上还没有材料":"材料 \(selection.portions.count)/2").font(.caption).foregroundStyle(Palette.muted)
            }
            if !hint.isEmpty {Text(hint).font(.caption).foregroundStyle(Palette.goldLight)}
        }.sheet(isPresented:$recipes){recipeWindow}
    }
    private var cabinet:some View {
        VStack(alignment:.leading,spacing:9) {
            Text("材料柜").font(.headline)
            PixelTabs(selection:$materials,items:[(false,"食材"),(true,"探险材料")])
            PixelScrollView {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:64))],spacing:9) {
                    if materials {
                        ForEach(store.data.garden.economy.finds.keys.filter{store.data.garden.economy.finds[$0,default:0]>0 && !Potion.all.map(\.id).contains($0)}.sorted(),id:\.self) {name in
                            materialButton(name,kind:.material,available:store.data.garden.economy.finds[name,default:0])
                        }
                    } else {
                        ForEach(Ingredient.allCases.filter{store.data.ingredientCount($0)>0}) {ingredient in
                            materialButton(ingredient.rawValue,kind:.ingredient,available:store.data.ingredientCount(ingredient))
                        }
                    }
                }
            }
            Button("取回全部"){selection.clear();hint=""}.font(.caption).disabled(selection.portions.isEmpty || brewing)
        }.padding(10).magicSurface(Palette.paper)
    }
    private func materialButton(_ name:String,kind:PotionSelection.Kind,available:Int)->some View {
        let remaining=available-selection.count(name,kind:kind)
        return Button {
            if selection.add(name,kind:kind,available:available){hint=""}
        } label: {
            VStack(spacing:4) {
                PotionMaterialArt(name:name,kind:kind,size:42)
                Text(name).font(.system(size:10)).lineLimit(1)
                Text("×\(max(0,remaining))").font(.caption).foregroundStyle(Palette.goldLight)
            }.frame(maxWidth:.infinity).padding(.vertical,4)
        }.buttonStyle(.plain).accessibilityLabel("取用材料：\(name)").disabled(!unlocked || trip != nil || remaining<=0 || selection.portions.count>=2)
    }
    private func openPot() {
        if ready {
            if let result=store.data.collectJourney(){store.message=result;hint=""}
        } else {recipes=true}
    }
    private var recipeWindow:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text(brewing ? "正在熬制":"选择配方").font(.title3);Spacer();Button("关闭"){recipes=false}}
            if brewing,let trip {
                let potion=Potion.all.first{$0.id == trip.recipe}
                Text(potion?.name ?? "魔药").font(.headline)
                Text(potion?.benefit ?? "").font(.caption).foregroundStyle(Palette.muted)
                PixelProgress(value:trip.progress(store.data.totalFocus))
                Text("熬制需要累计 15 分钟专注").font(.caption)
            } else {
                Text("桌上："+(selection.portions.isEmpty ? "尚未选材":selection.portions.map(\.name).joined(separator:" + "))).font(.caption).foregroundStyle(Palette.goldLight)
                PixelScrollView {
                    ForEach(Potion.all) {potion in
                        let matches=selection.matches(potion)
                        HStack(spacing:12) {
                            GameSprite(sheet:"Equipment",index:11,size:40)
                            VStack(alignment:.leading,spacing:5) {
                                Text(potion.name).font(.headline)
                                Text("\(potion.ingredient) ×1 + \(potion.material) ×1").font(.caption)
                                Text(potion.benefit).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("熬制"){brew(potion)}.disabled(!matches || trip != nil)
                        }.padding(12).magicSurface(matches ? Palette.card:Palette.paper)
                    }
                }
                Text(trip == nil ? "熬制用时：15 分钟专注":"进行中：\(trip!.kind.rawValue)").font(.caption).foregroundStyle(Palette.muted)
            }
        }.padding(20).frame(width:550,height:365).magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
    private func brew(_ potion:Potion) {
        guard selection.matches(potion) else{return}
        guard store.data.embark(.potions,recipe:potion.id) else{hint="材料不足。";recipes=false;return}
        selection.clear();recipes=false;hint="";store.message="\(potion.name)开始熬制。"
    }
}

private struct PotionMaterialArt:View {
    var name:String
    var kind:PotionSelection.Kind
    var size:CGFloat
    var body:some View {
        if kind == .ingredient {IngredientArt(name:name,size:size)}
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
