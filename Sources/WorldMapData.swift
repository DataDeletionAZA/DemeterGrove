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
        .init(id:"mountains",name:"群山",point:CGPoint(x:0.76,y:0.22),level:12),
        .init(id:"river",name:"河谷",point:CGPoint(x:0.76,y:0.43),level:10),
        .init(id:"polar",name:"极地",point:CGPoint(x:0.46,y:0.10),level:25),
        .init(id:"tropical",name:"雨林",point:CGPoint(x:0.19,y:0.69),level:18),
        .init(id:"beach",name:"海滩",point:CGPoint(x:0.80,y:0.71),level:15),
        .init(id:"sea",name:"远海",point:CGPoint(x:0.91,y:0.88),level:20)
    ]
}
