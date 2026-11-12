import AppKit
import SwiftUI

@main
struct ThemeIconChecks {
    @MainActor static func main() {
        let themes: [AppTheme] = [.y2k, .liquidGlass, .christmas]
        let controls = ["check", "close", "down", "calendar", "药瓶", "主题", "外观", "四象限", "渔具店",
                        "任务", "计时器", "日程", "习惯", "日记", "成长", "小屋", "后院", "户外地图", "衣柜",
                        "统计", "设置", "菜单", "动物商店", "库存", "种子柜", "配方册", "上次制作", "上次结果",
                        "出发探险", "采买", "通用", "桌宠", "AI 服务", "专注与提醒", "表达与提示词", "存档",
                        "金加隆", "银西可", "铜纳特"]
        let locations = SceneNavigation.rooms + SceneNavigation.wilds + FishingLocation.all.map(\.name) + ExpeditionLocation.all.map(\.name)
        let equipment = CookingMethod.allCases.map(\.rawValue) + Upgrade.allCases.map(\.name)
        for name in controls + locations + equipment {
            precondition(ThemeIcon.designs[name] != nil, "Missing theme icon for \(name)")
        }
        precondition(ThemeIcon.design(for: "钓鱼/lake") == ThemeIcon.design(for: "钓鱼"))
        precondition(ThemeIcon.design(for: "日程") == ThemeIcon.design(for: "calendar"))

        for (name, design) in ThemeIcon.designs {
            for theme in themes {
                let symbol = design.symbol(for: theme)
                precondition(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil,
                             "Unavailable \(theme.name) symbol \(symbol) for \(name)")
            }
        }
        for theme in themes {
            precondition(ThemeIcon.design(for: "circle").symbol(for: theme) == "circle")
        }

        for (name, size) in [("check", 12.0), ("close", 16.0), ("农场", 23.0), ("日程", 32.0), ("种子柜", 32.0), ("衣柜", 48.0)] {
            let renderings = themes.map { theme in
                let view = ThemeIcon(name: name, size: size, theme: theme)
                    .environment(\.colorScheme, .light)
                let renderer = ImageRenderer(content: view)
                guard let image = renderer.nsImage,
                      let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else {
                    preconditionFailure("Unable to render \(theme.name) icon \(name)")
                }
                precondition(image.size == CGSize(width: size, height: size), "Unexpected size for \(name)")
                let solidPixels = (0..<bitmap.pixelsHigh).reduce(0) { count, y in
                    count + (0..<bitmap.pixelsWide).filter { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 }.count
                }
                precondition(solidPixels > 0 && Double(solidPixels) / Double(bitmap.pixelsWide * bitmap.pixelsHigh) < 0.5,
                             "Unexpected coverage for \(theme.name) icon \(name)")
                return data
            }
            precondition(Set(renderings).count == themes.count, "Theme artwork matches for \(name)")
        }
        print("Theme icon checks passed (\(ThemeIcon.designs.count) names)")
    }
}
