import SwiftUI

struct ForgeScene:View {
    @ObservedObject var store:GardenStore
    @State private var showing=false
    @State private var mold=ForgeMold.all[0]
    @State private var materials=["",""]
    @State private var part=0
    @State private var started:Date?
    @State private var rolling=false
    @State private var reveal=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sceneViewport) private var viewport

    private var station:ForgeStation {mold.station}
    private var result:ForgeResult? {store.data.forgeState.lastResult}
    private var sewing:Bool {station == .sewing}
    private var unlocked:Bool {store.data.levelProgress.level>=mold.level}
    private var component:ForgePart {mold.parts[part]}
    private var compact:Bool {viewport.width<650 || viewport.height<500}

    var body:some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {Text("锻造室").font(.system(size:13));Spacer();WalletView(coins:store.data.garden.coins)}
                SceneToolbar(items:[
                    SceneToolbarItem("酒馆"){SceneNavigation.open("酒馆",store:store,from:"锻造室")},
                    SceneToolbarItem("矿洞"){SceneNavigation.open("矿洞",store:store,from:"锻造室")},
                    SceneToolbarItem("商店"){SceneNavigation.open("商店",store:store,from:"锻造室")},
                    SceneToolbarItem("上次结果",disabled:result == nil){openResult()},
                    SceneToolbarItem("小院"){SceneNavigation.open("首页",store:store,from:"锻造室")}
                ])
            }
            SceneCanvas(hasSidebar:true) {size in
                ZStack {
                    RoomBackdrop(name:"Forge").frame(width:size.width,height:size.height)
                    SceneImageHotspot(background:"Forge",rect:CGRect(x:0.72,y:0.08,width:0.23,height:0.44),size:size,label:"熔炉"){openStation(.furnace)}
                    SceneImageHotspot(background:"Forge",rect:CGRect(x:0.07,y:0.34,width:0.33,height:0.28),size:size,label:"缝纫台"){openStation(.sewing)}
                    SceneArrows(store:store,scene:"锻造室")
                }.frame(width:size.width,height:size.height).clipShape(PixelFrame())
                    .overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
            } sidebar: {materialBasket}
        }.sheet(isPresented:$showing,onDismiss:clearPresentation) {
            stationWindow.onExitCommand{showing=false}
        }
    }

    private var materialBasket:some View {
        let owned=ForgeMaterial.all.filter{store.data.forgeMaterialCount($0)>0}
        return VStack(alignment:.leading,spacing:8) {
            Text("材料篮").font(.headline).foregroundStyle(Palette.goldLight)
            if owned.isEmpty {
                Text("还没有制作材料").font(.caption).foregroundStyle(Palette.muted)
                Spacer(minLength:0)
            } else {
                PixelScrollView {
                    VStack(spacing:6) {
                        ForEach(owned) {material in
                            HStack(spacing:6) {
                                GameNatureSprite(key:material.spriteKey,size:24)
                                Text(material.name).font(.caption)
                                Spacer(minLength:2)
                                Text("×\(store.data.forgeMaterialCount(material))").font(.caption)
                                    .monospacedDigit().foregroundStyle(Palette.muted)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }.padding(.trailing,SceneSizing.scrollGutter)
                }
            }
        }.padding(10).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            .magicSurface(Palette.paper)
    }

    private func openStation(_ value:ForgeStation) {
        guard let first=ForgeMold.all.first(where:{$0.station == value}) else{return}
        clearPresentation()
        selectMold(first)
        showing=true
    }

    private func openResult() {
        guard let result,let previous=ForgeMold.all.first(where:{$0.id == result.moldID}) else{return}
        clearPresentation()
        selectMold(previous)
        reveal=true
        showing=true
    }

    private func clearPresentation() {
        started=nil
        rolling=false
        reveal=false
    }

    private func selectMold(_ value:ForgeMold) {
        mold=value
        materials=Array(repeating:"",count:value.parts.count)
        part=0
    }

    @ViewBuilder private var stationWindow:some View {
        if rolling,let result {
            CraftRollPresentation(roll:result.roll,title:sewing ? "落针定形":"锤落成器",subtitle:mold.name) {
                rolling=false
                reveal=true
            }
        } else if reveal,let result {
            resultWindow(result)
        } else if let started {
            SceneDialog(preferred:CGSize(width:490,height:370)) {
                HStack {Text(station.rawValue).font(.title3);Spacer();Button("关闭"){showing=false}}
            } content: {
                ForgeSequence(start:started,station:station,materials:materials).frame(height:190)
            } footer: {
                Text(mold.name).foregroundStyle(Palette.goldLight)
            }.task(id:started) {
                try? await Task.sleep(for:.seconds(3.2))
                guard !Task.isCancelled else{return}
                self.started=nil
                rolling=true
            }
        } else {
            craftingWindow
        }
    }

    private var craftingWindow:some View {
        SceneDialog(preferred:CGSize(width:760,height:560)) {
            HStack {
                Text(station.rawValue).font(.title3).foregroundStyle(Palette.goldLight)
                Spacer()
                Button("关闭"){showing=false}
            }
        } content: {
            if viewport.width>=470 {
                HStack(alignment:.top,spacing:compact ? 12:20) {
                    moldChoices.frame(width:compact ? 154:176)
                    Rectangle().fill(Palette.line).frame(width:1).frame(minHeight:compact ? 190:320)
                    workspace.frame(maxWidth:.infinity,alignment:.topLeading)
                }
            } else {
                VStack(alignment:.leading,spacing:16) {
                    moldChoices
                    workspace
                }
            }
        } footer: {
            let modifier=store.data.forgeModifier(mold:mold,materialIDs:materials)
            HStack(spacing:12) {
                VStack(alignment:.leading,spacing:4) {
                    Text(mold.outputName(materialIDs:materials)).foregroundStyle(Palette.goldLight)
                    Text(unlocked ? "适配 \(modifier>=0 ? "+":"")\(modifier)" : "等级 \(mold.level) 解锁")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength:0)
                Button(sewing ? "开始缝制":"开始锻造",action:begin)
                    .buttonStyle(PixelButtonStyle(primary:true))
                    .disabled(!store.data.canForge(mold:mold,materialIDs:materials))
            }
        }.environment(\.compactSceneControls,compact)
    }

    private var moldChoices:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(sewing ? "纸样":"铸模").font(.headline)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:compact ? 72:78),spacing:6)],spacing:6) {
                ForEach(ForgeMold.all.filter{$0.station == station}) {item in
                    let selected=mold.id == item.id
                    Button {if !selected {selectMold(item)}} label: {
                        VStack(spacing:3) {
                            GameNatureSprite(key:item.spriteKey,size:compact ? 25:31)
                            Text(item.name).font(.system(size:12)).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth:.infinity).frame(height:compact ? 40:48)
                    }.buttonStyle(PixelButtonStyle(primary:selected))
                        .accessibilityLabel("选择\(item.name)\(sewing ? "纸样":"铸模")")
                        .accessibilityAddTraits(selected ? .isSelected:[])
                }
            }
        }
    }

    private var workspace:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("部件").font(.headline)
            HStack(spacing:6) {
                ForEach(mold.parts.indices,id:\.self) {index in
                    let material=ForgeMaterial.all.first{$0.id == materials[index]}
                    let selected=part == index
                    Button {part=index} label: {
                        VStack(spacing:4) {
                            Text(mold.parts[index].name).font(.system(size:12))
                            Text(material?.name ?? "未选").font(.caption)
                                .foregroundStyle(material == nil ? Palette.muted:Palette.goldLight)
                        }.lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth:.infinity).frame(height:30)
                    }.buttonStyle(PixelButtonStyle(primary:selected))
                        .accessibilityLabel(mold.parts[index].name)
                        .accessibilityValue(material?.name ?? "未选")
                        .accessibilityAddTraits(selected ? .isSelected:[])
                }
            }
            HStack {
                Text("\(component.name)材料").font(.headline)
                Spacer()
                Button("取回材料"){materials[part]=""}.disabled(materials[part].isEmpty)
            }.padding(.top,3)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:65,maximum:92),spacing:6)],spacing:6) {
                ForEach(ForgeMaterial.all) {material in materialButton(material)}
            }
        }
    }

    private func materialButton(_ material:ForgeMaterial)->some View {
        let reserved=materials.indices.filter{$0 != part && materials[$0] == material.id}.count
        let remaining=max(0,store.data.forgeMaterialCount(material)-reserved)
        let fit=component.compatibility(material)
        let selected=materials[part] == material.id
        return Button {
            materials[part]=material.id
            if let empty=materials.firstIndex(of:"") {part=empty}
        } label: {
            VStack(spacing:4) {
                GameNatureSprite(key:material.spriteKey,size:27).opacity(remaining>0 ? 1:0.47)
                Text(material.name).font(.system(size:12))
                Text("×\(remaining) · \(fit>=0 ? "+":"")\(fit)").font(.system(size:10)).monospacedDigit().foregroundStyle(Palette.muted)
            }.lineLimit(1).minimumScaleFactor(0.78)
                .frame(maxWidth:.infinity).frame(height:63)
                .background(selected ? Palette.moss:Palette.control,in:PixelFrame())
                .overlay(PixelFrame().strokeBorder(selected ? Palette.gold:Palette.line,lineWidth:1))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!unlocked || remaining == 0)
            .help("\(material.name) · 采集 +\(material.gathering) · 寻踪 +\(material.scouting) · 护行 +\(material.guarding)")
            .accessibilityLabel(material.name)
            .accessibilityValue("可用 \(remaining)，适配 \(fit)")
            .accessibilityAddTraits(selected ? .isSelected:[])
    }

    private func begin() {
        guard started == nil,!rolling,!reveal,
              store.commitGameChange({$0.forgeGear(moldID:mold.id,materialIDs:materials)}) else{return}
        if reduceMotion {rolling=true}
        else {started=Date()}
    }

    private func resultWindow(_ result:ForgeResult)->some View {
        let item=result.gearID.flatMap{store.data.expeditionState.resolveGear($0)}
        return SceneDialog(preferred:CGSize(width:480,height:385)) {
            HStack {Text("制作结果").font(.title3);Spacer();Button("关闭"){showing=false}}
        } content: {
            VStack(spacing:10) {
                if let item {
                    GameNatureSprite(key:item.spriteKey,size:82)
                    Text(item.name).font(.headline).foregroundStyle(Palette.goldLight)
                    if let lore=item.description {Text(lore).font(.caption).foregroundStyle(Palette.ink)}
                    Text("采集 \(item.gathering) · 寻踪 \(item.scouting) · 护行 \(item.guarding)").font(.caption)
                    Text("品质 \(result.roll.quality) · \(Money.text(item.salePrice))").font(.caption).foregroundStyle(Palette.muted)
                } else {
                    Text(sewing ? "断针散线":"坩埚破裂").font(.headline).foregroundStyle(Palette.goldLight)
                    Text("材料损毁，未获得成品").font(.caption)
                }
                Text("d20 · \(result.roll.natural) \(result.roll.modifier>=0 ? "+":"")\(result.roll.modifier) = \(result.roll.total)")
                    .font(.caption).foregroundStyle(Palette.goldLight)
            }.multilineTextAlignment(.center).frame(maxWidth:.infinity)
        } footer: {
            HStack {
                if item != nil {
                    Button("去商店"){
                        showing=false
                        SceneNavigation.open("商店",store:store,from:"锻造室")
                    }
                }
                Spacer()
                Button("继续制作"){
                    selectMold(mold)
                    reveal=false
                }.buttonStyle(PixelButtonStyle(primary:true))
            }
        }
    }
}

struct ForgeSequence:View {
    var start:Date
    var station:ForgeStation
    var materials:[String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:0.05,paused:reduceMotion)) {timeline in
            let age=max(0,timeline.date.timeIntervalSince(start)),phase=min(2,Int(age))
            ZStack {
                Canvas {context,size in
                    let center=CGPoint(x:size.width/2,y:size.height*0.54)
                    if station == .furnace {
                        let metal=Color(red:0.28,green:0.30,blue:0.34)
                        context.fill(Path(CGRect(x:center.x-43,y:center.y,width:86,height:15)),with:.color(metal))
                        context.fill(Path(CGRect(x:center.x-18,y:center.y+15,width:36,height:26)),with:.color(metal))
                        context.fill(Path(CGRect(x:center.x-28,y:center.y-8,width:56,height:8)),with:.color(phase == 0 ? .orange:Palette.goldLight))
                        if phase == 1 {
                            context.fill(Path(CGRect(x:center.x+20,y:center.y-65,width:37,height:25)),with:.color(metal))
                            context.fill(Path(CGRect(x:center.x+23,y:center.y-64,width:31,height:7)),with:.color(.orange))
                            context.fill(Path(CGRect(x:center.x+17,y:center.y-45,width:7,height:40)),with:.color(.orange))
                        }
                        if phase == 2 {
                            var hammer=context
                            hammer.translateBy(x:center.x+24,y:center.y-5)
                            hammer.rotate(by:.degrees(reduceMotion ? -25:sin(age*17)*32-20))
                            hammer.fill(Path(CGRect(x:-4,y:-51,width:8,height:51)),with:.color(Color(red:0.58,green:0.33,blue:0.15)))
                            hammer.fill(Path(CGRect(x:-20,y:-65,width:40,height:18)),with:.color(metal))
                            hammer.fill(Path(CGRect(x:-18,y:-64,width:35,height:4)),with:.color(Palette.goldLight))
                        }
                    } else {
                        context.fill(Path(CGRect(x:center.x-48,y:center.y-8,width:96,height:48)),with:.color(Color(red:0.2,green:0.38,blue:0.32)))
                        for i in 0..<8 {context.fill(Path(CGRect(x:center.x-36+Double(i)*10,y:center.y+8,width:5,height:3)),with:.color(Palette.goldLight))}
                    }
                    for i in 0..<12 {
                        let p=(age*1.3+Double(i)/12).truncatingRemainder(dividingBy:1)
                        let angle=Double(i)*2.4
                        context.fill(Path(CGRect(x:center.x+cos(angle)*p*73,y:center.y-abs(sin(angle))*p*82,width:3,height:3)),with:.color(Palette.goldLight.opacity(1-p)))
                    }
                }
                if phase == 0 {
                    ForEach(Array(materials.enumerated()),id:\.offset) {index,id in
                        if let material=ForgeMaterial.all.first(where:{$0.id == id}) {
                            GameNatureSprite(key:material.spriteKey,size:28).offset(x:Double(index-1)*26,y:reduceMotion ? -25:-65+min(1,age*1.5)*48).opacity(age>0.8 ? 0:1)
                        }
                    }
                }
                if station == .sewing {
                    Rectangle().fill(Palette.goldLight).frame(width:3,height:35).rotationEffect(.degrees(-25)).offset(x:sin(age*10)*25,y:reduceMotion ? -10:-10+sin(age*18)*8)
                }
                Text(station == .sewing ? ["理布","走针","收线"][phase]:["熔炼","浇铸","锤打"][phase]).font(.system(size:12)).foregroundStyle(Palette.goldLight)
                    .padding(6).background(Palette.paper,in:PixelFrame()).offset(y:70)
            }
        }.allowsHitTesting(false).accessibilityLabel(station == .sewing ? "正在缝制":"正在锻造")
    }
}
