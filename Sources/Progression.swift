import Foundation

enum Money {
    static let sickle = 29
    static let galleon = 493
    static func text(_ knuts: Int) -> String {
        let gold = knuts / galleon, silver = knuts % galleon / sickle, copper = knuts % sickle
        return [(gold,"金加隆"),(silver,"银西可"),(copper,"铜纳特")]
            .filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator:" ").nilIfEmpty ?? "0 铜纳特"
    }
}
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

struct LevelProgress {
    var level = 1
    var experience: Double
    var needed: Int { Self.requirement(level) }
    static func requirement(_ level: Int) -> Int {
        let n = Double(max(0,level-1))
        return Int(ceil(10 + 6*n + 0.08*n*n))
    }
    init(seconds: Double) {
        experience = max(0,seconds/60)
        while experience >= Double(Self.requirement(level)) {
            experience -= Double(Self.requirement(level)); level += 1
        }
    }
}

enum Upgrade: String, Codable, CaseIterable, Identifiable {
    case soil, watering, kitchen, rod, wand, shop, farmland, storefront
    var id: String { rawValue }
    var name: String {
        switch self { case .soil:return "土地培育";case .watering:return "浇水工具";case .kitchen:return "烹饪工具";case .rod:return "钓竿";case .wand:return "探险工具";case .shop:return "店面装潢";case .farmland:return "扩张农场";case .storefront:return "扩张店面" }
    }
    var limit: Int { self == .farmland || self == .storefront ? 2 : 3 }
    var icon: Int { switch self {case .soil,.farmland:return 3;case .watering:return 4;case .kitchen:return 5;case .rod:return 6;case .wand:return 7;case .shop,.storefront:return 9} }
    func price(_ rank: Int) -> Int { EconomyBalance.upgradePrice(self,rank:rank) }
    func level(_ rank:Int) -> Int { (self == .rod ? 3 : self == .wand ? 5 : 2) + rank*2 }
    var effect: String {
        switch self {
        case .soil:return "每级让每块地多收获 1 份食材"
        case .watering:return "每级让新播种作物的生长时间缩短 10%"
        case .kitchen:return "每级让新制作料理的品质提高 5 点，新上架售价增加 1 铜纳特"
        case .rod:return "每级让钓鱼所需专注减少 2 分钟"
        case .wand:return "每级让探险多获得 1 份材料"
        case .shop:return "每级让新上架料理的售价增加 2 铜纳特"
        case .farmland:return "每次新增一片有 6 块地的农场"
        case .storefront:return "每次增加 2 个可同时售卖的陈列位"
        }
    }
}

enum ClothingSlot: String, Codable, CaseIterable, Identifiable {
    case outfit, top, bottom, outer, neck, wrist, socks, head, face, shoes, focusOutfit
    var id:String {rawValue}
    var isAccessory:Bool { ![.outfit,.top,.bottom,.outer,.focusOutfit].contains(self) }
    var name:String {
        switch self {
        case .outfit:return "整套";case .top:return "上衣";case .bottom:return "下装"
        case .outer:return "外套";case .focusOutfit:return "专注套装"
        case .neck:return "围巾";case .wrist:return "手饰";case .socks:return "袜子"
        case .head:return "头饰";case .face:return "面饰";case .shoes:return "鞋"
        }
    }
}

struct Cosmetic: Identifiable {
    var id: String
    var name: String
    var slot: ClothingSlot
    var sprite = 0
    var asset: String? = nil
    var price: Int
    var level: Int
    var season: String? = nil
    var dates: String { season == "autumn" ? "10 月 24 日—11 月 2 日" : "12 月 20 日—1 月 5 日" }
    func available(_ date: Date) -> Bool {
        guard let season else { return true }
        let c = Calendar.current.dateComponents([.month,.day],from:date), m=c.month!, d=c.day!
        return season == "autumn" ? (m == 10 && d >= 24) || (m == 11 && d <= 2) : (m == 12 && d >= 20) || (m == 1 && d <= 5)
    }
    static let all: [Cosmetic] = [
        .init(id:"black",name:"黑色长袍",slot:.outfit,asset:"RobeBlack",price:0,level:1),
        .init(id:"travel",name:"深绿旅行袍",slot:.outfit,asset:"RobeTravel",price:493,level:2),
        .init(id:"winter",name:"紫灰冬日袍",slot:.outfit,asset:"RobeWinter",price:986,level:4),
        .init(id:"shirt",name:"米白衬衫",slot:.top,asset:"TopShirt",price:58,level:1),
        .init(id:"sweater",name:"炭灰毛衣",slot:.top,asset:"TopSweater",price:116,level:2),
        .init(id:"trousers",name:"深色长裤",slot:.bottom,asset:"BottomTrousers",price:87,level:1),
        .init(id:"jeans",name:"蓝色牛仔裤",slot:.bottom,asset:"BottomJeans",price:116,level:2),
        .init(id:"coat",name:"炭灰长外套",slot:.outer,asset:"OuterCoat",price:174,level:2),
        .init(id:"jacket",name:"浅棕夹克",slot:.outer,asset:"OuterJacket",price:116,level:1),
        .init(id:"grayScarf",name:"灰色围巾",slot:.neck,asset:"ScarfGray",price:58,level:1),
        .init(id:"greenScarf",name:"墨绿围巾",slot:.neck,asset:"ScarfGreen",price:87,level:2),
        .init(id:"watch",name:"经典腕表",slot:.wrist,asset:"WristWatch",price:116,level:3),
        .init(id:"bracelet",name:"银色手链",slot:.wrist,asset:"WristBracelet",price:87,level:2),
        .init(id:"blackSocks",name:"黑色短袜",slot:.socks,asset:"SocksBlack",price:29,level:1),
        .init(id:"creamSocks",name:"奶油色短袜",slot:.socks,asset:"SocksCream",price:58,level:1),
        .init(id:"longSocks",name:"深灰长袜",slot:.socks,asset:"SocksLong",price:58,level:2),
        .init(id:"wizard",name:"黑色尖顶帽",slot:.head,asset:"HeadWizard",price:174,level:2),
        .init(id:"flowers",name:"白花发夹",slot:.head,asset:"HeadFlowers",price:232,level:3),
        .init(id:"pumpkin",name:"南瓜贝雷帽",slot:.head,asset:"HeadPumpkin",price:290,level:2,season:"autumn"),
        .init(id:"snow",name:"冬日绒帽",slot:.head,asset:"HeadWinter",price:290,level:2,season:"winter"),
        .init(id:"glasses",name:"细框眼镜",slot:.face,asset:"FaceGlasses",price:58,level:1),
        .init(id:"mask",name:"黑色口罩",slot:.face,asset:"FaceMask",price:58,level:1),
        .init(id:"blackShoes",name:"黑色皮鞋",slot:.shoes,asset:"ShoesBlack",price:87,level:1),
        .init(id:"boots",name:"棕色短靴",slot:.shoes,asset:"ShoesBoots",price:116,level:2),
        .init(id:"focusSuit",name:"书房常服",slot:.focusOutfit,asset:"FocusSuit",price:174,level:2)
    ]
}

enum JourneyKind: String, Codable, CaseIterable, Identifiable {
    case fishing = "湖畔钓鱼", adventure = "林间冒险", potions = "熬制魔药"
    var id: String { rawValue }
    var level: Int { self == .fishing ? 3 : self == .adventure ? 5 : 8 }
    var scene: String { self == .fishing ? "Lake" : self == .adventure ? "Forest" : "Laboratory" }
    var icon: Int { self == .fishing ? 6 : self == .adventure ? 9 : 11 }
}
struct Journey: Codable {
    var kind: JourneyKind
    var startedAt: Double
    var duration: Double
    var recipe: String?
    func progress(_ total:Double) -> Double { min(1,max(0,(total-startedAt)/duration)) }
}
struct Potion: Identifiable {
    var id: String
    var name: String
    var ingredient: String
    var material: String
    var price: Int
    var benefit: String
    static let all: [Potion] = [
        .init(id:"dew",name:"丰沛露水",ingredient:"薄荷",material:"月光草",price:42,benefit:"使用后获得 6 滴露水"),
        .init(id:"seed",name:"萌芽药剂",ingredient:"南瓜",material:"琥珀石",price:60,benefit:"使用后获得 3 袋种子"),
        .init(id:"bloom",name:"繁盛药剂",ingredient:"草莓",material:"星砂",price:65,benefit:"使用后让当前已种作物增加 5 分钟生长进度")
    ]
}

struct WearAdjustment: Codable, Equatable {
    var x = 0
    var y = 0
    var scale = 100
}

struct Economy: Codable {
    var upgrades: [String:Int] = [:]
    var owned: Set<String> = []
    var outfit = ""
    var hat = ""
    var equipped: [String:String]? = nil
    var adjustments: [String:WearAdjustment]? = nil
    var redeemedKeys = 0
    var redeemedActions:Int? = nil
    var extraOrders: [ShopOrder] = []
    var journey: Journey?
    var finds: [String:Int] = [:]
    var expeditions = 0
    func adjustment(for id:String) -> WearAdjustment {
        adjustments?[id] ?? WearAdjustment()
    }
    func worn(_ slot:ClothingSlot) -> String {
        switch slot {
        case .outfit:return outfit.isEmpty ? "black":outfit == "base" ? "":outfit
        case .head:return hat
        default:return equipped?[slot.rawValue] ?? ""
        }
    }
}

extension Garden {
    func rank(_ upgrade:Upgrade) -> Int { economy.upgrades[upgrade.rawValue,default:0] }
    var orders: [ShopOrder] { (order.map { [$0] } ?? []) + economy.extraOrders }
    var capacity: Int { 1 + rank(.storefront)*2 }
}

extension AppData {
    var levelProgress: LevelProgress { LevelProgress(seconds:totalFocus) }
    var totalActions:Int { keys.values.reduce(0,+) + (mouseClicks ?? [:]).values.reduce(0,+) }
    var consumedActions:Int { garden.economy.redeemedActions ?? garden.economy.redeemedKeys*1000 }
    var typingReward: Int { max(0,(totalActions-consumedActions)/10000) }
    var harvestYield: Int { 2 + garden.rank(.soil) }
    func salePrice(_ dish:Dish) -> Int { EconomyBalance.salePrice(dish,shopRank:garden.rank(.shop),kitchenRank:garden.rank(.kitchen)) }
    mutating func redeemTyping() -> Bool {
        let amount=typingReward
        guard amount>0 else{return false}
        garden.coins += amount;garden.economy.redeemedActions = consumedActions + amount*10000
        return true
    }
    mutating func upgrade(_ item:Upgrade) -> Bool {
        let rank=garden.rank(item)
        guard rank<item.limit,levelProgress.level>=item.level(rank),garden.coins>=item.price(rank) else{return false}
        garden.coins -= item.price(rank);garden.economy.upgrades[item.rawValue]=rank+1
        if item == .farmland { garden.plots += (0..<6).map{_ in Plot()} }
        return true
    }
    mutating func buyCosmetic(_ item:Cosmetic,at date:Date) -> Bool {
        guard let item = Cosmetic.all.first(where: { $0.id == item.id }),
              !garden.economy.owned.contains(item.id),item.available(date),levelProgress.level>=item.level,garden.coins>=item.price else{return false}
        garden.coins -= item.price;garden.economy.owned.insert(item.id)
        return true
    }
    mutating func wear(_ id:String,slot:ClothingSlot) -> Bool {
        guard id.isEmpty || Cosmetic.all.contains(where:{$0.id == id && $0.slot == slot && ($0.price == 0 || garden.economy.owned.contains(id))}) else{return false}
        if slot == .outfit {
            garden.economy.outfit = id.isEmpty ? "base":id == "black" ? "":id
            if !id.isEmpty {
                garden.economy.equipped?.removeValue(forKey:ClothingSlot.top.rawValue)
                garden.economy.equipped?.removeValue(forKey:ClothingSlot.bottom.rawValue)
            }
        } else if slot == .head {garden.economy.hat=id}
        else if id.isEmpty {garden.economy.equipped?.removeValue(forKey:slot.rawValue)}
        else {
            if slot == .top || slot == .bottom {garden.economy.outfit="base"}
            if garden.economy.equipped == nil {garden.economy.equipped=[:]}
            garden.economy.equipped?[slot.rawValue]=id
        }
        return true
    }
    mutating func wear(_ id:String,outfit:Bool) -> Bool {
        wear(outfit ? (id.isEmpty ? "black":id == "base" ? "":id):id,slot:outfit ? .outfit:.head)
    }
    mutating func embark(_ kind:JourneyKind,recipe:String?=nil) -> Bool {
        guard levelProgress.level>=kind.level,garden.economy.journey == nil else{return false}
        let duration:Double
        if kind == .potions {
            guard let potion=Potion.all.first(where:{$0.id == recipe}),garden.ingredients[potion.ingredient,default:0]>0,garden.economy.finds[potion.material,default:0]>0 else{return false}
            garden.ingredients[potion.ingredient,default:0]-=1;garden.economy.finds[potion.material,default:0]-=1
            duration=900
        } else { duration=kind == .fishing ? Double(900-garden.rank(.rod)*120) : 1200 }
        garden.economy.journey=Journey(kind:kind,startedAt:totalFocus,duration:duration,recipe:kind == .potions ? recipe : nil)
        return true
    }
    mutating func collectJourney() -> String? {
        guard let trip=garden.economy.journey,trip.progress(totalFocus)>=1 else{return nil}
        let item:String, count:Int
        switch trip.kind {
        case .fishing:item=["银鳞鱼","月光鱼","金纹鱼"][garden.economy.expeditions%3];count=1
        case .adventure:item=["月光草","琥珀石","星砂"][garden.economy.expeditions%3];count=1+garden.rank(.wand)
        case .potions:guard let id=trip.recipe,Potion.all.contains(where:{$0.id == id}) else{return nil};item=id;count=1
        }
        garden.economy.finds[item,default:0]+=count;garden.economy.journey=nil;garden.economy.expeditions+=1
        return "获得 \(Potion.all.first{$0.id == item}?.name ?? item) ×\(count)"
    }
    func findPrice(_ item:String) -> Int {
        if let potion=Potion.all.first(where:{$0.id == item}) {return potion.price}
        return ["银鳞鱼":12,"月光鱼":20,"金纹鱼":30,"月光草":15,"琥珀石":25,"星砂":35][item] ?? 0
    }
    mutating func sellFind(_ item:String) -> Bool {
        let price=findPrice(item)
        guard price>0,garden.economy.finds[item,default:0]>0 else{return false}
        garden.economy.finds[item,default:0]-=1;garden.coins+=price;return true
    }
    mutating func usePotion(_ id:String) -> Bool {
        guard garden.economy.finds[id,default:0]>0 else{return false}
        switch id {
        case "dew":garden.water+=6
        case "seed":garden.cropSeeds[Crop.carrot.rawValue,default:0]+=1;garden.cropSeeds[Crop.wheat.rawValue,default:0]+=1;garden.cropSeeds[Crop.tomato.rawValue,default:0]+=1
        case "bloom":
            guard garden.plots.contains(where:{$0.crop != nil}) else{return false}
            for index in garden.plots.indices where garden.plots[index].crop != nil { garden.plots[index].bonus += 300 }
        default:return false
        }
        garden.economy.finds[id,default:0]-=1;return true
    }
}
