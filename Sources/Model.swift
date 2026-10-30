import Foundation

func dayKey(_ date: Date = Date()) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

struct GardenTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var notes = ""
    var category: String? = nil
    var categoryName: String { category ?? "任务" }
    var important = true
    var urgent = false
    var due: Date?
    var completedAt: Date?
    var quadrant: Int { important ? (urgent ? 0 : 1) : (urgent ? 2 : 3) }
}

struct Appointment: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var start = Date()
    var end = Date().addingTimeInterval(3600)
    var notes = ""
    var remind = true
}

struct Habit: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var days: Set<String> = []
    var reminderMinutes: Int? = nil
    var encouragement: String? = nil
    var checkIns: [String: HabitCheckIn]? = nil
    func streak(at date: Date = Date()) -> Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: date)
        if !days.contains(dayKey(cursor)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var count = 0
        while days.contains(dayKey(cursor)) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }
}

struct Diary: Codable, Equatable {
    var text = ""
    var mood = "平静"
    var moodSymbol: String? = nil
    var moodImage: Data? = nil
    var characters: Int { text.filter { !$0.isWhitespace }.count }
}

enum TimerKind: String, Codable, CaseIterable, Identifiable {
    case pomodoro = "番茄钟", stopwatch = "正计时", countdown = "倒计时", rest = "休息"
    var id: String { rawValue }
}

struct TimerRun: Codable, Identifiable {
    var id = UUID()
    var kind: TimerKind
    var target: TimeInterval
    var taskID: UUID?
    var taskTitle: String
    var startedAt: Date
    var resumedAt: Date?
    var accumulated: TimeInterval = 0
    func elapsed(at now: Date) -> TimeInterval {
        let raw = accumulated + (resumedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        return kind == .stopwatch ? raw : min(target, raw)
    }
    func display(at now: Date) -> TimeInterval {
        kind == .stopwatch ? elapsed(at: now) : max(0, target - elapsed(at: now))
    }
    mutating func pause(at now: Date) {
        accumulated = elapsed(at: now)
        resumedAt = nil
    }
}

struct FocusSession: Codable, Identifiable {
    var id: UUID
    var taskID: UUID?
    var title: String
    var kind: TimerKind
    var date: Date
    var seconds: TimeInterval
}

enum Crop: String, Codable, CaseIterable, Identifiable {
    case carrot = "胡萝卜", wheat = "小麦", tomato = "番茄", potato = "土豆", cucumber = "黄瓜", cabbage = "卷心菜", mushroom = "蘑菇", corn = "玉米", pumpkin = "南瓜", strawberry = "草莓", mint = "薄荷", lemon = "柠檬", starlightCarrot = "星露胡萝卜"
    var id: String { rawValue }
    static var marketCrops: [Crop] { allCases.filter { $0 != .starlightCarrot } }
    var artCrop: Crop { self == .starlightCarrot ? .carrot : self }
    var harvestName: String { artCrop.rawValue }
    var seconds: Double { switch self { case .mint, .carrot, .starlightCarrot: return 600; case .wheat, .cucumber, .mushroom: return 900; case .tomato, .potato, .cabbage, .corn: return 1200; default: return 1500 } }
}

struct Plot: Codable, Identifiable {
    var id = UUID()
    var crop: Crop?
    var plantedAt: Double = 0
    var duration: Double? = nil
    var bonus: Double = 0
    enum CodingKeys:String,CodingKey { case id,crop,plantedAt,duration,bonus }
    func progress(_ focus: Double) -> Double {
        guard let crop else { return 0 }
        return min(1, max(0, (focus - plantedAt + bonus) / (duration ?? crop.seconds)))
    }
    func growthStage(_ focus: Double) -> Int {
        let value = progress(focus)
        if value < 0.08 { return 0 }
        if value < 0.30 { return 1 }
        return value < 1 ? 2 : 3
    }
}

extension Plot {
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decode(UUID.self,forKey:.id);crop=try c.decodeIfPresent(Crop.self,forKey:.crop)
        plantedAt=try c.decode(Double.self,forKey:.plantedAt)
        duration=try c.decodeIfPresent(Double.self,forKey:.duration)
        bonus=try c.decodeIfPresent(Double.self,forKey:.bonus) ?? 0
    }
}

struct ShopOrder: Codable {
    var id = UUID()
    var dish: Dish
    var placedAt: Double
    var proceeds: Int? = nil
    var price: Int { proceeds ?? dish.price*29 }
    enum CodingKeys:String,CodingKey { case id,dish,placedAt,proceeds }
    func ready(_ focus: Double) -> Bool { focus - placedAt >= 300 }
}
extension ShopOrder {
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
        dish=try c.decode(Dish.self,forKey:.dish);placedAt=try c.decode(Double.self,forKey:.placedAt)
        proceeds=try c.decodeIfPresent(Int.self,forKey:.proceeds)
    }
}

struct Garden: Codable {
    var plots: [Plot] = (0..<6).map { _ in Plot() }
    var cropSeeds: [String:Int] = ["胡萝卜":2,"小麦":2,"番茄":2]
    var seeds: Int {
        get { cropSeeds.values.reduce(0,+) }
        set {
            guard newValue >= 0 else {cropSeeds = [Crop.carrot.rawValue:newValue];return}
            let difference = newValue-seeds
            if difference >= 0 {
                for (crop,count) in Self.distributeSeeds(difference) {cropSeeds[crop,default:0]+=count}
            } else {
                var remaining = -difference
                for crop in Crop.allCases {
                    let removed=min(remaining,cropSeeds[crop.rawValue,default:0])
                    cropSeeds[crop.rawValue,default:0]-=removed;remaining-=removed
                }
            }
        }
    }
    static func distributeSeeds(_ count:Int) -> [String:Int] {
        guard count > 0 else { return [:] }
        var result:[String:Int] = [:]
        for (index,crop) in Crop.marketCrops.enumerated() {
            let quantity = count / Crop.marketCrops.count + (index < count % Crop.marketCrops.count ? 1 : 0)
            if quantity > 0 { result[crop.rawValue] = quantity }
        }
        return result
    }
    var water = 4
    var coins = 0
    var ingredients: [String: Int] = ["大米":2, "鸡蛋":3, "牛奶":3, "小麦":2, "草莓":2, "茶叶":2, "砂糖":2]
    var dishes: [String: Int] = [:]
    var order: ShopOrder?
    var sales = 0
    var recipes: [String: Dish] = [:]
    var crafts: [String: Int] = [:]
    var economy = Economy()
    func isDiscovered(_ dish:Dish) -> Bool {
        recipes[dish.id] != nil || crafts[dish.id,default:0]>0 || dishes[dish.id,default:0]>0 || orders.contains{$0.dish.id == dish.id}
    }
    var menu: [Dish] {
        let builtIn = Dish.allCases.filter { recipes[$0.id] == nil }
        return (builtIn + Array(recipes.values)).sorted { $0.name < $1.name }
    }
    init() { }
    enum CodingKeys: String, CodingKey { case plots, seeds, cropSeeds, water, coins, ingredients, dishes, order, sales, recipes, crafts, economy }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plots = try c.decode([Plot].self, forKey: .plots)
        if let saved = try c.decodeIfPresent([String:Int].self, forKey:.cropSeeds) { cropSeeds = saved }
        else {
            let count = try c.decode(Int.self,forKey:.seeds)
            guard (0...1_000_000_000).contains(count) else { throw DataIssue.invalid }
            cropSeeds = Self.distributeSeeds(count)
        }
        water = try c.decode(Int.self, forKey: .water); coins = try c.decode(Int.self, forKey: .coins)
        ingredients = try c.decode([String:Int].self, forKey: .ingredients); dishes = try c.decode([String:Int].self, forKey: .dishes)
        order = try c.decodeIfPresent(ShopOrder.self, forKey: .order); sales = try c.decode(Int.self, forKey: .sales)
        recipes = try c.decodeIfPresent([String:Dish].self, forKey: .recipes) ?? [:]
        crafts = try c.decodeIfPresent([String:Int].self, forKey: .crafts) ?? [:]
        if let saved=try c.decodeIfPresent(Economy.self,forKey:.economy) { economy=saved }
        else {
            guard (0...1_000_000_000).contains(coins) else { throw DataIssue.invalid }
            coins *= 29
        }
    }
    func encode(to encoder:Encoder) throws {
        var c = encoder.container(keyedBy:CodingKeys.self)
        try c.encode(plots,forKey:.plots);try c.encode(seeds,forKey:.seeds);try c.encode(cropSeeds,forKey:.cropSeeds)
        try c.encode(water,forKey:.water);try c.encode(coins,forKey:.coins);try c.encode(ingredients,forKey:.ingredients)
        try c.encode(dishes,forKey:.dishes);try c.encodeIfPresent(order,forKey:.order);try c.encode(sales,forKey:.sales)
        try c.encode(recipes,forKey:.recipes);try c.encode(crafts,forKey:.crafts);try c.encode(economy,forKey:.economy)
    }

}

struct Preferences: Codable {
    var name = "西弗勒斯"
    var hair = 0
    var clothing = 0
    var petVisible = false
    var typingEnabled = false
    var focusMinutes = 25
    var breakMinutes = 5
    var sound = true
    var notifications = false
    var idlePose: Int? = nil
}

struct AppData: Codable {
    var version = 2
    var savedAt = Date()
    var tasks: [GardenTask] = []
    var events: [Appointment] = []
    var habits: [Habit] = []
    var habitProgress: HabitProgress? = nil
    var diaries: [String: Diary] = [:]
    var sessions: [FocusSession] = []
    var keys: [String: Int] = [:]
    var mouseClicks: [String:Int]? = nil
    var timer: TimerRun?
    var pomodoroBreakReady: Bool? = nil
    var garden = Garden()
    var preferences = Preferences()
    var totalFocus: Double { sessions.reduce(0) { $0 + $1.seconds } }

    mutating func finishTimer(at now: Date) -> (seconds: Double, water: Int, rest: Bool)? {
        guard let run = timer else { return nil }
        timer = nil
        let seconds = run.elapsed(at: now)
        pomodoroBreakReady = run.kind == .pomodoro && seconds >= run.target
        guard run.kind != .rest else { return (seconds, 0, true) }
        guard seconds >= 1, !sessions.contains(where: { $0.id == run.id }) else { return (0, 0, false) }
        let before = Int(totalFocus / 300)
        sessions.append(FocusSession(id: run.id, taskID: run.taskID, title: run.taskTitle,
                                     kind: run.kind, date: now, seconds: seconds))
        let water = Int(totalFocus / 300) - before
        garden.water += water
        return (seconds, water, false)
    }

    mutating func plant(_ crop: Crop, in id: UUID) -> Bool {
        guard let i = garden.plots.firstIndex(where: { $0.id == id }),
              garden.plots[i].crop == nil, garden.cropSeeds[crop.rawValue,default:0] > 0, garden.water > 0 else { return false }
        garden.cropSeeds[crop.rawValue,default:0] -= 1
        garden.water -= 1
        garden.plots[i].crop = crop
        garden.plots[i].plantedAt = totalFocus
        garden.plots[i].duration = crop.seconds * (1-Double(garden.rank(.watering))*0.10)
        garden.plots[i].bonus = 0
        return true
    }

    mutating func harvest(_ id: UUID) -> Bool {
        guard let i = garden.plots.firstIndex(where: { $0.id == id }),
              let crop = garden.plots[i].crop, garden.plots[i].progress(totalFocus) >= 1 else { return false }
        garden.ingredients[crop.harvestName, default: 0] += harvestYield * (crop == .starlightCarrot ? 2 : 1)
        garden.plots[i].crop = nil
        return true
    }

    func ingredientCount(_ ingredient:Ingredient) -> Int {
        garden.ingredients[ingredient.rawValue,default:0] + (ingredient.category == .fish ? garden.economy.finds[ingredient.rawValue,default:0] : 0)
    }
    func canCook(_ dish: Dish) -> Bool {
        dish.isValid && dish.ingredients.allSatisfy { key,value in
            Ingredient(rawValue:key).map { ingredientCount($0) >= value } ?? false
        }
    }

    mutating func cook(_ dish: Dish) -> Bool {
        guard dish.isValid, canCook(dish) else { return false }
        var dish=dish
        let baseQuality = dish.quality - dish.kitchenBonus
        dish.quality = min(100, baseQuality + garden.rank(.kitchen)*5)
        dish.kitchenBonus = dish.quality - baseQuality
        for (ingredient, count) in dish.ingredients {
            let stored = min(count,garden.ingredients[ingredient,default:0])
            garden.ingredients[ingredient,default:0] -= stored
            if count > stored { garden.economy.finds[ingredient,default:0] -= count-stored }
        }
        if let output = dish.outputIngredient { garden.ingredients[output.rawValue,default:0] += 1 }
        else { garden.dishes[dish.id, default: 0] += 1 }
        garden.recipes[dish.id] = dish
        garden.crafts[dish.id, default: 0] += 1
        return true
    }

    mutating func stock(_ dish: Dish) -> Bool {
        guard let dish = garden.recipes[dish.id] ?? Dish.allCases.first(where: { $0.id == dish.id }),
              dish.isValid, garden.orders.count < garden.capacity, garden.dishes[dish.rawValue, default: 0] > 0 else { return false }
        garden.dishes[dish.rawValue, default: 0] -= 1
        let order=ShopOrder(dish:dish,placedAt:totalFocus,proceeds:salePrice(dish))
        if garden.order == nil {garden.order=order} else {garden.economy.extraOrders.append(order)}
        return true
    }

    mutating func collectSale(_ id:UUID?=nil) -> Bool {
        guard let order = garden.orders.first(where:{$0.ready(totalFocus) && (id == nil || id == $0.id)}) else { return false }
        garden.coins += order.price
        garden.sales += 1
        if garden.order?.id == order.id {garden.order=nil}
        else {garden.economy.extraOrders.removeAll{$0.id == order.id}}
        return true
    }

    mutating func buySeeds(_ crop:Crop = .carrot) -> Bool {
        guard crop != .starlightCarrot, garden.coins >= 116 else { return false }
        garden.coins -= 116
        garden.cropSeeds[crop.rawValue,default:0] += 3
        return true
    }

    mutating func exchangeSeed(_ crop:Crop = .carrot) -> Bool {
        guard crop != .starlightCarrot, garden.water >= 3 else { return false }
        garden.water -= 3
        garden.cropSeeds[crop.rawValue,default:0] += 1
        return true
    }

    mutating func buyIngredient(_ ingredient: Ingredient, withWater: Bool = false) -> Bool {
        if withWater {
            guard garden.water >= 1 else { return false }
            garden.water -= 1
        } else {
            guard garden.coins >= ingredient.price*29 else { return false }
            garden.coins -= ingredient.price*29
        }
        garden.ingredients[ingredient.rawValue, default: 0] += 1
        return true
    }

    func validated() throws -> AppData {
        func require(_ value: Bool) throws { if !value { throw DataIssue.invalid } }
        func validDate(_ date: Date) -> Bool {
            date.timeIntervalSince1970.isFinite && (Date.distantPast...Date.distantFuture).contains(date)
        }
        try require(version == 1 || version == 2)
        try require(validDate(savedAt))
        try require(tasks.allSatisfy { ($0.due.map(validDate) ?? true) && ($0.completedAt.map(validDate) ?? true) })
        try require(events.allSatisfy { validDate($0.start) && validDate($0.end) })
        try require(sessions.allSatisfy { validDate($0.date) })
        try require(garden.economy.upgrades.allSatisfy { key,value in Upgrade(rawValue:key).map{(0...$0.limit).contains(value)} ?? false })
        try require(Set(tasks.map(\.id)).count == tasks.count)
        try require(Set(events.map(\.id)).count == events.count)
        try require(Set(habits.map(\.id)).count == habits.count)
        try require(Set(sessions.map(\.id)).count == sessions.count)
        try require(Set(garden.plots.map(\.id)).count == garden.plots.count && garden.plots.count == 6+garden.rank(.farmland)*6)
        try require(tasks.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.categoryName.count <= 40 })
        try require(events.allSatisfy { !$0.title.isEmpty && $0.end >= $0.start })
        try require(sessions.allSatisfy { $0.seconds.isFinite && $0.seconds > 0 && $0.kind != .rest })
        try require(totalFocus.isFinite && totalFocus < 1_000_000_000_000)
        try require(keys.values.allSatisfy { (0...1_000_000_000).contains($0) })
        try require((mouseClicks ?? [:]).values.allSatisfy { (0...1_000_000_000).contains($0) })
        try require(diaries.values.allSatisfy { ($0.moodSymbol?.count ?? 0) <= 80 && ($0.moodImage?.count ?? 0) <= 262144 })
        try require(garden.cropSeeds.allSatisfy { Crop(rawValue:$0.key) != nil && (0...1_000_000_000).contains($0.value) })
        try require([garden.seeds, garden.water, garden.sales].allSatisfy { (0...1_000_000_000).contains($0) })
        try require((0...1_000_000_000_000).contains(garden.coins))
        try require(garden.ingredients.keys.allSatisfy { Ingredient(rawValue: $0) != nil })
        try require(garden.dishes.keys.allSatisfy { id in garden.recipes[id] != nil || Dish.allCases.contains { $0.id == id } })
        try require(garden.ingredients.values.allSatisfy { (0...1_000_000_000).contains($0) } && garden.dishes.values.allSatisfy { (0...1_000_000_000).contains($0) })
        try require(habits.allSatisfy { $0.isValid })
        try require(habitProgress?.isValid ?? true)
        try require((0...2).contains(preferences.hair) && (0...2).contains(preferences.clothing))
        try require(preferences.idlePose.map { (0...1).contains($0) } ?? true)
        try require(garden.plots.allSatisfy { $0.plantedAt.isFinite && $0.plantedAt >= 0 && $0.plantedAt <= totalFocus })
        try require(garden.plots.allSatisfy { $0.bonus.isFinite && (0...1_000_000_000).contains($0.bonus) && ($0.duration.map{$0.isFinite && $0>0 && $0<=1500} ?? true) })
        try require((1...180).contains(preferences.focusMinutes) && (1...60).contains(preferences.breakMinutes))
        if let timer {
            try require(validDate(timer.startedAt) && (timer.resumedAt.map(validDate) ?? true))
            try require(timer.resumedAt.map { $0 >= timer.startedAt } ?? true)
            try require(timer.accumulated.isFinite && (0...1_000_000_000_000).contains(timer.accumulated) && timer.target.isFinite && timer.target > 0 && timer.target <= 1_000_000_000_000)
            try require(timer.kind == .stopwatch || timer.accumulated <= timer.target)
            try require(!sessions.contains { $0.id == timer.id })
        }
        try require(garden.recipes.allSatisfy { $0.key == $0.value.id && $0.value.isValid })
        try require(garden.crafts.values.allSatisfy { (0...1_000_000_000).contains($0) })
        try require(garden.orders.count <= garden.capacity && Set(garden.orders.map(\.id)).count == garden.orders.count)
        for order in garden.orders { try require(order.dish.isValid && order.placedAt.isFinite && order.placedAt >= 0 && order.placedAt <= totalFocus && (1...1_000_000).contains(order.price)) }
        let cosmetics=Set(Cosmetic.all.map(\.id))
        try require(garden.economy.owned.isSubset(of:cosmetics))
        try require(["","base"].contains(garden.economy.outfit) || (garden.economy.owned.contains(garden.economy.outfit) && Cosmetic.all.contains{$0.id == garden.economy.outfit && $0.slot == .outfit}))
        try require(garden.economy.hat.isEmpty || (garden.economy.owned.contains(garden.economy.hat) && Cosmetic.all.contains{$0.id == garden.economy.hat && $0.slot == .head}))
        try require((garden.economy.equipped ?? [:]).allSatisfy { key,id in
            guard let slot=ClothingSlot(rawValue:key),slot != .outfit,slot != .head else{return false}
            return garden.economy.owned.contains(id) && Cosmetic.all.contains{$0.id == id && $0.slot == slot}
        })
        try require(garden.economy.worn(.outfit).isEmpty || (garden.economy.worn(.top).isEmpty && garden.economy.worn(.bottom).isEmpty))
        try require((garden.economy.adjustments ?? [:]).allSatisfy { id,value in
            Cosmetic.all.contains { $0.id == id && $0.slot.isAccessory } &&
            (-30...30).contains(value.x) && (-30...30).contains(value.y) && (75...125).contains(value.scale)
        })
        try require(garden.economy.redeemedKeys>=0 && garden.economy.redeemedKeys<=keys.values.reduce(0,+)/1000)
        try require(garden.economy.redeemedActions.map { $0 >= garden.economy.redeemedKeys*1000 && $0 <= totalActions } ?? true)
        try require(garden.economy.finds.allSatisfy{findPrice($0.key)>0 && (0...1_000_000_000).contains($0.value)} && (0...1_000_000_000).contains(garden.economy.expeditions))
        if let trip=garden.economy.journey {
            try require(trip.startedAt.isFinite && trip.startedAt>=0 && trip.startedAt<=totalFocus && trip.duration.isFinite && (300...1200).contains(trip.duration))
            try require(levelProgress.level >= trip.kind.level)
            try require(trip.kind == .potions ? Potion.all.contains{$0.id == trip.recipe} && trip.duration == 900 : trip.recipe == nil)
            try require(trip.kind != .adventure || trip.duration == 1200)
            try require(trip.kind != .fishing || [900.0,780,660,540].contains(trip.duration))
        }
        var result=self;result.version=2;return result
    }
}

enum DataIssue: LocalizedError {
    case invalid, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: return "这份存档的数据不完整或版本不兼容，无法读取。"
        case .tooLarge: return "存档超过 50 MB，请减少图片后再保存。"
        }
    }
}

enum SaveFile {
    static func read(_ url: URL) throws -> AppData {
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count <= 50_000_000 else { throw DataIssue.invalid }
        return try JSONDecoder().decode(AppData.self, from: bytes).validated()
    }
    static func write(_ data: AppData, to url: URL) throws {
        let data = try data.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(data)
        guard bytes.count <= 50_000_000 else { throw DataIssue.tooLarge }
        try bytes.write(to: url, options: .atomic)
    }
}

func clockText(_ seconds: Double) -> String {
    let n = max(0, Int(ceil(seconds)))
    if n >= 3600 { return String(format: "%02d:%02d:%02d", n / 3600, n / 60 % 60, n % 60) }
    return String(format: "%02d:%02d", n / 60, n % 60)
}
