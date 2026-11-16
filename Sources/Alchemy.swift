import Foundation

enum AlchemyHeat: Int, Codable, CaseIterable, Identifiable {
    case gentle, medium, strong
    var id: Int { rawValue }
    var name: String { ["小火","中火","大火"][rawValue] }
}

enum AlchemyTrait: String, Codable, CaseIterable {
    case moisture, growth, germination, nutrition, binding
    var name: String {
        switch self {
        case .moisture:return "清润"
        case .growth:return "促生"
        case .germination:return "催芽"
        case .nutrition:return "滋养"
        case .binding:return "凝合"
        }
    }
    var weights: [AlchemyEffect:Int] {
        switch self {
        case .moisture:return [.dew:5,.growth:1]
        case .growth:return [.growth:5,.seeds:1]
        case .germination:return [.seeds:5,.growth:1]
        case .nutrition:return [.feed:5,.seeds:1]
        case .binding:return [.dew:1,.feed:1]
        }
    }
}

enum AlchemyEffect: String, Codable, CaseIterable {
    case dew, seeds, growth, feed
    var name: String {
        switch self {case .dew:return "露水";case .seeds:return "催芽";case .growth:return "促生";case .feed:return "饲育"}
    }
    func amount(quality:Int)->Int {
        switch self {
        case .dew:return max(1,(quality+14)/15)
        case .seeds:return quality >= 65 ? 2:1
        case .growth:return max(1,(quality+19)/20)*60
        case .feed:return quality >= 80 ? 2:1
        }
    }
    func text(quality:Int)->String {
        let n=amount(quality:quality)
        switch self {
        case .dew:return "获得 \(n) 滴露水"
        case .seeds:return "胡萝卜、小麦、番茄种子各 \(n) 袋"
        case .growth:return "已种作物增加 \(n/60) 分钟生长进度"
        case .feed:return "获得 \(n) 袋牧场饲料"
        }
    }
}

struct AlchemyMaterial: Codable, Equatable, Hashable, Identifiable {
    var name:String
    var kind:PotionSelection.Kind
    var id:String {kind.rawValue+":"+(kind == .material ? Potion.materialName(name):name)}
    var profile:AlchemyProfile? {AlchemyProfile.find(self)}
}

struct AlchemyProfile {
    var traits:[AlchemyTrait]
    var heat:AlchemyHeat
    var minutes:Int
    var suitability:Int
    var price:Int

    static func find(_ material:AlchemyMaterial)->AlchemyProfile? {
        if material.kind == .ingredient {
            guard let item=Ingredient(rawValue:material.name) else{return nil}
            let traits:[AlchemyTrait], heat:AlchemyHeat, minutes:Int, suitability:Int
            switch item {
            case .mint,.tea,.roastedTea:
                traits=[.moisture,.growth];heat = .gentle;minutes=8;suitability=88
            case .pumpkin,.moonbean,.moonbeanPaste,.pea,.hazelnut:
                traits=[.germination,.nutrition];heat = .medium;minutes=14;suitability=84
            case .strawberry,.shrivelfig,.dirigiblePlum,.sunroot:
                traits=[.growth,.germination];heat = .medium;minutes=12;suitability=90
            case .honey,.sugar,.beetSugar,.vanilla:
                traits=[.binding,.moisture];heat = .gentle;minutes=7;suitability=80
            case .lemon,.rosehip,.lingonberry:
                traits=[.moisture,.binding,.growth];heat = .gentle;minutes=8;suitability=76
            case .mushroom,.spinach,.cabbage:
                traits=[.growth,.nutrition];heat = .medium;minutes=12;suitability=78
            case .coffee,.cocoa,.onion:
                traits=[.growth,.binding];heat = .strong;minutes=13;suitability=65
            default:
                switch item.category {
                case .farm:traits=[.moisture,.nutrition];heat = .medium;minutes=10;suitability=70
                case .fish:traits=[.nutrition,.binding];heat = .strong;minutes=18;suitability=38
                case .dairy:traits=[.nutrition,.moisture];heat = .gentle;minutes=9;suitability=55
                case .grain:traits=[.binding,.germination];heat = .medium;minutes=15;suitability=48
                case .seasoning:traits=[.binding];heat = .gentle;minutes=8;suitability=60
                }
            }
            return .init(traits:traits,heat:heat,minutes:minutes,suitability:suitability,price:item.purchasePrice)
        }
        let canonical=Potion.materialName(material.name)
        guard let item=NatureCatalog.forage.first(where:{$0.name == canonical || $0.id == canonical}) else{return nil}
        let traits:[AlchemyTrait], heat:AlchemyHeat, minutes:Int
        switch item.id {
        case "moon_herb":traits=[.moisture,.growth];heat = .gentle;minutes=13
        case "amber":traits=[.germination,.binding];heat = .medium;minutes=16
        case "star_sand":traits=[.growth,.moisture,.binding];heat = .medium;minutes=14
        default:
            if let food=item.ingredient,let profile=find(.init(name:food,kind:.ingredient)) {
                return .init(traits:profile.traits,heat:profile.heat,minutes:profile.minutes+2,suitability:profile.suitability,price:item.salePrice)
            }
            switch item.origin {
            case .real:traits=[.binding,.nutrition];heat = .medium;minutes=15
            case .harryPotter:traits=[.growth,.germination,.binding];heat = .strong;minutes=18
            case .original:traits=[.moisture,.growth];heat = .gentle;minutes=15
            }
        }
        return .init(traits:traits,heat:heat,minutes:minutes,suitability:item.origin == .real ? 66:88,price:item.salePrice)
    }
}

struct AlchemyFormula: Codable, Equatable, Identifiable {
    var name:String
    var materials:[AlchemyMaterial]
    var heat:AlchemyHeat
    var minutes:Int
    var id:String {materials.map(\.id).sorted().joined(separator:"|")+"|\(heat.rawValue)|\(minutes)"}
    var isValid:Bool {
        (1...5).contains(materials.count) && Set(materials.map(\.id)).count == materials.count &&
        materials.allSatisfy{$0.profile != nil} && (1...1440).contains(minutes) && !name.isEmpty && name.count <= 80
    }
    static let catalog:[AlchemyFormula] = [
        .init(name:"薄荷浸液",materials:[.init(name:"薄荷",kind:.ingredient)],heat:.gentle,minutes:8),
        .init(name:"南瓜药剂",materials:[.init(name:"南瓜",kind:.ingredient)],heat:.medium,minutes:14),
        .init(name:"丰沛露水",materials:[.init(name:"薄荷",kind:.ingredient),.init(name:"月光草",kind:.material)],heat:.gentle,minutes:15),
        .init(name:"萌芽药剂",materials:[.init(name:"南瓜",kind:.ingredient),.init(name:"琥珀石",kind:.material)],heat:.medium,minutes:18),
        .init(name:"繁盛药剂",materials:[.init(name:"草莓",kind:.ingredient),.init(name:"星砂",kind:.material)],heat:.medium,minutes:16),
        .init(name:"蜂蜜调合剂",materials:[.init(name:"蜂蜜",kind:.ingredient),.init(name:"牛奶",kind:.ingredient)],heat:.gentle,minutes:11)
    ]
    var purchasePrice:Int {20+materials.count*10}
}

struct AlchemyAssessment {
    var idealMinutes:Int
    var compatibility:Int
    var timingPenalty:Int
    var heatPenalty:Int
    var successChance:Int
    var qualityBase:Int
    var weights:[AlchemyEffect:Int]
    init(materials:[AlchemyMaterial],heat:AlchemyHeat,minutes:Int) {
        let profiles=materials.compactMap(\.profile)
        guard !profiles.isEmpty else {
            idealMinutes=1;compatibility=0;timingPenalty=100;heatPenalty=100;successChance=0;qualityBase=0;weights=[:];return
        }
        idealMinutes=(profiles.map(\.minutes).max() ?? 1)+max(0,profiles.count-1)*2
        let ratio=Double(minutes)/Double(idealMinutes)
        timingPenalty=ratio<1 ? Int((1-ratio)*65):Int(max(0,ratio-1.2)*32)
        heatPenalty=profiles.reduce(0){$0+abs($1.heat.rawValue-heat.rawValue)*18}/profiles.count
        var clashes=0,pairs=0
        for i in profiles.indices {
            for j in profiles.indices where j>i {
                pairs+=1
                if Set(profiles[i].traits).isDisjoint(with:profiles[j].traits) {clashes+=1}
            }
        }
        compatibility=max(0,profiles.reduce(0){$0+$1.suitability}/profiles.count-(pairs == 0 ? 0:clashes*24/pairs))
        qualityBase=max(5,min(95,compatibility-timingPenalty-heatPenalty))
        successChance=max(8,min(98,qualityBase+8))
        weights=[:]
        for profile in profiles {
            for trait in profile.traits {
                for (effect,weight) in trait.weights {
                    weights[effect,default:0]+=max(1,weight*(100-abs(profile.heat.rawValue-heat.rawValue)*20)/100)
                }
            }
        }
    }
}

struct AlchemyOutcome: Codable, Equatable {
    var quality:Int
    var effects:[AlchemyEffect]
    var succeeded:Bool {quality>0}
    var name:String {effects.first.map{$0.name+"药剂"} ?? "熬制失败"}
    var isValid:Bool {
        (0...100).contains(quality) && (succeeded ? (1...3).contains(effects.count):effects.isEmpty) &&
        Set(effects).count == effects.count
    }
    static func roll(assessment:AlchemyAssessment,seed:UInt64)->AlchemyOutcome {
        var state=seed
        func next(_ upper:Int)->Int {
            state=state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state>>32)%UInt64(max(1,upper)))
        }
        guard next(100)<assessment.successChance else{return .init(quality:0,effects:[])}
        let quality=max(1,min(100,assessment.qualityBase+next(17)-8))
        let count=quality>=75 ? 3:quality>=45 ? 2:1
        var pool=AlchemyEffect.allCases.filter{assessment.weights[$0,default:0]>0}
        var effects:[AlchemyEffect]=[]
        for _ in 0..<min(count,pool.count) {
            var pick=next(pool.reduce(0){$0+assessment.weights[$1,default:0]})
            for index in pool.indices {
                pick-=assessment.weights[pool[index],default:0]
                if pick<0 {effects.append(pool.remove(at:index));break}
            }
        }
        return .init(quality:quality,effects:effects)
    }
}

struct AlchemyBrew: Codable, Equatable, Identifiable {
    var id=UUID()
    var formula:AlchemyFormula
    var startedFocus:Double
    var outcome:AlchemyOutcome
    var price:Int
    var duration:Double {Double(formula.minutes)*60}
    func progress(_ focus:Double)->Double {min(1,max(0,(focus-startedFocus)/duration))}
}

struct AlchemyBatch: Codable, Equatable, Identifiable {
    var id=UUID()
    var name:String
    var formula:AlchemyFormula
    var outcome:AlchemyOutcome
    var price:Int
    var count=1
}

struct AlchemyState: Codable, Equatable {
    var known:Set<String>=[]
    var notebook:[AlchemyFormula]=[]
    var batches:[AlchemyBatch]=[]
    var active:AlchemyBrew?
    var lastResult:AlchemyBrew?
    func isValid(focus:Double)->Bool {
        func brewValid(_ brew:AlchemyBrew)->Bool {
            brew.formula.isValid && brew.outcome.isValid && brew.startedFocus.isFinite &&
            brew.startedFocus>=0 && brew.startedFocus<=focus && (1...10000).contains(brew.price)
        }
        return known.isSubset(of:Set(AlchemyFormula.catalog.map(\.id))) &&
            notebook.count<=10000 && Set(notebook.map(\.id)).count == notebook.count && notebook.allSatisfy(\.isValid) &&
            batches.count<=10000 && Set(batches.map(\.id)).count == batches.count &&
            batches.allSatisfy{!$0.name.isEmpty && $0.name.count<=80 && $0.formula.isValid && $0.outcome.isValid && $0.outcome.succeeded && (1...10000).contains($0.price) && (1...1_000_000_000).contains($0.count)} &&
            (active.map(brewValid) ?? true) && (lastResult.map{brewValid($0) && $0.progress(focus)>=1} ?? true)
    }
}

extension AppData {
    var alchemyState:AlchemyState {garden.economy.alchemy ?? AlchemyState()}
    var knownAlchemyFormulas:[AlchemyFormula] {
        let state=alchemyState
        return AlchemyFormula.catalog.filter{state.known.contains($0.id)} +
            state.notebook.filter{formula in !AlchemyFormula.catalog.contains{$0.id == formula.id}}
    }
    func alchemyCount(_ material:AlchemyMaterial)->Int {
        material.kind == .ingredient ? Ingredient(rawValue:material.name).map{ingredientCount($0)} ?? 0:potionMaterialCount(material.name)
    }
    mutating func buyAlchemyFormula(_ id:String)->Bool {
        guard let formula=AlchemyFormula.catalog.first(where:{$0.id == id}),levelProgress.level>=JourneyKind.potions.level,
              !alchemyState.known.contains(id),garden.coins>=formula.purchasePrice else{return false}
        var state=alchemyState
        state.known.insert(id);garden.coins-=formula.purchasePrice;garden.economy.alchemy=state
        return true
    }
    mutating func startAlchemy(materials:[AlchemyMaterial],heat:AlchemyHeat,minutes:Int,seed:UInt64=UInt64.random(in:0...UInt64.max),at date:Date=Date())->Bool {
        let formula=AlchemyFormula(name:"自选配方",materials:materials,heat:heat,minutes:minutes)
        guard formula.isValid,levelProgress.level>=JourneyKind.potions.level,
              alchemyState.active == nil,garden.economy.trip(.potions) == nil,
              alchemyState.batches.count<10000,alchemyState.notebook.count<10000,
              materials.allSatisfy({alchemyCount($0)>0}) else{return false}
        var next=self
        for material in materials {
            if material.kind == .ingredient {
                if next.garden.ingredients[material.name,default:0]>0 {next.garden.ingredients[material.name,default:0]-=1}
                else {next.garden.economy.finds[material.name,default:0]-=1}
            }
            else if !next.consumePotionMaterial(material.name) {return false}
        }
        let assessment=AlchemyAssessment(materials:materials,heat:heat,minutes:minutes)
        let outcome=AlchemyOutcome.roll(assessment:assessment,seed:seed)
        let cost=materials.compactMap(\.profile).reduce(0){$0+$1.price}
        let price=max(1,Int((Double(cost)*0.65+Double(assessment.idealMinutes)*0.3)*Double(outcome.quality)/100))
        var state=alchemyState
        state.active=AlchemyBrew(formula:formula,startedFocus:gameFocus(at:date),outcome:outcome,price:price)
        next.garden.economy.alchemy=state;self=next
        return true
    }
    @discardableResult mutating func collectAlchemy(at date:Date=Date())->Bool {
        var state=alchemyState
        guard let brew=state.active,brew.progress(gameFocus(at:date))>=1 else{return false}
        if brew.outcome.succeeded {
            var formula=brew.formula
            formula.name=AlchemyFormula.catalog.first{$0.id == formula.id}?.name ?? brew.outcome.name
            if let canonical=AlchemyFormula.catalog.first(where:{$0.id == formula.id}) {state.known.insert(canonical.id)}
            if !state.notebook.contains(where:{$0.id == formula.id}) {state.notebook.append(formula)}
            if let index=state.batches.firstIndex(where:{$0.formula.id == formula.id && $0.outcome == brew.outcome && $0.price == brew.price}) {
                guard state.batches[index].count<1_000_000_000 else{return false}
                state.batches[index].count+=1
            } else {
                state.batches.append(AlchemyBatch(name:formula.name,formula:formula,outcome:brew.outcome,price:brew.price))
            }
        }
        state.lastResult=brew;state.active=nil;garden.economy.alchemy=state
        return true
    }
    mutating func sellAlchemy(_ id:UUID)->Bool {
        var state=alchemyState
        guard let index=state.batches.firstIndex(where:{$0.id == id}),state.batches[index].count>0,
              garden.coins<=1_000_000_000_000-state.batches[index].price else{return false}
        garden.coins+=state.batches[index].price;state.batches[index].count-=1
        state.batches.removeAll{$0.count == 0};garden.economy.alchemy=state
        return true
    }
    mutating func useAlchemy(_ id:UUID)->Bool {
        var state=alchemyState
        guard let index=state.batches.firstIndex(where:{$0.id == id}),state.batches[index].count>0 else{return false}
        let outcome=state.batches[index].outcome
        var next=self
        for effect in outcome.effects {
            let amount=effect.amount(quality:outcome.quality)
            switch effect {
            case .dew:
                guard next.garden.water<=1_000_000_000-amount else{return false}
                next.garden.water+=amount
            case .seeds:
                for crop in [Crop.carrot,.wheat,.tomato] {
                    guard next.garden.cropSeeds[crop.rawValue,default:0]<=1_000_000_000-amount else{return false}
                    next.garden.cropSeeds[crop.rawValue,default:0]+=amount
                }
            case .growth:
                guard next.garden.plots.contains(where:{$0.crop != nil}),next.garden.plots.filter({$0.crop != nil}).allSatisfy({$0.bonus<=1_000_000_000-Double(amount)}) else{return false}
                for i in next.garden.plots.indices where next.garden.plots[i].crop != nil {next.garden.plots[i].bonus+=Double(amount)}
            case .feed:
                var ranch=next.ranchState
                guard ranch.feedBags<=1_000_000-amount else{return false}
                ranch.feedBags+=amount;next.garden.economy.ranch=ranch
            }
        }
        state.batches[index].count-=1;state.batches.removeAll{$0.count == 0}
        next.garden.economy.alchemy=state;self=next
        return true
    }
}
