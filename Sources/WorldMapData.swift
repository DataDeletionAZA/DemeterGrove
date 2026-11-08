import Foundation

struct WorldMapPlace: Identifiable {
    var id: String
    var name: String
    var point: CGPoint
    var level: Int
    var route: String? = nil
    func canEnter(level: Int) -> Bool { route != nil && level >= self.level }
    var requirement: String { route == nil ? "等级 \(level) · 待开放" : "等级 \(level)" }
    static let all: [WorldMapPlace] = [
        .init(id:"courtyard",name:"小院",point:CGPoint(x:0.40,y:0.35),level:1,route:"首页"),
        .init(id:"lake",name:"湖畔",point:CGPoint(x:0.52,y:0.53),level:3,route:"湖畔钓鱼"),
        .init(id:"forest",name:"森林",point:CGPoint(x:0.30,y:0.53),level:5,route:"林间冒险"),
        .init(id:"mountains",name:"群山",point:CGPoint(x:0.76,y:0.22),level:12,route:"探险/mountains"),
        .init(id:"river",name:"河谷",point:CGPoint(x:0.76,y:0.43),level:10,route:"钓鱼/river"),
        .init(id:"polar",name:"极地",point:CGPoint(x:0.46,y:0.10),level:25,route:"探险/polar"),
        .init(id:"tropical",name:"雨林",point:CGPoint(x:0.19,y:0.69),level:18,route:"探险/tropical"),
        .init(id:"beach",name:"海滩",point:CGPoint(x:0.80,y:0.71),level:15,route:"钓鱼/beach"),
        .init(id:"sea",name:"远海",point:CGPoint(x:0.91,y:0.88),level:20,route:"钓鱼/sea"),
        .init(id:"quarry",name:"旧矿场",point:CGPoint(x:0.54,y:0.36),level:3,route:"矿洞/旧矿场"),
        .init(id:"volcano",name:"火山",point:CGPoint(x:0.11,y:0.84),level:20,route:"矿洞/火山矿洞")
    ]
    var activities:[(String,String)] {
        switch id {
        case "mountains":return [("高山湖钓","钓鱼/mountains"),("山地探险","探险/mountains"),("群山矿洞","矿洞/群山矿洞")]
        case "river":return [("缓流河段","钓鱼/river"),("清冷上游","钓鱼/river_cool"),("河谷探险","探险/river")]
        case "polar":return [("冰湖钓鱼","钓鱼/polar"),("极地海岸","钓鱼/polar_coast"),("极地探险","探险/polar"),("极地矿洞","矿洞/极地矿洞")]
        case "tropical":return [("雨林钓鱼","钓鱼/tropical"),("雨林探险","探险/tropical")]
        case "sea":return [("冷水外海","钓鱼/sea"),("暖流远洋","钓鱼/sea_warm")]
        case "beach":return [("海岸钓鱼","钓鱼/beach"),("海岸探险","探险/beach")]
        default:return route.map{[(name,$0)]} ?? []
        }
    }
}
