import Foundation

struct SceneSizing {
    static func sidebar(width:CGFloat,enabled:Bool)->CGFloat {enabled ? min(340,max(144,width*0.26)):0}
    static func height(width:CGFloat,maximum:CGFloat,sidebar:Bool)->CGFloat {
        max(1,min(max(1,width-self.sidebar(width:width,enabled:sidebar)-(sidebar ? 12:0))/1.5,max(120,maximum)))
    }
    static func fitted(in size:CGSize)->CGSize {
        let width=min(size.width,size.height*1.5)
        return CGSize(width:max(1,width),height:max(1,width/1.5))
    }
}

enum SceneNavigation {
    static let village=["首页","书房","农场","厨房","商店"]
    static let wilds=JourneyKind.allCases.map(\.rawValue)
    static func neighbors(of scene:String)->(String,String) {
        let group=village.contains(scene) ? village:wilds
        let index=group.firstIndex(of:scene) ?? 0
        return (group[(index+group.count-1)%group.count],group[(index+1)%group.count])
    }
    static func title(_ route:String)->String {route == "首页" ? "小院":route}
}
