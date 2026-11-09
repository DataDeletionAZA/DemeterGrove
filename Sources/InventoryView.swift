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
    @State private var selected:InventoryEntry?
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
                        Button {selected=entry} label: {
                            VStack(spacing:6) {
                                artwork(entry).frame(height:50)
                                Text(entry.name).font(.callout).lineLimit(2).multilineTextAlignment(.center)
                                Text("×\(entry.count)").font(.caption).foregroundStyle(Palette.goldLight)
                            }.frame(maxWidth:.infinity,minHeight:104).padding(8).magicSurface(Palette.card)
                        }.buttonStyle(.plain)
                            .accessibilityElement(children:.ignore).accessibilityLabel("\(entry.name)，\(entry.count) 份")
                    }
                }.padding(.trailing,20)
                if entries.isEmpty {Text(search.isEmpty ? "这一类还没有物品":"没有找到匹配的物品").foregroundStyle(Palette.muted).padding(.vertical,20)}
            }
            Text("\(entries.count) 种物品").font(.caption).foregroundStyle(Palette.muted)
        }.padding(20).frame(minWidth:340,minHeight:300)
            .magicSurface(Palette.paper,strong:true).foregroundStyle(Palette.ink).magicControls()
            .onExitCommand {closeWindow()}
            .sheet(item:$selected) {entry in
                SceneDialog(preferred:CGSize(width:380,height:340)) {
                    HStack {Text(entry.name).font(.headline);Spacer();Button("关闭"){selected=nil}}
                } content: {
                    VStack(spacing:14) {
                        artwork(entry)
                        Text("×\(entry.count)").foregroundStyle(Palette.goldLight)
                        Text(lore(entry)).font(.callout).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                    }.padding(8)
                } footer: {EmptyView()}
            }
    }
    @ViewBuilder private func artwork(_ entry:InventoryEntry)->some View {
        switch entry.artwork {
        case .nature(let key):GameNatureSprite(key:key,size:48)
        case .ingredient(let name):IngredientArt(name:name,size:48)
        case .dish(let index):GameSprite(sheet:"Foods",index:index,size:48)
        case .seed(let crop):PlantArt(crop:crop,stage:0,size:48)
        case .material:GameSprite(sheet:"Equipment",index:10,size:48)
        case .item:GameSprite(sheet:"Equipment",index:entry.id == "water" ? 4:11,size:48)
        case .clothing(let asset):
            if let asset,let image=ChibiWardrobe.thumbnail(asset:asset) {Image(nsImage:image).resizable().interpolation(.none).scaledToFit().frame(width:48,height:48)}
            else {PixelIcon(name:"衣柜",size:48)}
        }
    }
    private func closeWindow() {if let close {close()} else {dismiss()}}
    private func lore(_ entry:InventoryEntry)->String {
        if entry.id.hasPrefix("dish:"),let dish=store.data.garden.menu.first(where:{"dish:"+$0.id == entry.id}) {
            return CraftRoll.title(quality:dish.quality)+" · 品质 \(dish.quality)\n\n"+(ItemLore.text(for:"dish:"+dish.canonicalID) ?? dish.recipeText)
        }
        if entry.id.hasPrefix("gear:"),let gear=store.data.expeditionState.resolveGear(String(entry.id.dropFirst(5))) {
            let materials=(gear.minerals.merging(gear.materials,uniquingKeysWith:+)).sorted{$0.key<$1.key}.map {pair in (ForgeMaterial.all.first{$0.id == pair.key}?.name ?? pair.key)+" ×\(pair.value)"}.joined(separator:" · ")
            return (ItemLore.text(for:entry.id) ?? "按部位用料打造的\(gear.slot.rawValue)，随队出行时发挥作用。")+"\n\n"+materials+"\n采集 \(gear.gathering) · 勘察 \(gear.scouting) · 防护 \(gear.guarding)"
        }
        return ItemLore.text(for:entry.id) ?? ItemLore.text(for:entry.name) ?? entry.name
    }
}

struct ItemDescriptionButton:View {
    var key:String
    var title:String
    @State private var showing=false
    var body:some View {
        Button {showing.toggle()} label: {
            Image(systemName:"info.circle").font(.system(size:13)).frame(width:24,height:24)
        }.buttonStyle(.plain).foregroundStyle(Palette.goldLight).accessibilityLabel("查看\(title)详情")
            .popover(isPresented:$showing) {
                VStack(alignment:.leading,spacing:8) {
                    Text(title).font(.headline)
                    Text(ItemLore.text(for:key) ?? title).font(.callout).fixedSize(horizontal:false,vertical:true)
                }.padding(16).frame(width:270).magicSurface(Palette.paper).foregroundStyle(Palette.ink)
            }
    }
}
