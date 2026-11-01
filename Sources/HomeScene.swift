import SwiftUI

struct HomeScene: View {
    @ObservedObject var store: GardenStore
    @State private var showingInventory=false
    var body: some View {
        VStack(spacing:SceneSizing.sectionGap) {
            SceneHeader {
                HStack {
                    Spacer()
                    WalletView(coins: store.data.garden.coins)
                }
                SceneToolbar(items:[
                    .init("成长",action:{SceneNavigation.open("成长",store:store)}),
                    .init("库存",action:{showingInventory=true})
                ])
            }
            SceneCanvas { size in
                let w = size.width, h = size.height
                ZStack {
                    RoomBackdrop(name: "Courtyard").frame(width: w, height: h).clipped()
                    SceneTarget(object: .farmDoor, sceneSize: size, label: "农场", action: { SceneNavigation.open("农场",store:store) })
                    SceneTarget(object: .kitchenDoor, sceneSize: size, label: "厨房", action: { SceneNavigation.open("厨房",store:store) })
                    SceneTarget(object: .studyDoor, sceneSize: size, label: "书房", action: { SceneNavigation.open("书房",store:store) })
                    SceneTarget(object: .shopDoor, sceneSize: size, label: "商店", action: { SceneNavigation.open("商店",store:store) })
                    SceneTarget(object:.signpost,sceneSize:size,label:"外出路牌",action:{SceneNavigation.open("户外地图",store:store)})
                    SceneParticles()
                }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1))
            }
        }.sheet(isPresented:$showingInventory) {InventoryView(store:store)}
    }
}

struct SceneTarget: View {
    var object: SceneObject
    var sceneSize: CGSize
    var label: String
    var showLabel = false
    var action: () -> Void
    var body: some View {
        let target = object.target
        let w = sceneSize.width, h = sceneSize.height
        ObjectButton(label: label, action: action, embeddedInBackdrop: true,caption:showLabel ? nil:label) {
            SceneObjectArtwork(object: object, sceneSize: sceneSize)
        }
        .frame(width: w * target.width, height: h * target.height)
        .overlay(alignment: .bottom) {
            if showLabel {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.goldLight)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Palette.paper.opacity(0.94), in: PixelFrame()).offset(y: 15)
                    .allowsHitTesting(false)
            }
        }
        .position(x: w * target.x, y: h * target.y)
    }
}

struct StudyScene: View {
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
            SceneCanvas(hasSidebar:true) { size in
                let w = size.width, h = size.height
                ZStack {
                    RoomBackdrop(name: "Study").frame(width: w, height: h).clipped()
                    SceneTarget(object: .taskMemo, sceneSize: size, label: "任务", action: {SceneNavigation.open("任务",store:store)})
                    SceneTarget(object: .calendar, sceneSize: size, label: "日程", action: {SceneNavigation.open("日程",store:store)})
                    SceneTarget(object: .diary, sceneSize: size, label: "日记", action: {SceneNavigation.open("日记",store:store)})
                    SceneTarget(object: .hourglass, sceneSize: size, label: "专注", action: {SceneNavigation.open("专注",store:store)})
                    SceneTarget(object: .habitBook, sceneSize: size, label: "习惯", action: {SceneNavigation.open("习惯",store:store)})
                    SceneParticles()
                    SceneArrows(store:store,scene:"书房")
                }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1))
            } sidebar: {StudyTodaySidebar(store:store)}
        }.sheet(isPresented:$showingInventory) {InventoryView(store:store)}
    }
}
