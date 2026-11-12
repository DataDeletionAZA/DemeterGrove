import SwiftUI

struct WorldMapScene: View {
    @ObservedObject var store: GardenStore
    @State private var showingInventory=false
    @State private var selectedPlace:String?
    private var playerLevel: Int { store.data.levelProgress.level }

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
                        activityMenu(for: place, in: size)
                    }
                }.frame(width:size.width,height:size.height).clipped()
                    .clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold,lineWidth:1))
            }
        }.sheet(isPresented:$showingInventory) {InventoryView(store:store)}
    }

    private func activityMenu(for place: WorldMapPlace, in size: CGSize) -> some View {
        let frame = place.popupFrame(in: size)
        return VStack(spacing: 5) {
            HStack {
                Text(place.name).font(.headline).lineLimit(1)
                Spacer(minLength: 4)
                Button("关闭") { selectedPlace = nil }.buttonStyle(PixelButtonStyle())
            }
            PixelScrollView {
                VStack(spacing: 4) {
                    ForEach(place.activities) { activity in
                        let unlocked = activity.canEnter(level: playerLevel)
                        Button { enter(activity) } label: {
                            HStack(spacing: 5) {
                                Text(activity.name).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 4)
                                if !unlocked { ThemeSymbol(systemName: "lock.fill").font(.system(size: 9)).accessibilityHidden(true) }
                                Text(activity.requirement).font(.caption).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(PixelButtonStyle()).disabled(!unlocked)
                            .accessibilityLabel("\(activity.name)，\(activity.requirement)")
                    }
                }
            }
        }.environment(\.compactSceneControls, true).padding(8)
            .frame(width: frame.width, height: frame.height)
            .magicSurface(Palette.paper, strong: true)
            .position(x: frame.midX, y: frame.midY)
    }

    private func enter(_ activity: WorldMapActivity) {
        guard activity.canEnter(level: playerLevel) else { return }
        selectedPlace = nil
        SceneNavigation.open(activity.route, store: store, from: store.currentRoute)
    }

    private func mapMarker(_ place:WorldMapPlace,size:CGSize)->some View {
        let unlocked=place.canEnter(level:playerLevel)
        return Button {
            guard unlocked else { return }
            if place.activities.count > 1 { selectedPlace = place.id }
            else if let activity = place.activities.first { enter(activity) }
        } label: {
            VStack(spacing:2) {
                HStack(spacing:4) {
                    if !unlocked {ThemeSymbol(systemName:"lock.fill").font(.system(size:9))}
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
