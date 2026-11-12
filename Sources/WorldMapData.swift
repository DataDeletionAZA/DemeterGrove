import CoreGraphics

struct WorldMapActivity: Identifiable {
    let name: String
    let route: String
    var id: String { route }

    init(_ name: String, _ route: String) {
        self.name = name
        self.route = route
    }

    var level: Int? {
        if route == "首页" { return 1 }
        let parts = route.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let id = parts[1]
        switch parts[0] {
        case "钓鱼": return FishingLocation.all.first { $0.id == id }?.level
        case "探险": return ExpeditionLocation.all.first { $0.id == id }?.level
        case "矿洞": return MineLayer.layers(in: String(id)).first?.level
        default: return nil
        }
    }

    func canEnter(level playerLevel: Int) -> Bool {
        level.map { playerLevel >= $0 } ?? false
    }

    var requirement: String { level.map { "等级 \($0)" } ?? "待开放" }
}

struct WorldMapPlace: Identifiable {
    let id: String
    let name: String
    let point: CGPoint
    let activities: [WorldMapActivity]
    var level: Int? { activities.compactMap(\.level).min() }
    func canEnter(level playerLevel: Int) -> Bool { level.map { playerLevel >= $0 } ?? false }
    var requirement: String { level.map { "等级 \($0)" } ?? "待开放" }

    func popupFrame(in size: CGSize) -> CGRect {
        let inset = min(8, size.width / 4, size.height / 4)
        let width = min(208, size.width - 2 * inset)
        let height = min(CGFloat(activities.count) * 44 + 48, size.height - 2 * inset)
        let x = min(max(inset, size.width * point.x - width / 2), size.width - width - inset)
        let y = min(max(inset, size.height * point.y - height - 10), size.height - height - inset)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static let all: [WorldMapPlace] = [
        .init(id:"courtyard",name:"小屋",point:CGPoint(x:0.40,y:0.35),activities:[.init("小屋","首页")]),
        .init(id:"lake",name:"湖畔",point:CGPoint(x:0.52,y:0.53),activities:[.init("湖畔钓鱼","钓鱼/lake")]),
        .init(id:"forest",name:"森林",point:CGPoint(x:0.30,y:0.53),activities:[.init("森林探险","探险/forest")]),
        .init(id:"mountains",name:"群山",point:CGPoint(x:0.76,y:0.22),activities:[
            .init("高山湖钓","钓鱼/mountains"), .init("山地探险","探险/mountains"), .init("群山矿洞","矿洞/群山矿洞")
        ]),
        .init(id:"river",name:"河谷",point:CGPoint(x:0.76,y:0.43),activities:[
            .init("缓流河段","钓鱼/river"), .init("清冷上游","钓鱼/river_cool"), .init("河谷探险","探险/river")
        ]),
        .init(id:"polar",name:"极地",point:CGPoint(x:0.46,y:0.10),activities:[
            .init("冰湖钓鱼","钓鱼/polar"), .init("极地海岸","钓鱼/polar_coast"), .init("极地探险","探险/polar"), .init("极地矿洞","矿洞/极地矿洞")
        ]),
        .init(id:"tropical",name:"雨林",point:CGPoint(x:0.19,y:0.69),activities:[
            .init("雨林钓鱼","钓鱼/tropical"), .init("雨林探险","探险/tropical")
        ]),
        .init(id:"beach",name:"海滩",point:CGPoint(x:0.80,y:0.71),activities:[
            .init("海岸钓鱼","钓鱼/beach"), .init("海岸探险","探险/beach")
        ]),
        .init(id:"sea",name:"远海",point:CGPoint(x:0.91,y:0.88),activities:[
            .init("冷水外海","钓鱼/sea"), .init("暖流远洋","钓鱼/sea_warm")
        ]),
        .init(id:"quarry",name:"旧矿场",point:CGPoint(x:0.54,y:0.36),activities:[.init("旧矿场","矿洞/旧矿场")]),
        .init(id:"volcano",name:"火山",point:CGPoint(x:0.11,y:0.84),activities:[.init("火山矿洞","矿洞/火山矿洞")]),
        .init(id:"reed_marsh",name:"芦苇湿地",point:CGPoint(x:0.39,y:0.69),activities:[
            .init("湿地钓鱼","钓鱼/reed_marsh"), .init("湿地探险","探险/marsh")
        ]),
        .init(id:"reef",name:"珊瑚潟湖",point:CGPoint(x:0.90,y:0.61),activities:[
            .init("潟湖钓鱼","钓鱼/coral_lagoon"), .init("潟湖探险","探险/reef"), .init("潮汐矿窟","矿洞/潮汐矿窟")
        ]),
        .init(id:"highland",name:"云雾高地",point:CGPoint(x:0.64,y:0.16),activities:[
            .init("高地矿洞","矿洞/高地矿洞"), .init("高地钓鱼","钓鱼/mist_highland"), .init("高地探险","探险/highland")
        ]),
        .init(id:"ruins",name:"古塔遗迹",point:CGPoint(x:0.17,y:0.36),activities:[
            .init("遗迹矿井","矿洞/遗迹矿井"), .init("遗迹探险","探险/ruins")
        ]),
        .init(id:"abyss",name:"深海崖岸",point:CGPoint(x:0.94,y:0.40),activities:[.init("深海钓鱼","钓鱼/abyss")])
    ]
}
