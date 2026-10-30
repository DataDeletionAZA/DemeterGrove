import SwiftUI

struct HomeScene: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("等级 \(store.data.levelProgress.level)").font(.caption).foregroundStyle(Palette.goldLight)
                Spacer()
                WalletView(coins: store.data.garden.coins)
            }
            GeometryReader { geometry in
                let w = geometry.size.width, h = geometry.size.height
                ZStack {
                    RoomBackdrop(name: "Courtyard").frame(width: w, height: h).clipped()
                    SceneTarget(object: .farmDoor, sceneSize: geometry.size, label: "农场", showLabel: true, action: { store.selectedPage = "农场" })
                    SceneTarget(object: .kitchenDoor, sceneSize: geometry.size, label: "厨房", showLabel: true, action: { store.selectedPage = "厨房" })
                    SceneTarget(object: .studyDoor, sceneSize: geometry.size, label: "书房", showLabel: true, action: { store.selectedPage = "书房" })
                    SceneTarget(object: .shopDoor, sceneSize: geometry.size, label: "商店", showLabel: true, action: { store.selectedPage = "商店" })
                    SceneTarget(object: .signpost, sceneSize: geometry.size, label: "去远方", showLabel: true, action: { store.selectedPage = "地图" })
                    SceneParticles()
                }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1))
            }.aspectRatio(1.5, contentMode: .fit)
            HStack(spacing: 18) {
                Label("今日任务 \(store.todayTasks.count)", systemImage: "checklist")
                Label("累计专注 \(Int(store.data.totalFocus/60)) 分钟", systemImage: "hourglass")
                Spacer()
            }.font(.caption).foregroundStyle(Palette.muted)
        }
    }
}

struct SceneTarget: View {
    var object: SceneObject
    var sceneSize: CGSize
    var label: String
    var showLabel = false
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        let target = object.target
        let w = sceneSize.width, h = sceneSize.height
        ObjectButton(label: label, action: action, embeddedInBackdrop: true) {
            SceneObjectArtwork(object: object, sceneSize: sceneSize)
        }
        .frame(width: w * target.width, height: h * target.height)
        .overlay(alignment: .bottom) {
            if hovered || showLabel {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.goldLight)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Palette.paper.opacity(0.94), in: PixelFrame()).offset(y: 15)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovered = $0 }
        .position(x: w * target.x, y: h * target.y)
    }
}

struct StudyScene: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack {
                RoomBackdrop(name: "Study").frame(width: w, height: h).clipped()
                SceneTarget(object: .taskMemo, sceneSize: geometry.size, label: "任务", action: {store.selectedPage = "任务"})
                SceneTarget(object: .calendar, sceneSize: geometry.size, label: "日程", action: {store.selectedPage = "日程"})
                SceneTarget(object: .diary, sceneSize: geometry.size, label: "日记", action: {store.selectedPage = "日记"})
                SceneTarget(object: .hourglass, sceneSize: geometry.size, label: "专注", action: {store.selectedPage = "专注"})
                SceneTarget(object: .habitBook, sceneSize: geometry.size, label: "习惯", action: {store.selectedPage = "习惯"})
                SceneParticles()
            }.clipShape(PixelFrame()).overlay(PixelFrame().strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1))
        }.aspectRatio(1.5, contentMode: .fit)
    }
}
