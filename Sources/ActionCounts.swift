import Foundation

func compactActionCount(_ count: Int) -> String {
    let count = max(0,count)
    guard count >= 100_000 else { return String(count) }
    let divisor = count >= 100_000_000 ? 100_000_000 : 10_000
    let whole = count / divisor, decimal = (count % divisor) * 10 / divisor
    return String(whole) + (decimal == 0 ? "" : ".\(decimal)") + (divisor == 10_000 ? "万" : "亿")
}

extension AppData {
    var availableActions: Int { max(0,totalActions-consumedActions) }
}
