import Foundation

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case original, y2k, liquidGlass, christmas

    var id: String { rawValue }

    var name: String {
        switch self {
        case .original: return "原版"
        case .y2k: return "Y2K"
        case .liquidGlass: return "液态玻璃"
        case .christmas: return "圣诞"
        }
    }

    var level: Int {
        switch self {
        case .original: return 1
        case .y2k: return 5
        case .liquidGlass: return 8
        case .christmas: return 12
        }
    }

    var price: Int {
        switch self {
        case .original: return 0
        case .y2k: return 8 * Money.sickle
        case .liquidGlass: return Money.galleon
        case .christmas: return 2 * Money.galleon
        }
    }
}

extension AppData {
    var activeTheme: AppTheme {
        guard let theme = preferences.selectedTheme, ownsTheme(theme) else { return .original }
        return theme
    }

    func ownsTheme(_ theme: AppTheme) -> Bool {
        theme == .original || garden.economy.ownedThemes?.contains(theme) == true
    }

    mutating func buyTheme(_ theme: AppTheme) -> Bool {
        guard !ownsTheme(theme), garden.coins >= theme.price, levelProgress.level >= theme.level else { return false }
        garden.coins -= theme.price
        var ownedThemes = garden.economy.ownedThemes ?? []
        ownedThemes.insert(theme)
        garden.economy.ownedThemes = ownedThemes
        return true
    }

    mutating func selectTheme(_ theme: AppTheme) -> Bool {
        guard ownsTheme(theme), activeTheme != theme else { return false }
        preferences.selectedTheme = theme == .original ? nil : theme
        return true
    }
}
