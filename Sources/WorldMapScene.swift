import SwiftUI

struct WorldMapScene: View {
    @ObservedObject var store: GardenStore
    @State private var showingInventory=false
    var body: some View {
        VStack(spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Spacer()
                    WalletView(coins:store.data.garden.coins)
                }
                SceneToolbar(items:[
                    .init("成长",action:{SceneNavigation.open("成长",store:store)}),
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
                }.frame(width:size.width,height:size.height).clipped()
                    .clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            }
        }.sheet(isPresented:$showingInventory) {InventoryView(store:store)}
    }
    private func mapMarker(_ place:WorldMapPlace,size:CGSize)->some View {
        let unlocked=place.canEnter(level:store.data.levelProgress.level)
        return Button {
            if unlocked,let route=place.route {SceneNavigation.open(route,store:store)}
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
