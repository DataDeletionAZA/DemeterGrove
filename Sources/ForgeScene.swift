import SwiftUI

struct ForgeScene:View {
    @ObservedObject var store:GardenStore
    @State private var station:ForgeStation = .furnace
    @State private var moldID="sword"
    @State private var materials:[String]=["","",""]
    @State private var part=0
    @State private var started:Date?
    @State private var rolling=false
    @State private var reveal=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sceneViewport) private var viewport
    private var compact:Bool {viewport.width<700 || viewport.height<520}
    private var mold:ForgeMold {ForgeMold.all.first{$0.id == moldID} ?? ForgeMold.all[0]}
    private var result:ForgeResult? {store.data.forgeState.lastResult}
    private var working:Bool {started != nil || rolling}
    var body:some View {
        VStack(alignment:.leading,spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {Text("锻造室").font(.system(size:13));Spacer();WalletView(coins:store.data.garden.coins)}
                SceneToolbar(items:[SceneToolbarItem("酒馆"){SceneNavigation.open("酒馆",store:store)},SceneToolbarItem("矿洞"){SceneNavigation.open("矿洞",store:store)},SceneToolbarItem("商店"){SceneNavigation.open("商店",store:store)},SceneToolbarItem("上次结果",disabled:result == nil || working){reveal=true},SceneToolbarItem("小院"){SceneNavigation.open("首页",store:store)}])
            }
            SceneCanvas(hasSidebar:true) {size in
                ZStack {
                    RoomBackdrop(name:"Forge").frame(width:size.width,height:size.height)
                    SceneImageHotspot(background:"Forge",rect:CGRect(x:0.72,y:0.08,width:0.23,height:0.44),size:size,label:"熔炉"){selectStation(.furnace)}
                    SceneImageHotspot(background:"Forge",rect:CGRect(x:0.07,y:0.34,width:0.33,height:0.28),size:size,label:"缝纫台"){selectStation(.sewing)}
                    moldRack(size)
                    if let started {
                        ForgeSequence(start:started,station:station,materials:materials).frame(width:size.width*0.42,height:size.height*0.42).position(x:size.width*0.52,y:size.height*0.65)
                    } else {partTray(size)}
                    if reveal,let result {resultCard(result,height:size.height).frame(width:min(330,size.width*0.82)).position(x:size.width*0.52,y:size.height*0.5)}
                    if rolling,let result {
                        CraftRollPresentation(roll:result.roll,title:station == .sewing ? "落针定形":"锤落成器",subtitle:mold.name) {rolling=false;reveal=true}
                            .environment(\.sceneViewport,size).position(x:size.width/2,y:size.height/2)
                    }
                }.frame(width:size.width,height:size.height).clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
                    .onChange(of:store.now) {_,now in
                        if let started,now.timeIntervalSince(started)>=3.2 {
                            self.started=nil;rolling=true;materials=Array(repeating:"",count:mold.parts.count);part=0
                        }
                    }
            } sidebar:{basket}
        }.onAppear {if result != nil {reveal=true}}
    }
    private func selectStation(_ value:ForgeStation) {
        guard !working else{return}
        station=value
        if mold.station != value,let first=ForgeMold.all.first(where:{$0.station == value}) {selectMold(first)}
        reveal=false
    }
    private func selectMold(_ value:ForgeMold) {
        guard !working else{return}
        moldID=value.id;station=value.station;materials=Array(repeating:"",count:value.parts.count);part=0;reveal=false
    }
    private func moldRack(_ size:CGSize)->some View {
        HStack(spacing:5) {
            ForEach(ForgeMold.all.filter{$0.station == station}) {item in
                ObjectButton(label:"选择\(item.name)\(station == .sewing ? "纸样":"铸模")",action:{selectMold(item)},caption:item.name) {
                    GameNatureSprite(key:item.spriteKey,size:size.width*0.07)
                        .background(mold.id == item.id ? Palette.gold.opacity(0.22):.clear,in:PixelFrame())
                }
            }
        }.position(x:size.width*0.40,y:size.height*0.22).disabled(working)
    }
    private func partTray(_ size:CGSize)->some View {
        HStack(spacing:8) {
            ForEach(Array(mold.parts.enumerated()),id:\.element.id) {index,component in
                ObjectButton(label:"选择\(component.name)",action:{part=index;reveal=false},caption:component.name) {
                    ZStack {
                        PixelFrame().fill(Palette.paper.opacity(0.86))
                        if materials.indices.contains(index),let material=ForgeMaterial.all.first(where:{$0.id == materials[index]}) {GameNatureSprite(key:material.spriteKey,size:size.width*0.065)}
                        else {Text("+").font(.system(size:23)).foregroundStyle(Palette.goldLight)}
                    }.frame(width:size.width*0.095,height:size.width*0.09)
                        .overlay(PixelFrame().stroke(part == index ? Palette.goldLight:Palette.line,lineWidth:part == index ? 2:1))
                }
            }
        }.position(x:size.width*0.5,y:size.height*0.72).disabled(working)
    }
    private var basket:some View {
        VStack(alignment:.leading,spacing:compact ? 4:9) {
            PixelTabs(selection:$station,items:ForgeStation.allCases.map{($0,$0.rawValue)})
                .disabled(working).onChange(of:station){_,value in selectStation(value)}
            HStack(spacing:6) {GameNatureSprite(key:mold.spriteKey,size:compact ? 25:35);Text(mold.name).font(.headline).foregroundStyle(Palette.goldLight)}
                .help("等级 \(mold.level)")
            if !compact {Text(mold.description).font(.system(size:11)).foregroundStyle(Palette.ink).fixedSize(horizontal:false,vertical:true)}
            Text("\(mold.parts[min(part,mold.parts.count-1)].name) · 材料篮").font(.system(size:12)).foregroundStyle(Palette.goldLight)
            PixelScrollView {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:7) {
                    ForEach(ForgeMaterial.all) {material in materialButton(material)}
                }.padding(.trailing,SceneSizing.scrollGutter)
            }
            let modifier=store.data.forgeModifier(mold:mold,materialIDs:materials)
            Text("适配 \(modifier>=0 ? "+":"")\(modifier)").font(.system(size:11)).foregroundStyle(Palette.goldLight)
            Button(station == .sewing ? "开始缝制":"开始锻造") {
                guard store.commitGameChange({$0.forgeGear(moldID:moldID,materialIDs:materials)}) else{return}
                reveal=false;started=Date()
            }.frame(maxWidth:.infinity).buttonStyle(PixelButtonStyle(primary:true))
                .disabled(working || !store.data.canForge(mold:mold,materialIDs:materials))
        }.padding(compact ? 7:10).magicSurface(Palette.paper)
    }
    private func materialButton(_ material:ForgeMaterial)->some View {
        let available=store.data.forgeMaterialCount(material.id)
        let selected=working ? 0:materials.filter{$0 == material.id}.count
        let compatibility=mold.parts[min(part,mold.parts.count-1)].compatibility(material)
        return ObjectButton(label:"\(material.name)，库存\(available)，适配\(compatibility)",action:{
            guard materials.indices.contains(part) else{return}
            materials[part]=material.id;reveal=false
            if let empty=materials.firstIndex(of:"") {part=empty}
        }) {
            VStack(spacing:3) {
                GameNatureSprite(key:material.spriteKey,size:32)
                Text(material.name).font(.system(size:11))
                Text("\(max(0,available-selected)) · \(compatibility>=0 ? "+":"")\(compatibility)").font(.system(size:compact ? 9:10)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.75)
            }.frame(maxWidth:.infinity).padding(5).magicSurface(Palette.card)
        }.disabled(working || (available<=selected && materials[part] != material.id))
            .help("\(material.name) · 采集 +\(material.gathering) · 寻踪 +\(material.scouting) · 护行 +\(material.guarding) · \(mold.parts[min(part,mold.parts.count-1)].name)适配 \(compatibility>=0 ? "+":"")\(compatibility)")
            .accessibilityLabel("\(material.name)，库存\(available)，适配\(compatibility)")
    }
    private func resultCard(_ result:ForgeResult,height:CGFloat)->some View {
        VStack(spacing:9) {
            PixelScrollView {
                VStack(spacing:9) {
                    if let id=result.gearID,let item=store.data.expeditionState.resolveGear(id) {
                        GameNatureSprite(key:item.spriteKey,size:compact ? 42:72)
                        Text(item.name).font(.system(size:14,weight:.medium)).foregroundStyle(Palette.goldLight).multilineTextAlignment(.center)
                        if let lore=item.description {Text(lore).font(.system(size:11)).foregroundStyle(Palette.ink).fixedSize(horizontal:false,vertical:true)}
                        Text("采集 \(item.gathering) · 寻踪 \(item.scouting) · 护行 \(item.guarding)").font(.system(size:11))
                        Text("品质 \(result.roll.quality) · \(Money.text(item.salePrice))").font(.system(size:11)).foregroundStyle(Palette.muted)
                        Button("去商店"){SceneNavigation.open("商店",store:store)}
                    } else {
                        Text(ForgeMold.all.first{$0.id == result.moldID}?.station == .sewing ? "断针散线":"坩埚破裂").font(.headline).foregroundStyle(Palette.goldLight)
                        Text("材料损毁，未获得成品").font(.system(size:12))
                    }
                }.frame(maxWidth:.infinity).padding(.trailing,4)
            }
            Text("d20 · \(result.roll.natural) \(result.roll.modifier>=0 ? "+":"")\(result.roll.modifier) = \(result.roll.total)").font(.system(size:11)).foregroundStyle(Palette.goldLight)
            Button("继续制作"){reveal=false;materials=Array(repeating:"",count:mold.parts.count);part=0}
        }.padding(compact ? 9:15).frame(maxWidth:.infinity).frame(height:min(360,max(180,height-16))).magicSurface(Palette.paper,strong:true)
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
