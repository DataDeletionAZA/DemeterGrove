import Foundation

struct KitchenSelection {
    struct Portion: Identifiable {
        let id = UUID()
        let ingredient: Ingredient
        let slot: Int
        let droppedAt: Date
    }
    private(set) var portions: [Portion] = []
    var counts: [String:Int] { portions.reduce(into:[:]) { $0[$1.ingredient.rawValue,default:0] += 1 } }
    mutating func add(_ ingredient: Ingredient, available: Int, at date: Date = Date()) -> Bool {
        guard portions.count < 6, available > counts[ingredient.rawValue,default:0],
              let slot = (0..<6).first(where: { slot in !portions.contains(where: { $0.slot == slot }) }) else { return false }
        portions.append(Portion(ingredient:ingredient,slot:slot,droppedAt:date))
        return true
    }
    mutating func remove(_ id: UUID) { portions.removeAll { $0.id == id } }
    mutating func clear() { portions.removeAll() }
}

enum IngredientDrop {
    static func height(age: TimeInterval) -> Double {
        if age < 0.34 { return -100 * (1-pow(max(0,age)/0.34,2)) }
        if age < 0.52 { return -10 * sin((age-0.34)/0.18 * .pi) }
        if age < 0.64 { return -3 * sin((age-0.52)/0.12 * .pi) }
        return 0
    }
}

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case main = "主食", hot = "热菜", cold = "冷菜", dessert = "甜点", drink = "饮品"
    var id: String { rawValue }
    var defaultSprite: Int { switch self { case .main: return 0; case .hot: return 7; case .cold: return 10; case .dessert: return 17; case .drink: return 20 } }
}

enum IngredientCategory:String,CaseIterable,Identifiable {
    case farm = "农场蔬果", fish = "鱼类", dairy = "蛋奶", grain = "谷物与半成品", seasoning = "调味与饮料"
    var id:String { rawValue }
}
enum CookingMethod:String,Codable,CaseIterable,Identifiable {
    case boil = "煮", fry = "炒", steam = "蒸", bake = "烘烤", mix = "拌合", brew = "冲泡"
    var id:String {rawValue}
    static func legacy(_ base:String) -> CookingMethod {
        switch base { case "stirfry":return .fry;case "bread","bake","cake","toast":return .bake;case "salad":return .mix;case "tea","milk","coffee":return .brew;default:return .boil }
    }
}

enum CookingIntent: String, CaseIterable, Identifiable {
    case dish = "菜肴", drink = "饮品", dessert = "甜点", process = "原料加工"
    var id: String { rawValue }

    func category(method: CookingMethod, ingredients: [String:Int]) -> FoodCategory {
        switch self {
        case .drink: return .drink
        case .dessert: return .dessert
        case .process: return .main
        case .dish:
            if ingredients.keys.contains(where: { ["米饭","面条","大米","小麦","面包"].contains($0) }) { return .main }
            return method == .mix ? .cold : .hot
        }
    }

    func methods(ingredients: [String:Int]) -> [CookingMethod] {
        guard !ingredients.isEmpty, ingredients.values.allSatisfy({ (1...6).contains($0) }), ingredients.values.reduce(0,+) <= 6,
              ingredients.keys.allSatisfy({ Ingredient(rawValue:$0) != nil }) else { return [] }
        let names = Set(ingredients.keys)
        switch self {
        case .process:
            return CookingMethod.allCases.filter { method in
                Dish.allCases.contains { $0.outputIngredient != nil && $0.ingredients == ingredients && $0.method == method }
            }
        case .drink:
            let allowed: Set<String> = ["牛奶","茶叶","焙炒茶叶","薄荷","柠檬","蜂蜜","砂糖","可可","咖啡豆","草莓"]
            guard names.isSubset(of: allowed), !names.isDisjoint(with: ["牛奶","茶叶","焙炒茶叶","薄荷","柠檬","可可","咖啡豆","草莓"]) else { return [] }
            var result: [CookingMethod] = [.brew,.boil]
            if names.isDisjoint(with:["茶叶","焙炒茶叶","咖啡豆"]) { result.append(.mix) }
            return result
        case .dessert:
            let allowed: Set<String> = ["小麦","牛奶","鸡蛋","蜂蜜","砂糖","可可","草莓","南瓜","胡萝卜","玉米","柠檬","薄荷","蛋糕胚","面包"]
            guard names.isSubset(of: allowed), !names.isDisjoint(with:["小麦","牛奶","鸡蛋","草莓","南瓜","蛋糕胚","面包"]) else { return [] }
            var result: [CookingMethod] = [.bake]
            if names.contains("牛奶") && names.contains("鸡蛋") { result += [.boil,.steam] }
            if names.isDisjoint(with:["小麦","鸡蛋","南瓜"]) { result.append(.mix) }
            return result
        case .dish:
            guard names.isDisjoint(with:["茶叶","焙炒茶叶","咖啡豆","可可"]),
                  names.contains(where: { name in
                      guard let item = Ingredient(rawValue:name) else { return false }
                      return item.category == .fish || item.category == .grain || item == .egg ||
                          (item.category == .farm && ![Ingredient.strawberry,.mint,.lemon].contains(item))
                  }) else { return [] }
            var result: [CookingMethod] = [.boil,.fry,.steam,.bake]
            if names.isDisjoint(with:["鸡蛋","小麦","大米","土豆","南瓜","银鳞鱼","月光鱼","金纹鱼"]) { result.append(.mix) }
            return result
        }
    }

    func develop(method: CookingMethod, ingredients: [String:Int], practice: Int = 0) -> Dish? {
        guard methods(ingredients:ingredients).contains(method) else { return nil }
        if self == .process {
            guard var output = Dish.allCases.first(where: { $0.outputIngredient != nil && $0.ingredients == ingredients && $0.method == method }) else { return nil }
            output.quality = min(95,output.quality + practice*2)
            return output
        }
        let category = category(method:method,ingredients:ingredients)
        if var known = Dish.allCases.first(where: { $0.outputIngredient == nil && $0.method == method && $0.category == category && $0.ingredients == ingredients }) {
            known.quality = min(95,known.quality + practice*2)
            return known
        }
        guard var dish = Dish.develop(method:method,category:category,ingredients:ingredients,practice:practice) else { return nil }
        if dish.outputIngredient != nil {
            let key = ingredients.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator:",")
            dish.id = "custom|" + method.rawValue + "|" + category.rawValue + "|" + key
        }
        let prefix = ingredients.keys.sorted().prefix(2).joined(separator:"·")
        let ending: String
        switch self {
        case .drink: ending = method == .mix ? "特调" : "热饮"
        case .dessert: ending = method == .bake ? "烘焙点心" : method == .mix ? "甜点" : "奶点"
        case .dish: ending = method == .boil ? "炖煮" : method == .fry ? "小炒" : method == .steam ? "清蒸" : method == .bake ? "焗烤" : "拌菜"
        case .process: ending = ""
        }
        dish.name = prefix + ending
        return dish
    }
}

enum Ingredient: String, Codable, CaseIterable, Identifiable {
    case roastedTea = "焙炒茶叶", carrot = "胡萝卜", wheat = "小麦", tomato = "番茄", potato = "土豆", cucumber = "黄瓜", cabbage = "卷心菜", mushroom = "蘑菇", corn = "玉米", pumpkin = "南瓜", strawberry = "草莓", mint = "薄荷", lemon = "柠檬", rice = "大米", egg = "鸡蛋", milk = "牛奶", honey = "蜂蜜", tea = "茶叶", sugar = "砂糖", cocoa = "可可", coffee = "咖啡豆", cookedRice = "米饭", noodles = "面条", cakeBase = "蛋糕胚", bread = "面包", silverFish = "银鳞鱼", moonFish = "月光鱼", goldFish = "金纹鱼"
    var id: String { rawValue }
    var category:IngredientCategory {
        if self == .wheat {return .grain}
        if Crop(rawValue:rawValue) != nil { return .farm }
        switch self {
        case .silverFish,.moonFish,.goldFish:return .fish
        case .egg,.milk:return .dairy
        case .rice,.cookedRice,.noodles,.cakeBase,.bread:return .grain
        default:return .seasoning
        }
    }
    var price: Int { switch self { case .cakeBase:return 8;case .bread:return 5;case .cookedRice,.noodles:return 4;case .silverFish:return 3;case .moonFish:return 4;case .goldFish:return 5;case .milk,.egg,.honey,.cocoa,.coffee:return 3;default:return 2 } }
    var purchasePrice: Int {
        switch self {
        case .carrot,.cucumber,.cabbage,.mint,.sugar,.rice,.egg:return 6
        case .wheat,.tomato,.potato,.corn,.tea,.cookedRice:return 8
        case .mushroom,.lemon:return 10
        case .pumpkin,.strawberry,.milk,.roastedTea:return 12
        case .honey,.cocoa,.coffee:return 14
        case .noodles,.silverFish:return 18
        case .bread:return 24
        case .moonFish:return 28
        case .cakeBase,.goldFish:return 40
        }
    }
}

struct FoodBase: Identifiable, Hashable {
    var id: String
    var name: String
    var category: FoodCategory
    var ingredients: [String: Int]
    var sprite: Int
    var baseSprite: Int { Self.all.firstIndex { $0.id == id } ?? 0 }
    static let all: [FoodBase] = [
        .init(id: "rice", name: "米饭", category: .main, ingredients: ["大米": 1], sprite: 0),
        .init(id: "noodles", name: "面条", category: .main, ingredients: ["小麦": 1], sprite: 2),
        .init(id: "bread", name: "面包", category: .main, ingredients: ["小麦": 1], sprite: 4),
        .init(id: "soup", name: "清汤", category: .hot, ingredients: [:], sprite: 5),
        .init(id: "stirfry", name: "炒菜", category: .hot, ingredients: [:], sprite: 6),
        .init(id: "bake", name: "焗烤", category: .hot, ingredients: ["牛奶": 1], sprite: 8),
        .init(id: "salad", name: "沙拉", category: .cold, ingredients: [:], sprite: 10),
        .init(id: "cake", name: "蛋糕胚", category: .dessert, ingredients: ["小麦": 1, "鸡蛋": 1], sprite: 15),
        .init(id: "pudding", name: "布丁", category: .dessert, ingredients: ["牛奶": 1, "鸡蛋": 1], sprite: 17),
        .init(id: "toast", name: "吐司", category: .dessert, ingredients: ["小麦": 1], sprite: 18),
        .init(id: "tea", name: "茶", category: .drink, ingredients: ["茶叶": 1], sprite: 21),
        .init(id: "milk", name: "牛奶", category: .drink, ingredients: ["牛奶": 1], sprite: 23),
        .init(id: "coffee", name: "咖啡", category: .drink, ingredients: ["咖啡豆": 1], sprite: 20)
    ]
}

struct Dish: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var category: FoodCategory
    var baseID: String
    var ingredients: [String: Int]
    var sprite: Int
    var quality: Int = 50
    var kitchenBonus = 0
    var methodID:CookingMethod? = nil
    var method:CookingMethod { methodID ?? CookingMethod.legacy(baseID) }
    var outputIngredient:Ingredient? {
        switch id {case "米饭":return .cookedRice;case "面条":return .noodles;case "蛋糕胚":return .cakeBase;case "面包":return .bread;case "焙炒茶叶":return .roastedTea;default:return nil}
    }
    var rawValue: String { id }
    var price: Int { id == "胡萝卜浓汤" ? 12 : id == "番茄面" ? 16 : 6 + ingredients.reduce(0) { $0 + (Ingredient(rawValue: $1.key)?.price ?? 2) * $1.value } + quality / 10 }
    var stars: Int { min(5, max(1, quality / 20 + 1)) }
    var isDiscovery: Bool { Self.allCases.contains { $0.id == id } }
    var recipeText: String { ingredients.sorted { $0.key < $1.key }.map { "\($0.key) ×\($0.value)" }.joined(separator: " · ") }

    static let allCases: [Dish] = {
        let rows: [(String, FoodCategory, String, [String:Int])] = [
            ("田园饭", .main, "rice", ["米饭":1,"胡萝卜":1,"玉米":1]),
            ("蛋炒饭", .main, "rice", ["米饭":1,"鸡蛋":1]),
            ("番茄面", .main, "noodles", ["面条":1,"番茄":1]),
            ("蘑菇烩饭", .main, "rice", ["米饭":1,"蘑菇":1,"牛奶":1]),
            ("南瓜面包", .main, "bread", ["小麦":1,"南瓜":1]),
            ("胡萝卜浓汤", .hot, "soup", ["胡萝卜":2]),
            ("番茄炒蛋", .hot, "stirfry", ["番茄":1,"鸡蛋":1]),
            ("蘑菇炖菜", .hot, "soup", ["蘑菇":1,"土豆":1]),
            ("奶香焗土豆", .hot, "bake", ["牛奶":1,"土豆":1]),
            ("奶油玉米汤", .hot, "soup", ["玉米":1,"牛奶":1]),
            ("田园沙拉", .cold, "salad", ["黄瓜":1,"番茄":1]),
            ("薄荷拌黄瓜", .cold, "salad", ["黄瓜":1,"薄荷":1]),
            ("柠檬胡萝卜丝", .cold, "salad", ["胡萝卜":1,"柠檬":1]),
            ("甜玉米沙拉", .cold, "salad", ["玉米":1,"黄瓜":1]),
            ("柠檬卷心菜", .cold, "salad", ["卷心菜":1,"柠檬":1]),
            ("草莓奶油蛋糕", .dessert, "cake", ["蛋糕胚":1,"草莓":1,"牛奶":1]),
            ("南瓜布丁", .dessert, "pudding", ["牛奶":1,"鸡蛋":1,"南瓜":1]),
            ("牛奶布丁", .dessert, "pudding", ["牛奶":1,"鸡蛋":1,"砂糖":1]),
            ("蜂蜜吐司", .dessert, "toast", ["面包":1,"蜂蜜":1]),
            ("巧克力蛋糕", .dessert, "cake", ["蛋糕胚":1,"可可":1]),
            ("奶茶", .drink, "tea", ["茶叶":1,"牛奶":1]),
            ("柠檬茶", .drink, "tea", ["茶叶":1,"柠檬":1]),
            ("薄荷茶", .drink, "tea", ["茶叶":1,"薄荷":1]),
            ("草莓牛奶", .drink, "milk", ["牛奶":1,"草莓":1]),
            ("热可可", .drink, "milk", ["牛奶":1,"可可":1])
        ]
        var result = rows.enumerated().map { index, r in
            var dish = Dish(id:r.0,name:r.0,category:r.1,baseID:r.2,ingredients:r.3,sprite:index,quality:65)
            if ["田园饭","蛋炒饭","蘑菇烩饭"].contains(r.0) { dish.methodID = .fry }
            return dish
        }
        for (name,ingredients,sprite,method) in [
            ("米饭",["大米":1],0,CookingMethod.boil),
            ("面条",["小麦":1,"鸡蛋":1],2,CookingMethod.mix),
            ("蛋糕胚",["小麦":1,"鸡蛋":1,"牛奶":1],15,CookingMethod.bake),
            ("面包",["小麦":1,"牛奶":1],4,CookingMethod.bake),
            ("焙炒茶叶",["茶叶":1],21,CookingMethod.fry)
        ] {
            let category:FoodCategory = name == "焙炒茶叶" ? .drink : name == "蛋糕胚" ? .dessert:.main
            let baseID = name == "焙炒茶叶" ? "tea":name == "蛋糕胚" ? "cake":name == "面条" ? "noodles":name == "面包" ? "bread":"rice"
            var dish=Dish(id:name,name:name,category:category,baseID:baseID,ingredients:ingredients,sprite:sprite,quality:60)
            dish.methodID=method;result.append(dish)
        }
        for (name,ingredient,sprite,method) in [("清蒸银鳞鱼","银鳞鱼",7,CookingMethod.steam),("柠檬月光鱼","月光鱼",8,CookingMethod.bake),("香煎金纹鱼","金纹鱼",6,CookingMethod.fry)] {
            var ingredients=[ingredient:1];if ingredient == "月光鱼" { ingredients["柠檬"]=1 }
            var dish=Dish(id:name,name:name,category:.hot,baseID:"soup",ingredients:ingredients,sprite:sprite,quality:70)
            dish.methodID=method;result.append(dish)
        }
        return result
    }()
    static var soup: Dish { allCases[5] }
    static var pasta: Dish { allCases[2] }

    static func develop(base: FoodBase, additions: [String:Int], practice: Int = 0) -> Dish? {
        guard !additions.isEmpty, additions.values.allSatisfy({ (1...4).contains($0) }), additions.values.reduce(0,+) <= 4,
              additions.keys.allSatisfy({ Ingredient(rawValue: $0) != nil }) else { return nil }
        var ingredients = base.ingredients
        for (key, value) in additions { ingredients[key, default: 0] += value }
        if var known = allCases.first(where: { $0.baseID == base.id && $0.ingredients == ingredients }) {
            known.quality = min(95, known.quality + practice * 2); return known
        }
        let key = "custom|" + base.id + "|" + ingredients.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ",")
        let prefix = additions.keys.sorted().prefix(2).joined(separator: "·")
        let name = prefix + (base.id == "cake" ? "蛋糕" : base.name)
        let sweet = ingredients.keys.contains { ["砂糖","蜂蜜","草莓","可可"].contains($0) }
        let savory = ingredients.keys.contains { ["蘑菇","番茄","卷心菜"].contains($0) }
        let harmony = (base.category == .dessert || base.category == .drink) ? (sweet ? 12 : 0) - (savory ? 8 : 0) : (savory ? 10 : 0)
        return Dish(id: key, name: name, category: base.category, baseID: base.id, ingredients: ingredients, sprite: base.sprite,
                    quality: min(95, max(25, 40 + ingredients.count * 4 + harmony + practice * 2)))
    }

    static func develop(method:CookingMethod, category:FoodCategory, ingredients:[String:Int], practice:Int = 0) -> Dish? {
        guard !ingredients.isEmpty, ingredients.values.allSatisfy({(1...6).contains($0)}), ingredients.values.reduce(0,+)<=6,
              ingredients.keys.allSatisfy({Ingredient(rawValue:$0) != nil}) else {return nil}
        if var known=allCases.first(where:{$0.method == method && $0.ingredients == ingredients && ($0.category == category || $0.outputIngredient != nil)}) {
            known.quality=min(95,known.quality+practice*2);return known
        }
        let id="custom|"+method.rawValue+"|"+category.rawValue+"|"+ingredients.sorted{$0.key<$1.key}.map{"\($0.key):\($0.value)"}.joined(separator:",")
        let baseID:String
        switch category {case .main:baseID="rice";case .hot:baseID="soup";case .cold:baseID="salad";case .dessert:baseID="cake";case .drink:baseID="tea"}
        let prefix=ingredients.keys.sorted().prefix(2).joined(separator:"·")
        var dish=Dish(id:id,name:prefix+method.rawValue+category.rawValue,category:category,baseID:baseID,ingredients:ingredients,sprite:category.defaultSprite,quality:min(95,40+ingredients.count*4+practice*2))
        dish.methodID=method;return dish
    }

    enum CodingKeys: String, CodingKey { case id, name, category, baseID, ingredients, sprite, quality, kitchenBonus, methodID }
    init(id: String, name: String, category: FoodCategory, baseID: String, ingredients: [String:Int], sprite: Int, quality: Int = 50) {
        self.id=id; self.name=name; self.category=category; self.baseID=baseID; self.ingredients=ingredients; self.sprite=sprite; self.quality=quality
    }
    init(from decoder: Decoder) throws {
        if let legacy = try? decoder.singleValueContainer().decode(String.self), var dish = Self.allCases.first(where: { $0.id == legacy }) {
            if dish.outputIngredient == nil {
                let previousInputs:[String:[String:Int]] = ["米饭":["大米":1],"面条":["小麦":1],"面包":["小麦":1],"蛋糕胚":["小麦":1,"鸡蛋":1]]
                for (ingredient,inputs) in previousInputs {
                    if let count=dish.ingredients.removeValue(forKey:ingredient) {
                        for (name,amount) in inputs {dish.ingredients[name,default:0]+=count*amount}
                    }
                }
            }
            self=dish;return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        category = try c.decode(FoodCategory.self, forKey: .category); baseID = try c.decode(String.self, forKey: .baseID)
        ingredients = try c.decode([String:Int].self, forKey: .ingredients); sprite = try c.decode(Int.self, forKey: .sprite)
        quality = try c.decode(Int.self, forKey: .quality)
        kitchenBonus = try c.decodeIfPresent(Int.self, forKey: .kitchenBonus) ?? 0
        methodID = try c.decodeIfPresent(CookingMethod.self, forKey:.methodID)
    }
    var isValid: Bool {
        !id.isEmpty && id.count <= 512 && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 &&
        (0..<25).contains(sprite) && (0...100).contains(quality) && (0...15).contains(kitchenBonus) && kitchenBonus <= quality && FoodBase.all.contains { $0.id == baseID && $0.category == category } &&
        !ingredients.isEmpty && ingredients.values.allSatisfy { (1...6).contains($0) } && ingredients.values.reduce(0,+) <= 6 && ingredients.keys.allSatisfy { Ingredient(rawValue: $0) != nil }
    }
}
