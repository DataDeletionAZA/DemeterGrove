import SwiftUI

struct GameRoomView: View {
    @ObservedObject var store: GardenStore
    var room: String
    @State private var plantingPlot: Plot?
    @State private var hint = ""
    @State private var harvested: UUID?
    @State private var harvestedCrop: Crop?
    @State private var harvestedCount = 2
    @State private var field = 0
    @State private var burst: Date?
    @State private var intent: CookingIntent = .dish
    @State private var method:CookingMethod = .boil
    @State private var ingredientCategory:IngredientCategory = .farm
    @State private var loadedDish:Dish?
    @State private var selection = KitchenSelection()
    @State private var seedCabinet = false
    @State private var selectedSeed: Crop?
    @State private var methodWindow = false
    @State private var cookingStarted = Date.distantPast
    @State private var cookingIngredients: [String] = []
    private var additions: [String:Int] { selection.counts }
    private var category: FoodCategory { intent.category(method:method,ingredients:additions) }
    @State private var lastDish: Dish?
    @State private var dishName = ""
    @State private var cookingUntil = Date.distantPast
    @State private var book = false
    @State private var market = false
    @State private var soldAt: Date?
    @State private var shopChoice: String?
    private var recipe: Dish? {
        if var saved = loadedDish, saved.ingredients == additions, saved.method == method, saved.category == category {
            saved.quality=min(95,saved.quality-saved.kitchenBonus+2);saved.kitchenBonus=0;return saved
        }
        guard let draft=intent.develop(method:method,ingredients:additions) else{return nil}
        var result=intent.develop(method:method,ingredients:additions,practice:min(25,store.data.garden.crafts[draft.id,default:0]))!
        if let saved=store.data.garden.recipes[result.id] {result.name=saved.name}
        return result
    }
    private var availableDishes: [Dish] { store.data.garden.menu.filter { store.data.garden.dishes[$0.id, default: 0] > 0 } }
    private var choice: Dish? { availableDishes.first { $0.id == shopChoice } ?? availableDishes.first }
    private var cooking: Bool { store.now < cookingUntil }
    private var readyToCook:Bool {recipe.map{store.data.canCook($0)} ?? false}
    private var roomStatus:String {
        if !hint.isEmpty {return hint}
        switch room {
        case "农场":
            if let selectedSeed { return "已选\(selectedSeed.rawValue)种子 · 点击亮起的空地播种" }
            let empty=store.data.garden.plots.filter{$0.crop == nil}.count
            let mature=store.data.garden.plots.filter{$0.crop != nil && $0.progress(store.data.totalFocus)>=1}.count
            return "空地 \(empty) · 已成熟 \(mature)"
        case "厨房":return cooking ? "正在料理…" : additions.isEmpty ? "料理台还没有食材" : "已放入 \(selection.portions.count)/6 份食材"
        default:return "在售 \(store.data.garden.orders.count) · 待收款 \(store.data.garden.orders.filter{$0.ready(store.data.totalFocus)}.count)"
        }
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                resource(8, "种子", store.data.garden.seeds)
                resource(9, "露水", store.data.garden.water)
                WalletView(coins:store.data.garden.coins)
                Spacer()
                if room == "厨房" { Button("配方册") { book = true } }
                if room == "商店" {Button("采买"){market=true}}
                else if room == "厨房" {Button("去商店"){store.pet?.openTool("商店")}}
            }
            HStack {
                Text("等级 \(store.data.levelProgress.level)").font(.caption).foregroundStyle(Palette.goldLight)
                if room == "农场", store.data.garden.plots.count>6 {
                    PixelTabs(selection:$field,items:(0..<(store.data.garden.plots.count/6)).map{($0,"田地 \($0+1)")})
                }
                Spacer()
                Button("成长与升级") { store.pet?.openTool("成长") }
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    RoomBackdrop(name: room == "农场" ? "Garden" : room == "厨房" ? "Kitchen" : "Shop").frame(width:w,height:h).clipped()
                    if room == "农场" { gardenScene(w: w, h: h) }
                    else if room == "厨房" { kitchenScene(w: w, h: h) }
                    else { shopScene(w: w, h: h) }
                    SceneParticles()
                }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.65),lineWidth:1))
            }.aspectRatio(1.5, contentMode: .fit)
                .overlay(alignment:.trailing) {
                    if room == "厨房" {pantry.frame(width:160).offset(x:172)}
                }.padding(.trailing,room == "厨房" ? 172:0)
            Text(roomStatus).font(.system(size: 12)).foregroundStyle(Palette.goldLight).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal:false,vertical:true)
            if room == "农场" { seedTray }
            else if room != "厨房" { stockTray }
            if room == "厨房", let dish = lastDish, !cooking { resultCard(dish) }
        }
        .sheet(item:$plantingPlot) { plot in seedSelection(plot) }
        .sheet(isPresented:$seedCabinet) { seedSelection(nil) }
        .sheet(isPresented:$methodWindow) { methodSelection }
        .sheet(isPresented: $book) { recipeBook }
        .sheet(isPresented: $market) { IngredientMarket(store: store) }
    }
    private func resource(_ index: Int, _ name: String, _ count: Int) -> some View {
        HStack(spacing: 3) { GameSprite(index:index,size:28); Text("\(count)").monospacedDigit().font(.system(size:13,weight:.medium)) }.help("\(name) \(count)").accessibilityLabel("\(name) \(count)")
    }
    @ViewBuilder private func gardenScene(w: CGFloat, h: CGFloat) -> some View {
        ForEach(Array(store.data.garden.plots.enumerated()).filter{$0.offset/6 == field}, id: \.element.id) { index, plot in
            let soil = SceneObject.gardenPlots[index % SceneObject.gardenPlots.count]
            let center = soil.target
            let x = w * center.x, y = h * center.y
            let progress = plot.progress(store.data.totalFocus)
            let stage = plot.growthStage(store.data.totalFocus)
            ObjectButton(label: plot.crop.map { "\($0.rawValue)，\(["刚播种","出苗","成长中","成熟，点击收获"][stage])" } ?? "第 \(index+1) 块空地，选择种子", action: { workPlot(plot) }, embeddedInBackdrop: plot.crop == nil) {
                ZStack {
                    Color.clear
                    if let crop = plot.crop {
                        PlantArt(crop:crop,stage:stage,size:w*0.12).offset(y:-w*0.06+h*0.025)
                        if progress >= 1 { Text("可收获").font(.system(size:10,weight:.medium)).padding(.horizontal,5).padding(.vertical,2).background(Palette.paper.opacity(0.85)).foregroundStyle(Palette.goldLight).offset(y:h*0.060) }
                        else { PixelProgress(value:progress).frame(width:w*0.075).offset(y:h*0.052) }
                    } else {
                        SceneObjectArtwork(object: soil, sceneSize: CGSize(width: w, height: h)).brightness(selectedSeed == nil ? 0:0.18)
                            .overlay { if selectedSeed != nil { PixelFrame().stroke(Palette.goldLight,lineWidth:2).padding(3) } }
                    }
                }.frame(width:w*0.21,height:h*0.20)
            }.position(x:x,y:y)
            if harvested == plot.id, let burst {
                SceneParticles(burst:burst).frame(width:w*0.2,height:h*0.3).position(x:x,y:y)
                if let harvestedCrop { HarvestEffect(crop:harvestedCrop,date:burst,size:w*0.065,count:harvestedCount).position(x:x,y:y-h*0.05) }
            }
        }
        ObjectButton(label:"打开种子柜",action:{seedCabinet=true},caption:"种子柜") {
            SeedCrateArt().frame(width:w*0.12,height:h*0.14)
        }.position(x:w*0.51,y:h*0.85)
    }
    private func workPlot(_ plot: Plot) {
        if let crop = plot.crop {
            let amount=store.data.harvestYield * (crop == .starlightCarrot ? 2:1)
            if store.data.harvest(plot.id) { harvested = plot.id; harvestedCrop = crop;harvestedCount=amount; burst = Date(); hint = "收获 \(crop.harvestName) ×\(amount)"; store.animatePet(20, seconds: 0.65) }
            else { hint = "\(crop.rawValue)还需记录 \(Int(ceil((1-plot.progress(store.data.totalFocus))*(plot.duration ?? crop.seconds)/60))) 分钟专注。" }
        } else if let selectedSeed { plant(selectedSeed,in:plot) }
        else { plantingPlot=plot }
    }
    private var ownedSeeds:[Crop] { Crop.allCases.filter{store.data.garden.cropSeeds[$0.rawValue,default:0]>0} }
    private var seedTray: some View {
        HStack {
            Button("种子柜 · \(ownedSeeds.count) 种 · \(store.data.garden.seeds) 袋") {seedCabinet=true}.buttonStyle(.plain).font(.caption)
            Spacer()
            if selectedSeed != nil {Button("取消播种"){selectedSeed=nil;hint=""}}
        }
    }
    private func plant(_ crop:Crop,in plot:Plot) {
        guard store.data.plant(crop,in:plot.id) else {
            hint=store.data.garden.water < 1 ? "露水不足，记录专注后再来播种。":"这袋种子已用完。"
            return
        }
        plantingPlot=nil;selectedSeed=nil;harvested=plot.id;harvestedCrop=nil;burst=Date();hint="种下了\(crop.rawValue)。"
    }
    private func seedSelection(_ plot:Plot?) -> some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text(plot == nil ? "种子柜":"选择种子").font(.title3);Spacer();Button("关闭"){plantingPlot=nil;seedCabinet=false}}
            Text("露水 \(store.data.garden.water) · 播种消耗 1 袋种子、1 滴露水").font(.caption).foregroundStyle(Palette.muted)
            if ownedSeeds.isEmpty {Text("种子柜空空的").padding(.vertical,20)}
            ScrollView {
                LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:3),spacing:10) {
                    ForEach(ownedSeeds) {crop in
                        Button {
                            if let plot {plant(crop,in:plot)}
                            else {selectedSeed=crop;seedCabinet=false;hint=""}
                        } label: {
                            VStack(spacing:5) {
                                IngredientArt(name:crop.rawValue,size:42)
                                Text(crop.rawValue).font(.system(size:12))
                                Text("种子 ×\(store.data.garden.cropSeeds[crop.rawValue,default:0])").font(.caption)
                                Text("\(Int(crop.seconds*(1-Double(store.data.garden.rank(.watering))*0.10)/60)) 分钟专注").font(.system(size:10)).foregroundStyle(Palette.muted)
                            }.frame(maxWidth:.infinity).padding(8).magicSurface(Palette.card)
                        }.buttonStyle(.plain).disabled(plot != nil && store.data.garden.water<1)
                    }
                }
            }
        }.padding(20).frame(width:460,height:370).magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
    private var methodSelection:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("想做些什么？").font(.title3);Spacer();Button("关闭"){methodWindow=false}}
            Text(additions.sorted{$0.key<$1.key}.map{"\($0.key) ×\($0.value)"}.joined(separator:" · ")).font(.caption).foregroundStyle(Palette.muted)
            PixelTabs(selection:Binding(get:{intent},set:{intent=$0;loadedDish=nil;chooseDefaultMethod()}),items:CookingIntent.allCases.map{($0,$0.rawValue)})
            let methods=intent.methods(ingredients:additions)
            if methods.isEmpty { Text(intent == .process ? "这些食材还不能加工成原料，试试单独的茶叶，或米、麦搭配蛋奶。":"这些食材暂时不适合这类料理，可以换个方向。表里的食材会保留。").font(.system(size:13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true) }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(methods) {item in
                    Button {method=item;loadedDish=nil} label: {
                        VStack(spacing:8) {CookingToolArt(method:item).frame(width:64,height:50);Text(item.rawValue).font(.system(size:13))}.frame(maxWidth:.infinity).padding(10).magicSurface(method == item ? Palette.card:Palette.paper)
                            .overlay(PixelFrame().stroke(method == item ? Palette.goldLight:Palette.line,lineWidth:1))
                    }.buttonStyle(.plain)
                }
            }
            Spacer(minLength:0)
            HStack {
                Text(intent == .process ? "成品将放入食材柜":"完成后记入配方册").font(.caption).foregroundStyle(Palette.muted)
                Spacer()
                Button("开始制作"){makeFood()}.buttonStyle(PixelButtonStyle(primary:true)).disabled(!methods.contains(method) || !readyToCook)
            }
        }.padding(22).frame(width:530,height:365).magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
    private func chooseDefaultMethod() {
        let methods=intent.methods(ingredients:additions)
        if !methods.contains(method), let first=methods.first {method=first}
    }
    private func openCooking() {
        guard !cooking else{return}
        guard !additions.isEmpty else{hint="先从食材柜取出几份食材。";return}
        if intent.methods(ingredients:additions).isEmpty,
           let suitable=CookingIntent.allCases.first(where:{!$0.methods(ingredients:additions).isEmpty}) {intent=suitable}
        chooseDefaultMethod();methodWindow=true
    }
    @ViewBuilder private func kitchenScene(w: CGFloat, h: CGFloat) -> some View {
        SceneTarget(object: .recipeBook, sceneSize: CGSize(width: w, height: h), label: "打开配方册", action: { book = true })
        let counter=SceneObject.cookingCounter
        ObjectButton(label:"料理台，选择做法",action:openCooking,embeddedInBackdrop:true,caption:cooking ? "制作中…":"制作") {
            SceneObjectArtwork(object:counter,sceneSize:CGSize(width:w,height:h))
        }.frame(width:w*counter.target.width,height:h*counter.target.height).position(x:w*counter.target.x,y:h*counter.target.y)
        if cooking {
            CookingSequence(start:cookingStarted,method:method,ingredients:cookingIngredients).frame(width:w*0.32,height:h*0.34).position(x:w*0.59,y:h*0.58)
        } else {
            ForEach(selection.portions) {portion in
                TableIngredient(portion:portion,size:w*0.095) {selection.remove(portion.id);loadedDish=nil;lastDish=nil;hint=""}
                    .position(x:w*(0.37+CGFloat(portion.slot%3)*0.15),y:h*(portion.slot<3 ? 0.60:0.72))
            }
            if let displayed=lastDish {
                ObjectButton(label:displayed.name,action:{hint=displayed.name},caption:displayed.name) {
                    Group {
                        if let ingredient=displayed.outputIngredient {IngredientArt(name:ingredient.rawValue,size:w*0.17)}
                        else {GameSprite(sheet:"Foods",index:displayed.sprite,size:w*0.17)}
                    }
                }.position(x:w*0.54,y:h*0.64)
            }
        }
    }
    private var pantry:some View {
        VStack(alignment:.leading,spacing:9) {
            Text("食材柜").font(.system(size:13,weight:.medium)).foregroundStyle(Palette.goldLight)
            IngredientCategoryDropdown(selection:$ingredientCategory)
            ScrollView {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                    ForEach(Ingredient.allCases.filter{$0.category == ingredientCategory}) {ingredient in
                        let remaining=store.data.ingredientCount(ingredient)-additions[ingredient.rawValue,default:0]
                        Button {addIngredient(ingredient)} label: {
                            VStack(spacing:3) {
                                IngredientArt(name:ingredient.rawValue,size:42)
                                Text(ingredient.rawValue).font(.system(size:10)).lineLimit(1)
                                Text("×\(max(0,remaining))").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                            }.frame(maxWidth:.infinity).padding(.vertical,4)
                        }.buttonStyle(.plain).accessibilityLabel("取用食材：\(ingredient.rawValue)").disabled(remaining<=0 || selection.portions.count>=6 || cooking).opacity(remaining>0 ? 1:0.4)
                    }
                }
            }.frame(maxHeight:.infinity)
            HStack {Text("\(selection.portions.count)/6").font(.caption);Spacer();Button("取回全部"){selection.clear();loadedDish=nil;lastDish=nil;hint=""}.font(.caption).disabled(selection.portions.isEmpty || cooking)}
        }.padding(10).magicSurface(Palette.paper)
    }
    private func addIngredient(_ ingredient:Ingredient) {
        guard !cooking,selection.add(ingredient,available:store.data.ingredientCount(ingredient)) else{return}
        loadedDish=nil;lastDish=nil;hint=""
    }
    private func makeFood() {
        guard !cooking else { return }
        guard let dish=recipe else { hint="请为这些食材选择适合的做法。";return }
        guard store.data.cook(dish) else { hint="食材不足";return }
        cookingIngredients=selection.portions.map{$0.ingredient.rawValue};selection.clear();methodWindow=false
        lastDish=store.data.garden.recipes[dish.id] ?? dish;dishName=dish.name;cookingStarted=Date();cookingUntil=cookingStarted.addingTimeInterval(3)
        hint=""
        store.animatePet(20, seconds: 0.65)
    }
    private func resultCard(_ dish: Dish) -> some View {
        HStack(spacing:12) {
            if let ingredient=dish.outputIngredient {IngredientArt(name:ingredient.rawValue,size:48)}
            else {GameSprite(sheet:"Foods",index:dish.sprite,size:48)}
            VStack(alignment:.leading,spacing:5) {
                Text(String(repeating:"★",count:dish.stars) + "  品质 \(dish.quality)").foregroundStyle(Palette.goldLight).font(.caption)
                HStack {
                    TextField("料理名称",text:$dishName).onSubmit { rename(dish) }
                    Button("命名") { rename(dish) }.disabled(dishName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
            }
            if dish.outputIngredient == nil { Button("去上架") {store.pet?.openTool("商店")} }
            else {Text("已放入食材柜").font(.caption).foregroundStyle(Palette.goldLight)}
        }.padding(10).magicSurface(Palette.paper)
    }
    private func rename(_ dish: Dish) {
        let name=String(dishName.trimmingCharacters(in:.whitespacesAndNewlines).prefix(60))
        guard !name.isEmpty else{return}
        var updated=dish;updated.name=name;store.data.garden.recipes[dish.id]=updated;lastDish=updated;hint="配方已命名为\(name)。"
    }
    @ViewBuilder private func shopScene(w: CGFloat,h: CGFloat) -> some View {
        let orders=store.data.garden.orders
        ForEach(0..<store.data.garden.capacity,id:\.self) { slot in
            let order=orders.indices.contains(slot) ? orders[slot] : nil
            let x=store.data.garden.capacity == 1 ? 0.25 : 0.14+Double(slot)*0.34/Double(store.data.garden.capacity-1)
            ObjectButton(label:order.map{"查看在售料理：\($0.dish.name)"} ?? "第 \(slot+1) 个陈列位，上架料理",action:{
                if let order { hint="\(order.dish.name) · 售价 \(Money.text(order.price))" }
                else if let dish=choice, store.data.stock(dish) { soldAt=nil;hint="\(dish.name)已摆上柜台。" }
                else { hint="暂无可上架料理" }
            }) {
                ZStack {
                    Color.white.opacity(0.001)
                    if let order { GameSprite(sheet:"Shelf",index:order.dish.sprite,size:w*0.043) }
                    else { Text("+").font(.system(size:12)).foregroundStyle(Palette.goldLight.opacity(0.7)) }
                }.frame(width:w*0.065,height:h*0.09)
            }.position(x:w*x,y:h*0.519)
        }
        DisplayGlass()
        if let order=orders.first {
            let progress=min(1,max(0,(store.data.totalFocus-order.placedAt)/300))
            GameSprite(index:store.data.garden.sales%2 == 0 ? 12:13,size:w*0.15)
                .position(x:w*(progress>=1 ? 0.57:0.83-progress*0.18),y:h*(progress>=1 ? 0.73:0.46+progress*0.20))
        }
        let ready=orders.filter{$0.ready(store.data.totalFocus)}
        VStack(spacing:4) {
            Text("陈列 \(orders.count)/\(store.data.garden.capacity)").font(.system(size:12,weight:.medium))
            Text(ready.isEmpty ? "每份售卖需 5 分钟专注" : "\(ready.count) 份已售出").font(.system(size:10))
        }.foregroundStyle(Palette.goldLight).padding(6).background(Palette.paper.opacity(0.9)).position(x:w*0.62,y:h*0.18)
        if !ready.isEmpty {
            let amount=ready.reduce(0){$0+$1.price}
            ObjectButton(label:"收取 \(Money.text(amount))",action:{
                for order in ready { _=store.data.collectSale(order.id) }
                soldAt=Date();hint="收到 \(Money.text(amount))。"
            }) { GameSprite(index:10,size:w*0.09) }.position(x:w*0.68,y:h*0.50)
        }
        if let soldAt { SceneParticles(burst:soldAt).frame(width:w*0.25,height:h*0.35).position(x:w*0.68,y:h*0.50) }
        ObjectButton(label:"购买食材与种子",action:{market=true}) { GameSprite(index:11,size:w*0.14) }.position(x:w*0.16,y:h*0.82)
    }
    private var stockTray: some View {
        VStack(alignment:.leading,spacing:7) {
            Text("料理柜 · 累计售出 \(store.data.garden.sales) 份").font(.caption).foregroundStyle(Palette.muted)
            if availableDishes.isEmpty { Button("去厨房做料理") { store.pet?.openTool("厨房") } }
            ScrollView(.horizontal) {
                HStack(spacing:8) {
                    ForEach(availableDishes) { dish in
                        Button { shopChoice=dish.id;hint="已选 \(dish.name)" } label: {
                            VStack(spacing:4) {
                                GameSprite(sheet:"Foods",index:dish.sprite,size:56)
                                Text(dish.name).font(.system(size:11)).lineLimit(1)
                                Text("×\(store.data.garden.dishes[dish.id,default:0]) · \(Money.text(store.data.salePrice(dish)))").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                            }.frame(width:112).padding(6).magicSurface(choice?.id == dish.id ? Palette.moss : Palette.paper)
                        }.buttonStyle(.plain)
                    }
                }.padding(.bottom,4)
            }
        }
    }
    private var recipeBook: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { PixelIcon(name:"日记",size:25);Text("配方册").font(.title3);Spacer();Button("关闭"){book=false} }
            Text("已发现 \(store.data.garden.menu.filter{store.data.garden.isDiscovered($0)}.count) 份配方").font(.caption).foregroundStyle(Palette.muted)
            ScrollView {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                    ForEach(store.data.garden.menu) { dish in
                        let discovered=store.data.garden.isDiscovered(dish)
                        Button {loadRecipe(dish);book=false} label: {
                            HStack(spacing:9) {
                                if discovered {
                                    if let ingredient=dish.outputIngredient {IngredientArt(name:ingredient.rawValue,size:52)}
                                    else {GameSprite(sheet:"Foods",index:dish.sprite,size:52)}
                                }
                                else {Text("?").font(.system(size:32)).foregroundStyle(Palette.muted).frame(width:52,height:52)}
                                VStack(alignment:.leading,spacing:5) {
                                    Text(discovered ? dish.name:"未知配方").font(.system(size:12,weight:.medium))
                                    if discovered {
                                        Text((dish.outputIngredient != nil ? "原料加工":dish.category.rawValue)+" · "+dish.method.rawValue).font(.system(size:10)).foregroundStyle(Palette.goldLight)
                                        Text(dish.recipeText).font(.system(size:10)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                                    }
                                }.frame(maxWidth:.infinity,alignment:.leading)
                            }.padding(8).magicSurface(Palette.card)
                        }.buttonStyle(.plain).disabled(!discovered)
                    }
                }
            }
        }.padding(20).frame(width:650,height:540).magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
    private func loadRecipe(_ dish:Dish) {
        guard store.data.garden.isDiscovered(dish) else{return}
        guard !cooking else{return}
        let candidate:CookingIntent = dish.outputIngredient != nil ? .process : dish.category == .drink ? .drink : dish.category == .dessert ? .dessert:.dish
        var prepared=KitchenSelection()
        for (name,count) in dish.ingredients.sorted(by:{$0.key<$1.key}) {
            guard let ingredient=Ingredient(rawValue:name),store.data.ingredientCount(ingredient)>=count else{hint="食材不足，先补齐后再选这份配方。";return}
            for _ in 0..<count {guard prepared.add(ingredient,available:store.data.ingredientCount(ingredient)) else{return}}
        }
        intent=candidate;method=dish.method;selection=prepared;loadedDish=dish;lastDish=nil;hint="食材已放好。"
    }

}

struct IngredientMarket: View {
    @ObservedObject var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var waterPayment = false
    @State private var section = "种子"
    @State private var ingredientCategory:IngredientCategory = .grain
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text("食材与种子铺").font(.title3);Spacer();Text("露水 \(store.data.garden.water) · \(Money.text(store.data.garden.coins))").font(.caption);Button("关闭"){dismiss()}}
            PixelTabs(selection:$section,items:[("种子","种子"),("食材","食材")])
            Toggle(section == "种子" ? "用露水交换（每袋 3 滴）":"用露水交换（每份 1 滴）",isOn:$waterPayment)
            if section == "食材" {
                ScrollView(.horizontal) {HStack {ForEach(IngredientCategory.allCases) {item in Button(item.rawValue){ingredientCategory=item}.buttonStyle(PixelButtonStyle(primary:ingredientCategory == item))}}}
            }
            ScrollView {
                LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:4),spacing:10) {
                    if section == "种子" {
                        ForEach(Crop.marketCrops) {crop in
                            Button {if waterPayment {_ = store.data.exchangeSeed(crop)} else {_ = store.data.buySeeds(crop)}} label: {
                                VStack(spacing:4) {
                                    IngredientArt(name:crop.rawValue,size:48)
                                    Text(crop.rawValue+"种子").font(.system(size:12))
                                    Text("库存 \(store.data.garden.cropSeeds[crop.rawValue,default:0]) 袋").font(.system(size:10)).foregroundStyle(Palette.muted)
                                    Text(waterPayment ? "3 滴露水 / 袋":"4 银西可 / 3 袋").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                                }.frame(maxWidth:.infinity).padding(8).magicSurface(Palette.card)
                            }.buttonStyle(.plain).disabled(waterPayment ? store.data.garden.water<3:store.data.garden.coins<116)
                        }
                    } else {
                        ForEach(Ingredient.allCases.filter{$0.category == ingredientCategory}) {ingredient in
                            Button {_ = store.data.buyIngredient(ingredient,withWater:waterPayment)} label: {
                                VStack(spacing:4) {
                                    IngredientArt(name:ingredient.rawValue,size:48)
                                    Text(ingredient.rawValue).font(.system(size:12))
                                    Text("库存 \(store.data.ingredientCount(ingredient))").font(.system(size:10)).foregroundStyle(Palette.muted)
                                    Text(waterPayment ? "1 滴露水 / 份":"\(Money.text(ingredient.price*29)) / 份").font(.system(size:10)).foregroundStyle(Palette.goldLight)
                                }.frame(maxWidth:.infinity).padding(8).magicSurface(Palette.card)
                            }.buttonStyle(.plain).disabled(waterPayment ? store.data.garden.water<1:store.data.garden.coins<ingredient.price*29)
                        }
                    }
                }
            }
        }.padding(20).frame(width:650,height:560).magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
}
