import SwiftUI

struct SceneHeader<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {
        VStack(spacing:10) {content}
            .frame(maxWidth:.infinity,alignment:.topLeading)
            .frame(height:SceneSizing.headerHeight,alignment:.topLeading)
    }
}

private struct SceneViewportLayout:Layout {
    var viewportWidth:CGFloat
    var viewportHeight:CGFloat
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let width=SceneSizing.canvasWidth(viewportWidth:viewportWidth,availableWidth:proposal.width)
        return CGSize(width:width,height:SceneSizing.height(width:width,viewportHeight:viewportHeight))
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        subviews.first?.place(at:bounds.origin,proposal:ProposedViewSize(bounds.size))
    }
}

struct SceneCanvas<Stage:View,Sidebar:View>:View {
    @Environment(\.sceneViewport) private var viewport
    var hasSidebar=false
    @ViewBuilder var stage:(CGSize)->Stage
    @ViewBuilder var sidebar:()->Sidebar
    var body:some View {
        SceneViewportLayout(viewportWidth:viewport.width,viewportHeight:viewport.height) {
            GeometryReader {geo in
                let side=SceneSizing.sidebar(width:geo.size.width)
                let area=CGSize(width:max(1,geo.size.width-side-SceneSizing.gap),height:geo.size.height)
                let size=SceneSizing.fitted(in:area)
                HStack(spacing:SceneSizing.gap) {
                    stage(size).frame(width:size.width,height:size.height)
                        .frame(width:area.width,height:area.height)
                    Group {
                        if hasSidebar {sidebar()}
                        else {Color.clear.allowsHitTesting(false).accessibilityHidden(true)}
                    }.frame(width:side,height:geo.size.height)
                }
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

extension SceneCanvas where Sidebar == EmptyView {
    init(@ViewBuilder stage:@escaping(CGSize)->Stage) {
        self.stage=stage;self.sidebar={EmptyView()}
    }
}

extension SceneNavigation {
    static func open(_ route:String,store:GardenStore) {
        let route=canonical(route)
        if let pet=store.pet {pet.openTool(route)} else {store.selectedPage=route == "计时器" ? "专注":route}
    }
}

struct SceneArrows:View {
    @ObservedObject var store:GardenStore
    var scene:String
    var body:some View {
        if let routes=SceneNavigation.neighbors(of:scene) {
            HStack {
                arrow("◀",route:routes.0)
                Spacer(minLength:0)
                arrow("▶",route:routes.1)
            }.padding(9)
        }
    }
    private func arrow(_ glyph:String,route:String)->some View {
        Button {SceneNavigation.open(route,store:store)} label: {
            Text(glyph).font(.system(size:16)).foregroundStyle(Palette.goldLight)
                .frame(width:30,height:34).background(Palette.paper.opacity(0.92),in:PixelFrame())
        }.buttonStyle(.plain).help(SceneNavigation.title(route)).accessibilityLabel("前往\(SceneNavigation.title(route))")
    }
}

struct SceneDialog<Header:View,Content:View,Footer:View>:View {
    @Environment(\.sceneViewport) private var viewport
    var preferred:CGSize
    @ViewBuilder var header:Header
    @ViewBuilder var content:Content
    @ViewBuilder var footer:Footer
    var body:some View {
        let size=SceneSizing.dialog(preferred:preferred,viewport:viewport)
        VStack(alignment:.leading,spacing:14) {
            header.fixedSize(horizontal:false,vertical:true).layoutPriority(1)
            PixelScrollView {content.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,20)}
                .frame(maxHeight:.infinity)
            footer.fixedSize(horizontal:false,vertical:true).layoutPriority(1)
        }.padding(20).frame(width:size.width,height:size.height)
            .magicSurface(Palette.paper,strong:true).magicControls().foregroundStyle(Palette.ink)
    }
}
