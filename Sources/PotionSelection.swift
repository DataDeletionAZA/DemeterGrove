import Foundation

struct PotionSelection {
    enum Kind {case ingredient,material}
    struct Portion:Identifiable {
        let id=UUID()
        var name:String
        var kind:Kind
        var slot:Int
        var droppedAt=Date()
    }
    private(set) var portions:[Portion]=[]
    mutating func add(_ name:String,kind:Kind,available:Int)->Bool {
        guard available>portions.filter({$0.name == name && $0.kind == kind}).count,
              portions.count<2 else{return false}
        let slot=(0..<2).first{candidate in !portions.contains{$0.slot == candidate}}!
        portions.append(Portion(name:name,kind:kind,slot:slot));return true
    }
    mutating func remove(_ id:UUID) {portions.removeAll{$0.id == id}}
    mutating func clear() {portions=[]}
    func count(_ name:String,kind:Kind)->Int {portions.filter{$0.name == name && $0.kind == kind}.count}
    func matches(_ potion:Potion)->Bool {
        portions.count == 2 && count(potion.ingredient,kind:.ingredient) == 1 && count(potion.material,kind:.material) == 1
    }
}
