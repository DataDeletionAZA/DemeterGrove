import SwiftUI

struct SceneHeader<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {
        VStack(spacing:10) {content}
            .frame(maxWidth:.infinity,alignment:.topLeading)
            .frame(minHeight:SceneSizing.headerHeight,alignment:.topLeading)
    }
}

private struct SceneViewportLayout:Layout {
    var viewportWidth:CGFloat
    var viewportHeight:CGFloat
    var hasSidebar:Bool
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let width=SceneSizing.canvasWidth(viewportWidth:viewportWidth,availableWidth:proposal.width)
        return CGSize(width:width,height:SceneSizing.height(width:width,viewportHeight:viewportHeight,hasSidebar:hasSidebar))
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
        SceneViewportLayout(viewportWidth:viewport.width,viewportHeight:viewport.height,hasSidebar:hasSidebar) {
            GeometryReader {geo in
                let side=hasSidebar ? SceneSizing.sidebar(width:geo.size.width):0
                let area=CGSize(width:max(1,geo.size.width-side-(hasSidebar ? SceneSizing.gap:0)),height:geo.size.height)
                let size=SceneSizing.fitted(in:area)
                HStack(spacing:SceneSizing.gap) {
                    stage(size).frame(width:size.width,height:size.height)
                        .frame(width:area.width,height:area.height)
                    if hasSidebar {sidebar().frame(width:side,height:geo.size.height)}
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

struct SceneToolbarItem {
    var name:String
    var selected=false
    var disabled=false
    var action:()->Void
    init(_ name:String,selected:Bool=false,disabled:Bool=false,action:@escaping()->Void) {
        self.name=name;self.selected=selected;self.disabled=disabled;self.action=action
    }
}

struct SceneToolbar:View {
    var items:[SceneToolbarItem]
    private var fullWidth:CGFloat {max(84,CGFloat(items.map{ $0.name.count }.max() ?? 1)*13+54)}
    var body:some View {
        ViewThatFits(in:.horizontal) {
            HStack(spacing:6) {ForEach(items.indices,id:\.self) {index in button(items[index],labels:true)}}.fixedSize(horizontal:true,vertical:false)
            HStack(spacing:6) {ForEach(items.indices,id:\.self) {index in button(items[index],labels:false)}}.fixedSize(horizontal:true,vertical:false)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:44,maximum:44))],alignment:.leading,spacing:6) {
                ForEach(items.indices,id:\.self) {index in button(items[index],labels:false)}
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private func button(_ item:SceneToolbarItem,labels:Bool)->some View {
        Button(action:item.action) {
            HStack(spacing:6) {
                PixelIcon(name:item.name,size:22)
                if labels {Text(item.name).lineLimit(1)}
            }.frame(width:labels ? fullWidth-24:20,height:24)
        }.buttonStyle(PixelButtonStyle(primary:item.selected)).disabled(item.disabled)
            .help(item.name).accessibilityLabel(item.name)
            .accessibilityAddTraits(item.selected ? [.isSelected]:[])
    }
}
