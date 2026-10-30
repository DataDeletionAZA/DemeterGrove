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
    static func fitted(in size:CGSize)->CGSize {
        let width=min(size.width,size.height*1.5)
        return CGSize(width:max(1,width),height:max(1,width/1.5))
    }
}

enum SceneNavigation {
    static let rooms=["书房","农场","厨房","商店"]
    static let wilds=JourneyKind.allCases.map(\.rawValue)
    static func neighbors(of scene:String)->(String,String)? {
        let group=rooms.contains(scene) ? rooms:wilds
        guard let index=group.firstIndex(of:scene) else{return nil}
        return (group[(index+group.count-1)%group.count],group[(index+1)%group.count])
    }
    static func title(_ route:String)->String {route == "首页" ? "小院":route}
}
