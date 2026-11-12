import SwiftUI

struct WorldMapScene: View {
    @ObservedObject var store: GardenStore
    @State private var showingInventory=false
    @State private var selectedPlace:String?
    var body: some View {
        VStack(spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Spacer()
                    WalletView(coins:store.data.garden.coins)
                }
                SceneToolbar(items:[
                    .init("成长",action:{SceneNavigation.open("成长",store:store,from:store.currentRoute)}),
                    .init("库存",action:{showingInventory=true})
                ])
            }
            SceneCanvas {size in
                ZStack {
                    RoomBackdrop(name:"WorldMap")
                        .frame(width:size.width,height:size.height)
                    ForEach(WorldMapPlace.all) {place in
                        mapMarker(place,size:size)
                    }
                    if let place=WorldMapPlace.all.first(where:{$0.id == selectedPlace}) {
                        let popupHeight=CGFloat(place.activities.count)*40+60
                        let popupHalf=popupHeight/2
                        VStack(spacing:5) {
                            HStack {Text(place.name).font(.headline);Spacer();Button("关闭"){selectedPlace=nil}.font(.caption)}
                            ForEach(place.activities,id:\.1) {activity in
                                Button {selectedPlace=nil;SceneNavigation.open(activity.1,store:store,from:store.currentRoute)} label: {
                                    Text(activity.0).lineLimit(1).frame(maxWidth:.infinity)
                                }
                            }
                        }.environment(\.compactSceneControls,true).padding(10)
                            .frame(width:min(180,size.width-24),height:popupHeight).magicSurface(Palette.paper,strong:true)
                            .position(x:min(size.width-100,max(100,size.width*place.point.x)),y:min(size.height-popupHalf-6,max(popupHalf+6,size.height*place.point.y-popupHalf)))
                    }
                }.frame(width:size.width,height:size.height).clipped()
                    .clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            }
        }.sheet(isPresented:$showingInventory) {InventoryView(store:store)}
    }
    private func mapMarker(_ place:WorldMapPlace,size:CGSize)->some View {
        let unlocked=place.canEnter(level:store.data.levelProgress.level)
        return Button {
            if unlocked,let route=place.route {
                if place.activities.count>1 {selectedPlace=place.id}
                else {selectedPlace=nil;SceneNavigation.open(route,store:store,from:store.currentRoute)}
            }
        } label: {
            VStack(spacing:2) {
                HStack(spacing:4) {
                    if !unlocked {Image(systemName:"lock.fill").font(.system(size:9))}
                    Text(place.name).font(.system(size:12,weight:.semibold))
                }
                if !unlocked {Text(place.requirement).font(.system(size:10))}
            }.foregroundStyle(unlocked ? Palette.goldLight:Palette.ink)
                .padding(.horizontal,7).padding(.vertical,5)
                .background(Palette.paper.opacity(0.94),in:PixelFrame())
                .overlay(PixelFrame().strokeBorder(unlocked ? Palette.gold:Palette.line,lineWidth:1))
                .contentShape(Rectangle())
        }.buttonStyle(WorldMapMarkerStyle()).disabled(!unlocked)
            .help(unlocked ? "前往\(place.name)":place.requirement)
            .accessibilityLabel(unlocked ? "前往\(place.name)":"\(place.name)，\(place.requirement)")
            .position(x:min(size.width-52,max(52,size.width*place.point.x)),y:min(size.height-24,max(24,size.height*place.point.y)))
    }
}

private struct WorldMapMarkerStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.opacity(configuration.isPressed ? 0.8:1)
    }
}
