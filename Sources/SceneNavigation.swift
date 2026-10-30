import SwiftUI

private struct SceneViewportLayout:Layout {
    var maximum:CGFloat
    var sidebar:Bool
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let width=proposal.width ?? 600
        return CGSize(width:width,height:SceneSizing.height(width:width,maximum:maximum,sidebar:sidebar))
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        subviews.first?.place(at:bounds.origin,proposal:ProposedViewSize(bounds.size))
    }
}

struct SceneCanvas<Stage:View,Sidebar:View>:View {
    @Environment(\.sceneViewport) private var viewport
    var reservedHeight:CGFloat=150
    var hasSidebar=false
    @ViewBuilder var stage:(CGSize)->Stage
    @ViewBuilder var sidebar:()->Sidebar
    var body:some View {
        SceneViewportLayout(maximum:viewport.height-reservedHeight,sidebar:hasSidebar) {
            GeometryReader {geo in
                let side=SceneSizing.sidebar(width:geo.size.width,enabled:hasSidebar)
                let area=CGSize(width:max(1,geo.size.width-side-(hasSidebar ? 12:0)),height:geo.size.height)
                let size=SceneSizing.fitted(in:area)
                HStack(spacing:hasSidebar ? 12:0) {
                    stage(size).frame(width:size.width,height:size.height)
                        .frame(width:area.width,height:area.height)
                    if hasSidebar {sidebar().frame(width:side,height:geo.size.height)}
                }
            }
        }
    }
}

extension SceneCanvas where Sidebar == EmptyView {
    init(reservedHeight:CGFloat=150,@ViewBuilder stage:@escaping(CGSize)->Stage) {
        self.reservedHeight=reservedHeight;self.stage=stage;self.sidebar={EmptyView()}
    }
}

extension SceneNavigation {
    static func open(_ route:String,store:GardenStore) {
        if let pet=store.pet {pet.openTool(route)} else {store.selectedPage=route}
    }
}

struct SceneArrows:View {
    @ObservedObject var store:GardenStore
    var scene:String
    var body:some View {
        let routes=SceneNavigation.neighbors(of:scene)
        HStack {
            arrow("◀",route:routes.0)
            Spacer(minLength:0)
            arrow("▶",route:routes.1)
        }.padding(9)
    }
    private func arrow(_ glyph:String,route:String)->some View {
        Button {SceneNavigation.open(route,store:store)} label: {
            Text(glyph).font(.system(size:16)).foregroundStyle(Palette.goldLight)
                .frame(width:30,height:34).background(Palette.paper.opacity(0.92),in:PixelFrame())
        }.buttonStyle(.plain).help(SceneNavigation.title(route)).accessibilityLabel("前往\(SceneNavigation.title(route))")
    }
}
