import Foundation
import CoreGraphics

struct SceneSizing {
    static let sectionGap:CGFloat=12
    static let gap:CGFloat=12
    static let scrollGutter:CGFloat=16
    static let compactToolbarItemWidth:CGFloat=44
    static let toolbarGap:CGFloat=6
    static func headerHeight(width:CGFloat)->CGFloat {
        let sixItems=6*compactToolbarItemWidth+5*toolbarGap
        return width < sixItems ? 118 : 80
    }
    static func verticalReserve(width:CGFloat)->CGFloat {headerHeight(width:width)+sectionGap+16}
    static func canvasWidth(viewportWidth:CGFloat,availableWidth:CGFloat?=nil)->CGFloat {
        max(1,min(viewportWidth-scrollGutter,availableWidth ?? viewportWidth))
    }
    static func sidebar(width:CGFloat)->CGFloat {min(460,max(144,width*0.26))}
    static func height(width:CGFloat,viewportHeight:CGFloat,hasSidebar:Bool=true)->CGFloat {
        let stageWidth=max(1,width-(hasSidebar ? sidebar(width:width)+gap:0))
        return max(1,min(stageWidth/1.5,max(1,viewportHeight-verticalReserve(width:width))))
    }
    static func initialWindow(available:CGSize)->CGSize {
        let scale=max(0.001,min(1,available.width/1000,available.height/680))
        return CGSize(width:1000*scale,height:680*scale)
    }
    static func stockColumns(width:CGFloat)->Int {max(1,min(4,Int((width+8)/104)))}
    static func dialog(preferred:CGSize,viewport:CGSize)->CGSize {
        CGSize(width:min(preferred.width,max(280,viewport.width-12)),height:min(preferred.height,max(240,viewport.height-12)))
    }
    static func fitted(in size:CGSize)->CGSize {
        let width=min(size.width,size.height*1.5)
        return CGSize(width:max(1,width),height:max(1,width/1.5))
    }
}

enum SceneNavigation {
    struct Context: Equatable {
        private var path: [String] = []
        init() {}
        mutating func enter(_ route: String, from source: String? = nil, sideways: Bool = false) {
            let route = SceneNavigation.canonical(route)
            guard let source = source.map(SceneNavigation.canonical), source != "菜单" else {
                path = [route]
                return
            }
            if path.last != source { path = [source] }
            if sideways { path[path.count - 1] = route }
            else if route != source { path.append(route) }
        }
        func parent(of route: String, level: Int = .max) -> String? {
            let route = SceneNavigation.canonical(route)
            if let previous = previousIndex(from: route, level: level) { return path[previous] }
            return SceneNavigation.parent(of: route)
        }
        mutating func goBack(from route: String, level: Int = .max) -> String? {
            let route = SceneNavigation.canonical(route)
            if let previous = previousIndex(from: route, level: level) {
                path.removeSubrange((previous + 1)..<path.count)
                return path.last
            }
            let parent = SceneNavigation.parent(of: route)
            path = parent.map { [$0] } ?? []
            return parent
        }
        private func previousIndex(from route: String, level: Int) -> Int? {
            guard path.last == route else { return nil }
            return path.indices.dropLast().last { SceneNavigation.canEnter(path[$0],level:level) }
        }
    }
    static let indoorRooms=["书房","厨房","商店","炼金室","酒馆","锻造室"]
    static let outdoorRooms=["农场","牧场","池塘"]
    static let rooms=indoorRooms+outdoorRooms
    static let wilds=[JourneyKind.fishing.rawValue,JourneyKind.adventure.rawValue,"矿洞"]
    static func isWild(_ route:String)->Bool {
        wilds.contains(route) || ["钓鱼","探险","矿洞"].contains(route.components(separatedBy:"/")[0])
    }
    static func isLocation(_ route:String)->Bool {
        let route=canonical(route)
        return rooms.contains(route) || isWild(route) || ["首页","后院","世界地图"].contains(route)
    }
    static func isScene(_ route:String)->Bool {isLocation(route) || ["成长","衣柜"].contains(route)}
    static func canonical(_ route:String)->String {
        ["地图":"首页","小院":"首页","小屋":"首页","户外地图":"世界地图","熬制魔药":"炼金室","专注":"计时器","待办":"任务","四象限":"任务",
         "湖畔钓鱼":"钓鱼/lake","钓鱼":"钓鱼/lake","林间冒险":"探险/forest","探险":"探险/forest","矿洞":"矿洞/旧矿场"][route] ?? route
    }
    static func requiredLevel(for route:String)->Int? {
        let parts=canonical(route).split(separator:"/",maxSplits:1,omittingEmptySubsequences:false)
        guard parts.count == 2 else {return nil}
        let id=parts[1]
        switch parts[0] {
        case "钓鱼": return FishingLocation.all.first{$0.id == id}?.level
        case "探险": return ExpeditionLocation.all.first{$0.id == id}?.level
        case "矿洞": return MineLayer.layers(in:String(id)).first?.level
        default: return nil
        }
    }
    static func canEnter(_ route:String,level:Int)->Bool {
        guard isWild(route) else {return true}
        return requiredLevel(for:route).map{level >= $0} ?? false
    }
    static func parent(of route:String)->String? {
        let route=canonical(route)
        if isWild(route) { return "世界地图" }
        if outdoorRooms.contains(route) { return "后院" }
        if indoorRooms.contains(route) || ["后院","世界地图"].contains(route) { return "首页" }
        return nil
    }
    static func neighbors(of scene:String,level:Int = .max)->(String,String)? {
        let scene=canonical(scene)
        var group:[String]
        switch scene.components(separatedBy:"/")[0] {
        case "钓鱼": group=FishingLocation.all.map{"钓鱼/"+$0.id}
        case "探险": group=ExpeditionLocation.all.map{"探险/"+$0.id}
        case "矿洞": group=MineLayer.areas.map{"矿洞/"+$0}
        default: group=indoorRooms.contains(scene) ? indoorRooms:outdoorRooms
        }
        group=group.filter{canEnter($0,level:level)}
        guard group.count > 1,let index=group.firstIndex(of:scene) else{return nil}
        return (group[(index+group.count-1)%group.count],group[(index+1)%group.count])
    }
    static func title(_ route:String)->String {
        let route=canonical(route)
        if route.hasPrefix("钓鱼/"),let place=FishingLocation.all.first(where:{$0.id == String(route.dropFirst(3))}) {return place.name}
        if route.hasPrefix("探险/"),let place=ExpeditionLocation.all.first(where:{$0.id == String(route.dropFirst(3))}) {return place.name}
        if route.hasPrefix("矿洞/"),let area=MineLayer.areas.first(where:{$0 == String(route.dropFirst(3))}) {return area}
        return route == "首页" ? "小屋":route.components(separatedBy:"/")[0]
    }
    static func icon(_ route:String)->String {
        switch canonical(route).components(separatedBy:"/")[0] {
        case "钓鱼": return "渔具"
        case "探险": return "林间冒险"
        case "矿洞": return "矿洞"
        default: return title(route)
        }
    }
}

struct HomeEntrance:Identifiable {
    var id:String
    var rect:CGRect
    init(id:String,rect:CGRect) {self.id=id;self.rect=rect}
    static let house:[HomeEntrance]=[
        .init(id:"书房",rect:CGRect(x:0.09,y:0.21,width:0.28,height:0.28)),
        .init(id:"炼金室",rect:CGRect(x:0.40,y:0.22,width:0.21,height:0.24)),
        .init(id:"厨房",rect:CGRect(x:0.64,y:0.22,width:0.27,height:0.27)),
        .init(id:"商店",rect:CGRect(x:0.10,y:0.55,width:0.22,height:0.27)),
        .init(id:"酒馆",rect:CGRect(x:0.55,y:0.55,width:0.16,height:0.28)),
        .init(id:"锻造室",rect:CGRect(x:0.73,y:0.54,width:0.19,height:0.29)),
        .init(id:"后院",rect:CGRect(x:0.015,y:0.75,width:0.085,height:0.14)),
        .init(id:"世界地图",rect:CGRect(x:0.93,y:0.66,width:0.065,height:0.17))
    ]
    static let backyard:[HomeEntrance]=[
        .init(id:"牧场",rect:CGRect(x:0.07,y:0.03,width:0.31,height:0.31)),
        .init(id:"农场",rect:CGRect(x:0.58,y:0.18,width:0.40,height:0.28)),
        .init(id:"池塘",rect:CGRect(x:0.55,y:0.60,width:0.44,height:0.32)),
        .init(id:"首页",rect:CGRect(x:0.08,y:0.48,width:0.15,height:0.35))
    ]
}

struct ShopCustomerPose {
    var foot:CGPoint
    var behindCounter:Bool {foot.y<0.75}
    init(progress:Double) {
        let progress=min(1,max(0,progress))
        if progress<0.3 {
            let phase=progress/0.3
            foot=CGPoint(x:0.84+phase*0.04,y:0.64+phase*0.14)
        } else {
            let phase=(progress-0.3)/0.7
            foot=CGPoint(x:0.88-phase*0.20,y:0.78+phase*0.05)
        }
    }
}
