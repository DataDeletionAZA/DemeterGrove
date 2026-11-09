import Foundation

struct ShopReceipt: Codable, Equatable, Identifiable {
    var dishID: String
    var name: String
    var sprite: Int
    var count: Int
    var amount: Int
    var equipmentSprite:String? = nil
    var id: String { dishID }
}

struct EquipmentShopOrder:Codable,Equatable,Identifiable {
    var id=UUID()
    var gearID:String
    var placedAt:Double
    var price:Int
}

struct AutoShopState: Codable, Equatable {
    static let limit = 1_000_000_000
    static let moneyLimit = 1_000_000_000_000
    var enabled = false
    var dishIDs: [String] = []
    var receivables = 0
    var soldCount = 0
    var lastAdvancedFocus: Double? = nil
    var receipts: [ShopReceipt] = []
    var equipmentOrders:[EquipmentShopOrder]? = nil

    func isValid(in garden: Garden, focus: Double) -> Bool {
        let prepared = Set(garden.menu.filter { $0.outputIngredient == nil && $0.isValid }.map(\.id))
        let equipment=equipmentOrders ?? []
        let expedition=garden.economy.expedition ?? ExpeditionState()
        return equipment.count<=garden.capacity && Set(equipment.map(\.id)).count == equipment.count
            && equipment.allSatisfy{expedition.resolveGear($0.gearID) != nil && $0.placedAt.isFinite && $0.placedAt>=0 && $0.placedAt<=focus && (1...1_000_000).contains($0.price)}
            && Set(dishIDs).count == dishIDs.count && Set(dishIDs).isSubset(of: prepared)
            && (0...Self.moneyLimit).contains(receivables) && (0...Self.limit).contains(soldCount)
            && ((receivables == 0) == (soldCount == 0))
            && Set(receipts.map(\.dishID)).count == receipts.count
            && receipts.allSatisfy { !$0.dishID.isEmpty && $0.dishID.count <= 512 && !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count <= 60
                && ($0.equipmentSprite.map{sprite in CraftedGear.all.contains{$0.spriteKey == sprite} || ForgeMold.all.contains{$0.gearSpriteKey == sprite}} ?? Dish.validSprite($0.sprite)) && (1...Self.limit).contains($0.count) && (1...Self.moneyLimit).contains($0.amount) }
            && receipts.reduce(0, { $0 + $1.amount }) == receivables
            && receipts.reduce(0, { $0 + $1.count }) == soldCount
            && (lastAdvancedFocus.map { $0.isFinite && $0 >= 0 && $0 <= focus } ?? true)
    }
}

extension Garden {
    var autoShopState: AutoShopState { economy.autoShop ?? AutoShopState() }
    var shopOrderCount:Int {orders.count+(autoShopState.equipmentOrders?.count ?? 0)}
}

extension AppData {
    @discardableResult
    mutating func advanceAutoShop(to focus: Double) -> Bool {
        guard focus.isFinite, focus >= 0 else { return false }
        var state = garden.autoShopState
        let previous = state
        let baseline = state.lastAdvancedFocus ?? focus
        guard focus >= baseline else { return false }
        let menu = Dictionary(uniqueKeysWithValues: garden.menu.map { ($0.id, $0) })
        state.dishIDs=state.dishIDs.reduce(into:[]) {ids,id in
            let canonical=menu[id]?.canonicalID ?? id
            if !ids.contains(canonical) {ids.append(canonical)}
        }
        var orders = garden.orders
        var changed = false

        func firstAvailable() -> Dish? {
            guard state.enabled else { return nil }
            for id in state.dishIDs {
                if let dish=menu.values.filter({$0.canonicalID == id && $0.outputIngredient == nil && $0.isValid && garden.dishes[$0.id,default:0]>0})
                    .sorted(by:{$0.quality == $1.quality ? $0.id<$1.id:$0.quality<$1.quality}).first {return dish}
            }
            return nil
        }
        func fill(at time: Double) {
            while orders.count+(state.equipmentOrders?.count ?? 0) < garden.capacity, let dish = firstAvailable() {
                garden.dishes[dish.id, default: 0] -= 1
                orders.append(ShopOrder(dish: dish, placedAt: time, proceeds: salePrice(dish)))
                changed = true
            }
        }
        func credit(dish: Dish, price: Int, count: Int) -> Bool {
            guard count > 0, count <= AutoShopState.limit - state.soldCount,
                  count <= AutoShopState.limit - garden.sales,
                  price > 0, count <= (AutoShopState.moneyLimit - state.receivables) / price else { return false }
            state.receivables += price * count
            state.soldCount += count
            if let index = state.receipts.firstIndex(where: { $0.dishID == dish.id }) {
                state.receipts[index].count += count
                state.receipts[index].amount += price * count
            } else {
                state.receipts.append(ShopReceipt(dishID:dish.id,name:dish.name,sprite:dish.sprite,count:count,amount:price*count))
            }
            garden.sales += count
            changed = true
            return true
        }

        func settleEquipment(at time:Double)->Bool {
            let equipment=state.equipmentOrders ?? []
            var sold=Set<UUID>()
            let expedition=expeditionState
            for order in equipment where order.placedAt+300<=time {
                guard let gear=expedition.resolveGear(order.gearID),
                      state.soldCount<AutoShopState.limit,garden.sales<AutoShopState.limit,
                      order.price<=AutoShopState.moneyLimit-state.receivables else{continue}
                state.receivables+=order.price;state.soldCount+=1;garden.sales+=1
                let receiptID="gear:"+gear.id
                if let index=state.receipts.firstIndex(where:{$0.dishID == receiptID}) {
                    state.receipts[index].count+=1;state.receipts[index].amount+=order.price
                } else {state.receipts.append(ShopReceipt(dishID:receiptID,name:gear.name,sprite:0,count:1,amount:order.price,equipmentSprite:gear.spriteKey))}
                sold.insert(order.id);changed=true
            }
            if !sold.isEmpty {state.equipmentOrders=equipment.filter{!sold.contains($0.id)}}
            return !sold.isEmpty
        }

        while let earliest = (orders.map({ max(baseline, $0.placedAt + 300) })+(state.equipmentOrders ?? []).map({max(baseline,$0.placedAt+300)})).min(), earliest <= focus {
            let ready = orders.filter { $0.placedAt + 300 <= earliest }
            var settled = Set<UUID>()
            for order in ready where credit(dish:order.dish,price:order.price,count:1) { settled.insert(order.id) }
            let equipmentSettled=settleEquipment(at:earliest)
            guard !settled.isEmpty || equipmentSettled else { break }
            orders.removeAll { settled.contains($0.id) }
            fill(at: earliest)

            // Whole shelf cycles preserve staggered deadlines while bounding long catch-up work by recipe count.
            if (state.equipmentOrders ?? []).isEmpty, let dish = firstAvailable(), !orders.isEmpty,
               orders.allSatisfy({ $0.dish.id == dish.id && $0.price == salePrice(dish) }),
               let latest = orders.map(\.placedAt).max() {
                let count = orders.count, price = salePrice(dish)
                let cycles = min(Int(max(0, (focus - latest) / 300)),
                    garden.dishes[dish.id, default: 0] / count,
                    (AutoShopState.limit - state.soldCount) / count,
                    (AutoShopState.limit - garden.sales) / count,
                    (AutoShopState.moneyLimit - state.receivables) / price / count)
                if cycles > 0, credit(dish:dish,price:price,count:cycles*count) {
                    garden.dishes[dish.id, default: 0] -= cycles * count
                    for index in orders.indices { orders[index].placedAt += Double(cycles) * 300 }
                }
            }
        }
        fill(at: focus)
        state.lastAdvancedFocus = focus
        garden.order = orders.first
        garden.economy.extraOrders = Array(orders.dropFirst())
        garden.economy.autoShop = state
        return changed || state != previous
    }

    @discardableResult
    mutating func setAutoShop(enabled: Bool, at date: Date = Date()) -> Bool {
        let focus = gameFocus(at: date)
        advanceAutoShop(to: focus)
        var state = garden.autoShopState
        guard state.enabled != enabled else { return false }
        state.enabled = enabled
        garden.economy.autoShop = state
        advanceAutoShop(to: focus)
        return true
    }

    @discardableResult
    mutating func toggleAutoShopDish(_ id: String, at date: Date = Date()) -> Bool {
        advanceAutoShop(to: gameFocus(at: date))
        var state = garden.autoShopState
        guard let dish=garden.menu.first(where:{$0.id == id && $0.isValid && $0.outputIngredient == nil}) else{return false}
        let canonical=dish.canonicalID
        if let index = state.dishIDs.firstIndex(of: canonical) { state.dishIDs.remove(at: index) }
        else {
            guard garden.menu.contains(where:{$0.canonicalID == canonical && garden.dishes[$0.id,default:0]>0}) else{return false}
            state.dishIDs.append(canonical)
        }
        garden.economy.autoShop = state
        advanceAutoShop(to: gameFocus(at: date))
        return true
    }

    @discardableResult
    mutating func collectShopProceeds(at date: Date = Date()) -> Int {
        advanceAutoShop(to: gameFocus(at: date))
        var state = garden.autoShopState
        let amount = state.receivables
        guard amount > 0, amount <= AutoShopState.moneyLimit - garden.coins else { return 0 }
        garden.coins += amount
        state.receivables = 0
        state.soldCount = 0
        state.receipts = []
        garden.economy.autoShop = state
        return amount
    }

    mutating func stockEquipment(_ id:String,at date:Date=Date())->Bool {
        let focus=gameFocus(at:date)
        advanceAutoShop(to:focus)
        var expedition=expeditionState
        guard let gear=expedition.resolveGear(id),garden.shopOrderCount<garden.capacity,
              expedition.gear[id,default:0]>expedition.wornCount(id) else{return false}
        var shop=garden.autoShopState
        expedition.gear[id,default:0]-=1
        shop.equipmentOrders=(shop.equipmentOrders ?? [])+[EquipmentShopOrder(gearID:id,placedAt:focus,price:gear.salePrice)]
        garden.economy.expedition=expedition;garden.economy.autoShop=shop
        return true
    }
    mutating func unstockEquipment(_ id:UUID,at date:Date=Date())->Bool {
        advanceAutoShop(to:gameFocus(at:date))
        var shop=garden.autoShopState
        guard let order=shop.equipmentOrders?.first(where:{$0.id == id}) else{return false}
        var expedition=expeditionState
        guard expedition.gear[order.gearID,default:0]<AutoShopState.limit else{return false}
        expedition.gear[order.gearID,default:0]+=1
        shop.equipmentOrders?.removeAll{$0.id == id}
        garden.economy.expedition=expedition;garden.economy.autoShop=shop
        return true
    }

    @discardableResult
    mutating func stockAllAvailable(at date: Date = Date()) -> Int {
        advanceAutoShop(to: gameFocus(at: date))
        var count = 0
        for dish in garden.menu where dish.outputIngredient == nil {
            while garden.shopOrderCount < garden.capacity && stock(dish, at: date) { count += 1 }
        }
        return count
    }

    @discardableResult
    mutating func stopRestockingAndUnstock(_ id: UUID, at date: Date = Date()) -> Bool {
        advanceAutoShop(to: gameFocus(at: date))
        guard let order = garden.orders.first(where: { $0.id == id }), unstock(id, at: date) else { return false }
        var state = garden.autoShopState
        state.dishIDs.removeAll { $0 == order.dish.canonicalID }
        garden.economy.autoShop = state
        return true
    }
}
