import Foundation

enum EconomyBalance {
    static func focusReward(before: Double, after: Double) -> Int {
        max(0, Int(after / 60) - Int(before / 60)) * 2
    }

    static func seedPacketPrice(_ crop: Crop) -> Int {
        (Ingredient(rawValue: crop.harvestName)?.purchasePrice ?? 6) * 3
    }

    static func ingredientWaterPrice(_ ingredient: Ingredient) -> Int {
        (ingredient.purchasePrice + 5) / 6
    }

    static func seedWaterPrice(crop: Crop) -> Int { 1 }

    static func upgradePrice(_ upgrade: Upgrade, rank: Int) -> Int {
        let prices = upgrade == .farmland || upgrade == .storefront ? [240, 1200] : [80, 260, 780]
        return prices[min(max(0, rank), prices.count - 1)]
    }

    static func salePrice(_ dish: Dish, shopRank: Int, kitchenRank: Int) -> Int {
        let ingredients = dish.ingredients.reduce(0) { sum, portion in
            sum + (Ingredient(rawValue: portion.key)?.purchasePrice ?? 6) * portion.value
        }
        return ingredients + 5 + dish.quality / 10 + min(6, max(0, dish.ingredients.count - 1) * 2) + shopRank * 2 + kitchenRank
    }
}
