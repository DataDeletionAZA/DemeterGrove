import Foundation

enum EconomyBalance {
    static func focusReward(before: Double, after: Double) -> Int {
        max(0, Int(after / 60) - Int(before / 60)) * 2
    }

    static func seedPacketPrice(_ crop: Crop) -> Int {
        let ingredientPrice = Ingredient(rawValue: crop.harvestName)?.purchasePrice ?? 6
        return max(3, (ingredientPrice * 2 + 2) / 3)
    }

    static func ingredientWaterPrice(_ ingredient: Ingredient) -> Int {
        (ingredient.purchasePrice + 5) / 6
    }

    static func seedWaterPrice(crop: Crop) -> Int { (seedPacketPrice(crop) + 5) / 6 }

    static func waterReward(before: Double, after: Double, wateringRank: Int) -> Int {
        max(0, Int(after / 300) - Int(before / 300)) * (1 + min(3, max(0, wateringRank)))
    }

    static func upgradePrice(_ upgrade: Upgrade, rank: Int) -> Int {
        let prices: [Int]
        switch upgrade {
        case .soil: prices = [120, 420, 1080]
        case .watering: prices = [160, 480, 1200]
        case .kitchen: prices = [60, 180, 420]
        case .rod: prices = [30, 60, 100]
        case .wand: prices = [40, 80, 160]
        case .shop: prices = [90, 240, 600]
        case .farmland: prices = [360, 1080]
        case .storefront: prices = [720, 2000]
        }
        return prices[min(max(0, rank), prices.count - 1)]
    }

    static func upgradeLevel(_ upgrade: Upgrade, rank: Int) -> Int {
        let levels: [Int]
        switch upgrade {
        case .soil, .watering, .kitchen: levels = [2, 5, 10]
        case .rod: levels = [5, 10, 15]
        case .wand: levels = [5, 10, 15]
        case .shop: levels = [3, 7, 12]
        case .farmland: levels = [4, 10]
        case .storefront: levels = [5, 15]
        }
        return levels[min(max(0, rank), levels.count - 1)]
    }

    static func salePrice(_ dish: Dish, shopRank: Int) -> Int {
        let ingredients = dish.ingredients.reduce(0) { sum, portion in
            sum + (Ingredient(rawValue: portion.key)?.purchasePrice ?? 6) * portion.value
        }
        return ingredients + 2 + dish.quality / 10 + min(2, max(0, dish.ingredients.count - 1)) + min(3, max(0, shopRank))
    }
}
