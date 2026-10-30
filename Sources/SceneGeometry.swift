import Foundation

struct SceneSizing {
    static let headerHeight:CGFloat=72
    static let sectionGap:CGFloat=12
    static let verticalReserve:CGFloat=180
    static let gap:CGFloat=12
    static let scrollGutter:CGFloat=16
    static func canvasWidth(viewportWidth:CGFloat,availableWidth:CGFloat?=nil)->CGFloat {
        max(1,min(viewportWidth-scrollGutter,availableWidth ?? viewportWidth))
    }
    static func sidebar(width:CGFloat)->CGFloat {min(340,max(144,width*0.26))}
    static func height(width:CGFloat,viewportHeight:CGFloat)->CGFloat {
        max(1,min(max(1,width-sidebar(width:width)-gap)/1.5,max(120,viewportHeight-verticalReserve)))
    }
    static func dialog(preferred:CGSize,viewport:CGSize)->CGSize {
        CGSize(width:min(preferred.width,max(280,viewport.width-12)),height:min(preferred.height,max(240,viewport.height-12)))
    }
    static func fitted(in size:CGSize)->CGSize {
        let width=min(size.width,size.height*1.5)
        return CGSize(width:max(1,width),height:max(1,width/1.5))
    }
}

enum SceneNavigation {
    static let rooms=["书房","农场","厨房","商店","炼金室"]
    static let wilds=[JourneyKind.fishing.rawValue,JourneyKind.adventure.rawValue]
    static func canonical(_ route:String)->String {
        ["地图":"首页","小院":"首页","熬制魔药":"炼金室","专注":"计时器","待办":"任务","四象限":"任务"][route] ?? route
    }
    static func parent(of route:String)->String? {wilds.contains(canonical(route)) ? "首页":nil}
    static func neighbors(of scene:String)->(String,String)? {
        let scene=canonical(scene)
        let group=rooms.contains(scene) ? rooms:wilds
        guard let index=group.firstIndex(of:scene) else{return nil}
        return (group[(index+group.count-1)%group.count],group[(index+1)%group.count])
    }
    static func title(_ route:String)->String {canonical(route) == "首页" ? "小院":canonical(route)}
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
