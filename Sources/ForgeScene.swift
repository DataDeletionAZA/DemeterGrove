import SwiftUI

struct ForgeScene: View {
    @ObservedObject var store: GardenStore
    var body: some View { TavernScene(store:store,workshop:true) }
}
