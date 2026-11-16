import SwiftUI

struct CompanionEquipmentSheet: View {
    @ObservedObject var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneViewport) private var viewport
    let person:Companion
    @State private var selectedSlot:GearSlot = .tool
    @State private var dropSlot:GearSlot?
    @State private var feedback = ""
    private var state:ExpeditionState { store.data.expeditionState }
    private var traveling:Bool { state.isTraveling(person.id) }
    private var compact:Bool { viewport.width<390 || viewport.height<390 }

    var body: some View {
        SceneDialog(preferred:CGSize(width:550,height:traveling ? 350:550)) {
            VStack(alignment:.leading,spacing:8) {
                HStack(spacing:8) {
                    Text("\(person.name) · 装备").font(.headline)
                    Text(person.role).font(.caption).foregroundStyle(Palette.muted)
                }
                HStack(spacing:9) {
                    VStack(spacing:6) { slot(.tool);slot(.coat) }
                    GameNatureSprite(key:person.spriteKey,size:compact ? 94:124)
                        .background(alignment:.bottom) {
                            Ellipse().fill(Palette.gold.opacity(0.15)).frame(width:compact ? 70:96,height:13)
                        }
                    VStack(spacing:6) { slot(.charm);slot(.trousers) }
                }
            }
        } content: {
            VStack(alignment:.leading,spacing:11) {
                VStack(alignment:.leading,spacing:4) {
                    let bonuses = state.gearBonuses(for:person.id)
                    Text("基础 · 采集 \(person.gathering) · 寻踪 \(person.scouting) · 护行 \(person.guarding)")
                    Text("装备 · 采集 +\(bonuses.gathering) · 寻踪 +\(bonuses.scouting) · 护行 +\(bonuses.guarding)")
                        .foregroundStyle(Palette.goldLight)
                }.font(.system(size:11))
                    .frame(maxWidth:.infinity,alignment:.leading).padding(8).magicSurface(Palette.card)

                if !traveling { gearShelf }
            }
        } footer: {
            HStack(spacing:8) {
                if traveling || !feedback.isEmpty {
                    Text(traveling ? "行程中 · 返回后可换装":feedback)
                        .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                }
                Spacer(minLength:0)
                Button("关闭"){dismiss()}.keyboardShortcut(.cancelAction)
            }
        }
    }

    private func gear(in slot:GearSlot) -> CraftedGear? {
        state.equipment[person.id]?[slot.rawValue].flatMap(state.resolveGear)
    }

    private func slot(_ slot:GearSlot) -> some View {
        let item = gear(in:slot)
        let highlighted = selectedSlot == slot || dropSlot == slot
        return Button {
            selectedSlot=slot
            feedback=""
        } label: {
            VStack(spacing:compact ? 2:4) {
                Text(slot.rawValue).font(.caption).foregroundStyle(Palette.goldLight)
                if let item { GameNatureSprite(key:item.spriteKey,size:compact ? 20:32) }
                else { Text("+").font(.title3).foregroundStyle(Palette.muted).frame(height:compact ? 20:32) }
                Text(item?.name ?? "空").font(.system(size:10)).foregroundStyle(Palette.ink)
                    .lineLimit(compact ? 1:2).multilineTextAlignment(.center)
            }.frame(maxWidth:.infinity).frame(height:compact ? 54:76).padding(.horizontal,2)
                .magicSurface(highlighted ? Palette.moss.opacity(0.55):Palette.card)
                .overlay { PixelFrame().strokeBorder(highlighted ? Palette.goldLight:Palette.line,lineWidth:1).allowsHitTesting(false) }
        }.buttonStyle(.plain)
            .accessibilityLabel(slot.rawValue+" · "+(item?.name ?? "空"))
            .accessibilityAddTraits(selectedSlot == slot ? [.isSelected]:[])
            .help(slot.rawValue+" · "+(item?.name ?? "空"))
            .dropDestination(for:String.self) { items,_ in
                guard items.count == 1, let id=items.first, !traveling else { return false }
                return equip(id,in:slot)
            } isTargeted: { targeted in
                if targeted && !traveling { dropSlot=slot }
                else if dropSlot == slot { dropSlot=nil }
            }
    }

    private var gearShelf:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(selectedSlot.rawValue+" · 已有装备").font(.subheadline).foregroundStyle(Palette.goldLight)
                Spacer(minLength:0)
                if gear(in:selectedSlot) != nil {
                    Button("取下"){equip(nil,in:selectedSlot)}.accessibilityLabel("取下\(selectedSlot.rawValue)")
                }
            }
            let candidates = state.ownedGear.filter{$0.slot == selectedSlot}
            if candidates.isEmpty { Text("背包里没有此部位的装备。").font(.caption).foregroundStyle(Palette.muted) }
            ForEach(candidates) { item in
                let available = state.gear[item.id,default:0]-state.wornCount(item.id)
                let equipped = gear(in:item.slot)?.id == item.id
                HStack(spacing:9) {
                    if available>0 && !equipped {
                        gearPreview(item,available:available).draggable(item.id)
                    } else {
                        gearPreview(item,available:available)
                    }
                    Spacer(minLength:0)
                    Button(equipped ? "已穿戴":"穿戴"){equip(item.id,in:item.slot)}
                        .disabled(equipped || available<=0)
                        .accessibilityLabel(equipped ? "\(item.name)已穿戴":"穿戴\(item.name)")
                }.padding(7).magicSurface(Palette.card)
            }
        }
    }

    private func gearPreview(_ item:CraftedGear, available:Int) -> some View {
        HStack(spacing:7) {
            GameNatureSprite(key:item.spriteKey,size:42)
            VStack(alignment:.leading,spacing:4) {
                Text(item.name).font(.system(size:11))
                Text("闲置 \(available)/\(state.gear[item.id,default:0])").font(.caption).foregroundStyle(Palette.muted)
                Text("采集 +\(item.gathering) · 寻踪 +\(item.scouting) · 护行 +\(item.guarding)")
                    .font(.system(size:10)).foregroundStyle(Palette.goldLight)
            }
        }.contentShape(Rectangle())
    }

    @discardableResult
    private func equip(_ id:String?, in slot:GearSlot) -> Bool {
        if let id, let item=state.resolveGear(id), item.slot != slot {
            feedback="\(item.name)应放入\(item.slot.rawValue)栏。"
            return false
        }
        guard store.commitGameChange({$0.equipExpeditionGear(id,companion:person.id,slot:slot)}) else {
            feedback="暂时无法调整这件装备。"
            return false
        }
        selectedSlot=slot
        feedback=id.flatMap(state.resolveGear).map{"已穿戴\($0.name)。"} ?? "已取下\(slot.rawValue)。"
        return true
    }
}
