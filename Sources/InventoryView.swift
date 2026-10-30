import SwiftUI

struct InventoryButton:View {
    @ObservedObject var store:GardenStore
    @State private var showing=false
    var body:some View {
        Button("库存",systemImage:"shippingbox") {
            if let pet=store.pet {pet.openInventory()} else {showing=true}
        }.sheet(isPresented:$showing) {InventoryView(store:store)}
    }
}

struct InventoryView:View {
    @ObservedObject var store:GardenStore
    var close:(()->Void)?=nil
    @Environment(\.dismiss) private var dismiss
    @State private var category:InventoryCategory = .all
    @State private var search=""
    private var entries:[InventoryEntry] {store.data.inventory(category:category,search:search)}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text("库存").font(.title2);Spacer();Button("关闭"){closeWindow()}}
            HStack {WalletView(coins:store.data.garden.coins);Spacer()}
            HStack {
                PixelSelect(selection:$category,items:InventoryCategory.allCases.map{($0,$0.rawValue)})
                    .frame(width:130).accessibilityLabel("库存分类")
                TextField("搜索库存",text:$search).textFieldStyle(PixelTextFieldStyle())
            }
            PixelScrollView {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:124))],spacing:10) {
                    ForEach(entries) {entry in
                        VStack(spacing:6) {
                            artwork(entry).frame(height:50)
                            Text(entry.name).font(.callout).lineLimit(2).multilineTextAlignment(.center)
                            Text("×\(entry.count)").font(.caption).foregroundStyle(Palette.goldLight)
                        }.frame(maxWidth:.infinity,minHeight:104).padding(8).magicSurface(Palette.card)
                            .accessibilityElement(children:.ignore).accessibilityLabel("\(entry.name)，\(entry.count) 份")
                    }
                }.padding(.trailing,20)
                if entries.isEmpty {Text(search.isEmpty ? "这一类还没有物品":"没有找到匹配的物品").foregroundStyle(Palette.muted).padding(.vertical,20)}
            }
            Text("\(entries.count) 种物品").font(.caption).foregroundStyle(Palette.muted)
        }.padding(20).frame(minWidth:340,minHeight:300)
            .magicSurface(Palette.paper,strong:true).foregroundStyle(Palette.ink).magicControls()
            .onExitCommand {closeWindow()}
    }
    @ViewBuilder private func artwork(_ entry:InventoryEntry)->some View {
        switch entry.artwork {
        case .ingredient(let name):IngredientArt(name:name,size:48)
        case .dish(let index):GameSprite(sheet:"Foods",index:index,size:48)
        case .seed(let crop):PlantArt(crop:crop,stage:0,size:48)
        case .material:GameSprite(sheet:"Equipment",index:10,size:48)
        case .item:GameSprite(sheet:"Equipment",index:entry.id == "water" ? 4:11,size:48)
        case .clothing(let asset):
            if let asset,let image=DollImages.thumbnails[asset] {Image(nsImage:image).resizable().interpolation(.none).scaledToFit().frame(width:48,height:48)}
            else {PixelIcon(name:"衣柜",size:48)}
        }
    }
    private func closeWindow() {if let close {close()} else {dismiss()}}
}
