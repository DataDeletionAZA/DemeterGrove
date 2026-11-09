import Foundation

struct CraftRoll: Codable, Equatable {
    let natural: Int
    let modifier: Int
    var total: Int { max(0, natural + modifier) }
    var criticalFailure: Bool { natural == 1 }
    var criticalSuccess: Bool { natural == 20 }
    var succeeded: Bool { criticalSuccess || (!criticalFailure && total >= 8) }
    var isValid: Bool { (1...20).contains(natural) && (-6...6).contains(modifier) }
    var quality: Int {
        if criticalFailure { return 0 }
        if criticalSuccess { return 100 }
        switch total {
        case ..<8: return 15
        case ..<12: return 35
        case ..<16: return 55
        case ..<20: return 75
        default: return 95
        }
    }
    var tierTitle: String {
        if criticalFailure { return "大失败" }
        return Self.title(quality: quality)
    }
    static func title(quality: Int) -> String {
        switch quality {
        case ..<25: return "粗劣"
        case ..<45: return "普通"
        case ..<65: return "精良"
        case ..<85: return "卓越"
        case ..<100: return "大师"
        default: return "杰作"
        }
    }
}

struct KitchenResult: Codable, Equatable, Identifiable {
    var id = UUID()
    var recipe: Dish
    var output: Dish?
    var roll: CraftRoll
    var isValid: Bool {
        guard recipe.isValid, recipe.recipeID == nil, roll.isValid else { return false }
        if roll.criticalFailure { return output == nil }
        guard let output else { return false }
        return output.isValid && output.canonicalID == recipe.id && output.quality == roll.quality
            && output.ingredients == recipe.ingredients && output.method == recipe.method
            && output.category == recipe.category && output.sprite == recipe.sprite
    }
}
