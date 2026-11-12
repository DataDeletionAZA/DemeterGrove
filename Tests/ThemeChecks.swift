import Foundation

@main
struct ThemeChecks {
    static func main() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var oldData = AppData()
        oldData.garden.coins = 135
        oldData.garden.economy.owned = ["travel"]
        oldData.garden.economy.outfit = "travel"
        oldData.preferences.petSkin = PetSkin.original.rawValue
        let oldSave = try encoder.encode(oldData)
        let oldJSON = String(decoding: oldSave, as: UTF8.self)
        precondition(!oldJSON.contains("\"ownedThemes\"") && !oldJSON.contains("\"selectedTheme\""))
        var loaded = try decoder.decode(AppData.self, from: oldSave).validated(at: date)
        precondition(loaded.garden.coins == 135 && loaded.garden.economy.worn(.outfit) == "travel")
        precondition(loaded.preferences.selectedPetSkin == .original)
        precondition(loaded.activeTheme == .original && loaded.ownsTheme(.original))
        precondition(!loaded.buyTheme(.original) && loaded.garden.coins == 135)

        for theme in AppTheme.allCases where theme != .original {
            var data = AppData()
            let minutes = (1..<theme.level).reduce(0) { $0 + LevelProgress.requirement($1) }
            let unlockSeconds = Double(minutes * 60)
            data.sessions = [FocusSession(id: UUID(), title: "专注", kind: .stopwatch, date: date, seconds: unlockSeconds - 1)]
            data.garden.coins = theme.price
            precondition(!data.buyTheme(theme) && !data.selectTheme(theme))
            precondition(!data.ownsTheme(theme) && data.garden.coins == theme.price && data.activeTheme == .original)

            data.sessions[0].seconds = unlockSeconds
            data.garden.coins -= 1
            precondition(!data.buyTheme(theme) && data.garden.coins == theme.price - 1)
            data.garden.coins += 1
            precondition(data.buyTheme(theme) && data.ownsTheme(theme) && data.garden.coins == 0)
            precondition(data.activeTheme == .original)

            data.garden.coins = theme.price
            precondition(!data.buyTheme(theme) && data.garden.coins == theme.price)
            precondition(data.selectTheme(theme) && data.activeTheme == theme && !data.selectTheme(theme))
            let save = try encoder.encode(data)
            loaded = try decoder.decode(AppData.self, from: save).validated(at: date)
            precondition(loaded.activeTheme == theme && loaded.ownsTheme(theme) && loaded.garden.coins == theme.price)
            precondition(loaded.selectTheme(.original) && loaded.activeTheme == .original && loaded.ownsTheme(theme))

            data.garden.economy.ownedThemes = nil
            precondition(data.activeTheme == .original)
            do {
                _ = try data.validated(at: date)
                preconditionFailure("Accepted an unowned selected theme")
            } catch DataIssue.invalid { }
        }
        print("Theme checks passed")
    }
}
